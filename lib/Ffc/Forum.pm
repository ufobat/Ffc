package Ffc::Forum;
use 5.18.0;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

use Ffc::Forum::Topics;
use Ffc::Forum::Readlater;

###############################################################################
# Die verschiedenen Routen des Forenteils installieren
sub install_routes { 
    my $l = $_[0];

    # Themenlisten-Routen einrichten
    Ffc::Forum::install_topics_routes($l);
    
    # Späterlesen-Routen einrichten
    Ffc::Forum::install_readlater_routes($l);

    # Standardrouten für die Beitragsbehandlung
    Ffc::Plugin::Posts::install_routes_posts($l, 'forum', '/topic/:topicid', topicid => $Ffc::Digqr);
}

###############################################################################
# Abfrage-Einschränkgung von Beiträgen im Forum
sub where_select { 
    # Bei bestimmten Aktionen muss noch geprüft werden, ob der angemeldete Benutzer Überhaupt zugriff auf die Aktion hat
    $_[0]->stash('action') =~ m~\A(?:delete|edit|upload|move)~xmsio
        and return 
            'p."userto" IS NULL AND p."topicid"=? AND p."userfrom"=?',
            $_[0]->param('topicid'), $_[0]->session->{userid};

    # Die Übliche Beitragsausgabe innerhalb eines Themas
    return 'p."userto" IS NULL AND p."topicid"=?', $_[0]->param('topicid');
}

###############################################################################
# Beim Modifizieren von Beiträgen im Forum muss auch darauf geachtet werden, dass das nur der angemeldete Benutzer darf
sub where_modify {
    return
        '"userto" IS NULL AND "topicid"=? AND "userfrom"=?',
        $_[0]->param('topicid'), $_[0]->session->{userid};
}

###############################################################################
# Es wird immer eine Themen-Id gebraucht, wenn man irgendwas mit den Beiträgen im Forum machen will
sub additional_params { topicid => $_[0]->param('topicid') }

###############################################################################
# Wahlweise die Themenliste oder die Liste der Themen in der Startseiten-Thema-Einstellung anzeigen
sub show_startuppage {
    $_[0]->configdata->{starttopic}
        and return
            $_[0]->redirect_to('show_forum', topicid => $_[0]->configdata->{starttopic});
    
    $_[0]->show_topiclist;
}

###############################################################################
# Beiträge eines Foren-Themas anzeigen
sub show {
    my $c = $_[0];
    my ( $uid, $topicid ) = ( $c->session->{userid}, $c->param('topicid') );
    my ( $heading, $userfrom ) = $c->_get_title_from_topicid;
    # Ohne Themenüberschrift kein Thema
    $heading or return;
    $c->stash(
        topicid      => $topicid,
        backurl      => $c->url_for('show_forum_topiclist'),
        backtext     => 'zur Themenliste',
        msgurl       => 'show_pmsgs',
        moveurl      => 'move_forum_topiclist',
        heading      => $heading,
    );
    $c->stash( topicediturl => $c->url_for('edit_forum_topic_form', topicid => $topicid) )
        if $uid eq $userfrom or $c->session->{admin};
    $c->set_lastseen( $uid, $topicid );
    $c->show_posts();
}

###############################################################################
# Einen Beitrag zu einem Thema hinzu fügen
sub add { 
    my $c = shift; 
    my $topicid = $c->param('topicid');
    $c->dbh_do( 'UPDATE "lastseenforum" SET "mailed"=0 WHERE "topicid"=?', $topicid );
    $c->add_post( undef, $topicid, @_ ) }

###############################################################################
# Formular anzeigen, um einen Beitrag zu ändern
sub edit_form {
    $_[0]->stash( heading => 
        'Beitrag zum Thema "' . $_[0]->_get_title_from_topicid . '" ändern' );
    $_[0]->edit_post_form();
}

###############################################################################
# Änderungen an einem Beitrag durchführen
sub edit_do { $_[0]->edit_post_do(undef, $_[0]->param('topicid')) }

###############################################################################
# Rückfragebestätigung, ob ein Beitrag gelöscht werden soll
sub delete_check {
    $_[0]->stash( heading => 
        'Beitrag zum Thema "' . $_[0]->_get_title_from_topicid . '" entfernen' );
    $_[0]->delete_post_check();
}


###############################################################################
# Hochladeformular
sub upload_form {
    $_[0]->stash( heading => 
        'Eine Datei zum Beitrag zum Thema "' . $_[0]->_get_title_from_topicid . '" anhängen' );
    $_[0]->upload_post_form();
}


###############################################################################
# Rückfragebestätigung, wenn man einen Dateiupload doch wieder löschen möchte
sub delete_upload_check {
    $_[0]->stash( heading => 
        'Eine Datei zum Beitrag zum Thema "' . $_[0]->_get_title_from_topicid . '" löschen' );
    $_[0]->delete_upload_post_check();
}

###############################################################################
# Hier ist der einzige Ort, wo High-Scores gezählt werden
sub inc_highscore { $_[0]->inc_post_highscore() }
sub dec_highscore { $_[0]->dec_post_highscore() }

###############################################################################
# Das wird direkt durechgeleitet
sub search           { $_[0]->search_posts()          }
sub query            { $_[0]->query_posts             }
sub set_postlimit    { $_[0]->set_post_postlimit()    }
sub upload_do        { $_[0]->upload_post_do()        }
sub download         { $_[0]->download_post()         }
sub delete_upload_do { $_[0]->delete_upload_post_do() }
sub delete_do        { $_[0]->delete_post_do()        }

1;
