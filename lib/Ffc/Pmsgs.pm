package Ffc::Pmsgs;
use 5.18.0;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

use Ffc::Pmsgs::Userlist;

###############################################################################
# Routen für die Privatnachrichtenbehandlung erstellen
sub install_routes {
    # Route zur Benutzerliste als Übersichtsseite und Einstiegsseite für alle privaten Nachrichtenkonversationen
    $_[0]->route('/pmsgs')->via('get')
      ->to(controller => 'pmsgs', action => 'show_userlist')
      ->name('show_pmsgs_userlist');

    # Beitrags-Standard-Routen
    Ffc::Plugin::Posts::install_routes_posts(
        $_[0], 'pmsgs', '/pmsgs/:usertoid', usertoid => $Ffc::Digqr);
}

###############################################################################
# Beiträge auf Privatnachrichten einschränken (nur in der Konversationsansicht notwendig)
sub where_select {
    my $utid = $_[0]->param('usertoid');

    # Basic-SQL, brauch ich immer
    my $sql = << 'EOSQL';
              p."userto"   IS NOT NULL
        AND   p."userfrom" <> p."userto"
        AND ( p."userfrom" =  ?
         OR   p."userto"   =  ? )
EOSQL
    # Falls es keine Gegenseite gibt, dann war es das auch schon
    $utid or
        return $sql, ( ( $_[0]->session->{userid} ) x 2 );

    # Gibt es eine Gegenseite (aka private Konversation), müssen wir das in Betracht ziehen
    return $sql . << 'EOSQL',
        AND ( p."userfrom" =  ?
         OR   p."userto"   =  ? )
EOSQL
        ( ( $_[0]->session->{userid} ) x 2, ( $utid ) x 2 ),
}

###############################################################################
# Veränderungen dürfen nur vom Beitragsersteller durchgeführt werden,
# darunter zählen auch Uploads und so, deswegen brauchen wir das auch für Privatnachrichten
sub where_modify {
    return << 'EOSQL',
              "userto"   IS NOT NULL
        AND   "userfrom" <> "userto"
        AND ( "userfrom" =  ? )
        AND ( "userto"   =  ? )
EOSQL
        $_[0]->session->{userid},
        $_[0]->param('usertoid');
}

###############################################################################
# Als zusätzlichen Parameter in den URL's wird lediglich die Id des Benutzers,
# mit dem man die private Konversation führt, benötigt
sub additional_params { usertoid => $_[0]->param('usertoid') }

###############################################################################
# Private Nachrichten anzeigen
sub show {
    my ( $c, $ajax ) = @_[0,1];
    my ( $uid, $utoid ) = ( $c->session->{userid}, $c->param('usertoid') );

    $c->stash(
        backurl      => $c->url_for('show_pmsgs_userlist'),
        backtext     => 'zur Benutzerliste',
        heading      => 'Private Nachrichten mit "' . $c->_get_username . '"',
    );
    # anders herum, weil ich ja von-zu setze und ich möchte meine eigene Zählung anpassen
    $c->set_lastseenpmsgs( $utoid, $uid ); 
    if ( $ajax ) { $c->fetch_new_posts() }
    else         { $c->show_posts()      }
}

###############################################################################
# Neue Beiträge als JSON zurück liefern
sub fetch_new { show($_[0], 1) }

###############################################################################
# Eine neue Privatnachricht an einem Benutzer schreiben
sub add {
    my $c = $_[0];
    my ( $utoid, $uid ) = ( $c->param('usertoid'), $c->session->{userid} );

    # Nachsehen, ob es für den Benutzer bereits einen Eintrag gibt, der mitverfolgt,
    # welche Privatnachricht in der bestimmten Konversation bereits gesehen wurden
    my $lastseen = $c->dbh_selectall_arrayref(
        'SELECT "lastseen" FROM "lastseenmsgs" WHERE "userid"=? AND "userfromid"=?',
        $utoid, $uid
    );

    # In der Konversationsverfolgung mit dem Benutzer hinterlegen, dass gleich eine neue
    # nocht nicht veremailte (falls das gewünscht ist) Nachricht vorhanden ist
    if ( @$lastseen ) {
        $c->dbh_do(
            'UPDATE "lastseenmsgs" SET "mailed"=0 WHERE "userid"=? AND "userfromid"=?',
            $utoid, $uid );
    }
    else {
        $c->dbh_do(
            'INSERT INTO "lastseenmsgs" ("userid", "userfromid", "mailed") VALUES (?,?,0)',
            $utoid, $uid );
    }

    # Regulärer Ablauf
    $c->add_post($utoid, undef);
}

###############################################################################
# Formular für das Hochladen befüllen (nur Überschrift)
sub upload_form {
    $_[0]->stash( heading => 'Eine Datei zur privaten Nachrichten mit "' . $_[0]->_get_username . '" anhängen' );
    $_[0]->upload_post_form();
}


###############################################################################
# Formular für die Löschnachfrage befüllen (nur Überschrift)
sub delete_upload_check {
    $_[0]->stash( heading => 'Einen Dateianhang der privaten Nachrichten mit "' . $_[0]->_get_username . '" löschen' );
    $_[0]->delete_upload_post_check();
}

###############################################################################
# Highscores machen bei Privatnachrichten keinen Sinn, und werden deswegen auf die Startseite umgeleitet
sub inc_highscore { $_[0]->show_posts() }
sub dec_highscore { $_[0]->show_posts() }

###############################################################################
# Das hier wird direkt durchgeleitet und nicht überschrieben
sub search           { $_[0]->search_posts()          }
sub query            { $_[0]->query_posts             }
sub set_postlimit    { $_[0]->set_post_postlimit()    }
sub upload_do        { $_[0]->upload_post_do()        }
sub download         { $_[0]->download_post()         }
sub delete_upload_do { $_[0]->delete_upload_post_do() }

1;
