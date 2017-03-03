package Ffc::Chat;
use 5.18.0;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util 'xml_escape';
use Mojo::JSON 'encode_json';

###############################################################################
# Routen für die Behandlung des Chats einrichten
sub install_routes {
    my $r = $_[0];

    # Lediglich das Chatfenster darstellen
    $r->route('/chat')->via('get')
         ->to(controller => 'chat', action => 'chat_window_open')
         ->name('chat_window');

    # Start des Chats mit Eingangsinformationen
    $r->route('/chat/receive/started')->via(qw(GET))
         ->to(controller => 'chat', action => 'receive_started')
         ->name('chat_receive_started');
   
    # Regelmäßige Statusabfrage inklusive Nachrichtenübermittlung, wenn der Fokus auf dem Chat-Webbrowserfenster liegt
    $r->route('/chat/receive/focused')->via(qw(GET POST))
         ->to(controller => 'chat', action => 'receive_focused')
         ->name('chat_receive_focused');

    # Regelmäßige Statusabfrage, wenn der Fokus nicht auf dem Chat-Webbrowserfenster liegt
    $r->route('/chat/receive/unfocused')->via(qw(GET POST))
         ->to(controller => 'chat', action => 'receive_unfocused')
         ->name('chat_receive_unfocused');

    # Der Benutzer verlässt den Chat, zum Beispiel, in dem er das entsprechende Browserfenster schließt
    $r->route('/chat/leave')->via(qw(GET))
         ->to(controller => 'chat', action => 'leave_chat')
         ->name('chat_leave');

    # Häufigkeit der Statusabfragen festlegen
    $r->route('/chat/refresh/:refresh', refresh => $Ffc::Digqr)->via(qw(GET))
         ->to(controller => 'chat', action => 'set_refresh')
         ->name('chat_set_refresh');
}

###############################################################################
# Häufigkeit der Statusabfragen in der Datenbank festlegen
sub set_refresh {
    my $c = $_[0];
    my $refresh = $c->param('refresh');
    if ( $refresh and $refresh =~ $Ffc::Digqr ) {
        $c->dbh_do('UPDATE "users" SET "chatrefreshsecs"=? WHERE "id"=?',
            $refresh, $c->session->{userid} );
    }
    $c->render( json => 'ok' );
}

###############################################################################
# Chat-Fenster wird geöffnet, am Chat wird teil genommen
sub chat_window_open {
    my $c = $_[0];

    # Eine History-Liste neuester Nachrichten
    my @history_list = map {$_->[0]} reverse @{ $c->dbh_selectall_arrayref(
            'SELECT c."msg" FROM "chat" c WHERE c."userfromid"=? ORDER BY c."id" DESC LIMIT ?',
            $c->session->{userid}, 10) };
    $c->stash(history_list => encode_json \@history_list);
    $c->stash(history_pointer => scalar @history_list); # An welcher Stelle in der History sind wir

    # Die "Rahmeninformationen" für den Chat-Titel einrichten
    $c->stash(title_array => encode_json $c->configdata->{title});

    # Caching-Vorgaben und Fenster-Rendering anstoßen
    $c->res->headers( 'Cache-Control' => 'public, max-age=0, no-cache' );
    $c->stash(isinchat => 1);
    $c->render( template => 'chat' );
}

###############################################################################
# Den Chat verlassen bzw. das Chat-Webbrowserfenster schließen
sub leave_chat {
    my $c = $_[0];
    # Vermerk und Info-Nachricht in die Datenbank eintragen, dass der entsprechende Benutzer den Chat verlassen hat
    $c->dbh_do('UPDATE "users" SET "inchat"=0 WHERE "id"=?', $c->session->{userid} );
    $c->render( text => 'ok' );
}

###############################################################################
# Eine neue Chat-Nachricht in die Datenbank eintragen
my $i = 0;
sub _add_msg {
    return unless $_[1];
    my ( $c, $msg, $issys ) = @_;

    # Formatieren der neuen Nachricht
    $msg = $c->pre_format($msg, undef, $c->configdata->{inlineimage});
    $msg =~ s~\A\s*<p>~~xmsgo;
    $msg =~ s~</p>\s*\z~~xmsgo;
    $msg =~ s~</p>\s*<p>~<br />~xgmso;

    # Die neue Nachricht in die Daten eintragen, wenn sie Daten enthält
    $c->dbh_do('INSERT INTO "chat" ("userfromid", "msg", "sysmsg") VALUES (?,?,?)',
        $c->session->{userid}, $msg, $issys ? 1 : 0)
            if $msg;
}

###############################################################################
# Currying der Actions
sub receive_started   { _receive($_[0], 1, 1) }
sub receive_focused   { _receive($_[0], 1, 0) }
sub receive_unfocused { _receive($_[0], 0, 0) }

###############################################################################
# Benutzerliste ermitteln
sub get_chat_users {
    my $c = $_[0];
    my $sql = << 'EOSQL';
SELECT 
    "name", 
    DATETIME("lastseenchatactive",'localtime'),
    "chatrefreshsecs",
    "id"
FROM "users"
WHERE 
    DATETIME("lastseenchat", 'localtime', '+'|| ( "chatrefreshsecs" + 1 ) ||' seconds') >= DATETIME('now', 'localtime')
    AND "inchat"=1
ORDER BY UPPER("name"), "id"
EOSQL
    my $users = $c->dbh_selectall_arrayref( $sql );

    $c->generate_userlist();

    my %fusers = map {;$_->[0] => $_->[2]} @{$c->stash('users')};
    # Nachbearbeitung der Benutzerliste
    my $uid = $c->session->{userid};
    for my $u ( @$users ) {
        $u->[1] = $c->format_timestamp( $u->[1] || 0 );
        $u->[0] = xml_escape($u->[0]);
        $u->[4] = $u->[3] == $uid 
            ? ''
            : $c->url_for( 'show_pmsgs', usertoid => $u->[3] );
        $u->[5] = $fusers{$u->[3]} || 0;
        $u->[6] = $c->url_for( 'avatar_show', userid => $u->[3] );
    }
    return $users;
}

###############################################################################
# Action-Handler für die Status-Ermittlung aus der Datenbank und den optionalen Nachrichtentransfer in die Datenbank
sub _receive {
    my ( $c, $active, $started ) = @_;

    # Für den Fall, dass eine Nachricht gesendet wurde, diese in die Datenbank eintragen
    # ( Nur notwendig, wenn das Fenster aktiv ist beim Senden bzw. wenn ein POST-Request stattfand)
    if ( $c->req->json ) {
        _add_msg($c, $c->req->json);
    }
    my $s = $c->session;

    # Beginn des Rückgabe-SQL erstellen
    my $sql = << 'EOSQL';
SELECT c."id", uf."name", c."msg", datetime(c."posted", 'localtime'), c."sysmsg", c."userfromid"
FROM "chat" c 
INNER JOIN "users" uf ON uf."id"=c."userfromid"
EOSQL
    
    # Bei Betreten des Chats wird eventuell eine Nachricht erzeugt, dass der Benutzer den Chat betreten hat,
    # wobei die Refresh-Zeit des Benutzers mit in die Berechnung mit einbezogen wird
    if ( $started ) {
        unless ( 
            $c->dbh_selectall_arrayref( << 'EOSQL', $s->{userid} )->[0]->[0]
SELECT CASE WHEN
    "inchat" AND DATETIME("lastseenchat", 'localtime', '+'||"chatrefreshsecs"||' seconds') >= DATETIME('now', 'localtime') THEN 1 ELSE 0 END
FROM "users" 
WHERE "id"=?
EOSQL
        ) { 
            $c->dbh_do('DELETE FROM "chat" WHERE "sysmsg" = 1 AND "userfromid"=?', $s->{userid});
            _add_msg($c, $s->{user}.' schaut im Chat vorbei', 2);
        }

        # Nachrichtensortierung und Nachrichtenlimit für den Einstieg berücksichtigen
        $sql .= << 'EOSQL';
ORDER BY c."id" DESC
LIMIT ?;
EOSQL
    }
    else {
        # Ist man bereits drin, müssen die anderen Benutzer für die Nachrichten berücksichtigt werden
        # (umgekehrte Sortierung ist auch hier wichtig, muss aber wegen der String-Verkettung hier so nochmal extra da stehen)
        $sql .= << 'EOSQL';
LEFT OUTER JOIN "users" u2 ON u2."id"=?
WHERE c."id">COALESCE(u2."lastchatid",0)
ORDER BY c."id" DESC
EOSQL
    }

    # Nachrichten-Abfrage wird durchgeführt
    my $msgs = $c->dbh_selectall_arrayref( $sql,
        ( $started ? 50 : $s->{userid} )
    );

    # Nachbearbeitung der empfangenen Nachrichten
    my %ulinks;
    for my $m ( @$msgs ) {
        $m->[1] = xml_escape($m->[1]);
        $ulinks{$m->[5]} = 
            $m->[5] == $s->{userid} ?
                '' : $c->url_for( 'show_pmsgs', usertoid => $m->[5] )
                    unless exists $ulinks{$m->[5]};
        $m->[6] = $ulinks{$m->[5]};
        $m->[7] = $c->format_timestamp($m->[3], 1);
    }

    # Refresh-Timer neu setzen, damit diese Statusabfrage bei der Berechnung der Aktivität berücksichtig werden kann
    $sql  = qq~UPDATE "users" SET\n~;
    $sql .= qq~    "lastchatid"=?,\n~ if @$msgs;
    $sql .= qq~    "inchat"=1,\n    "lastseenchat"=CURRENT_TIMESTAMP~;
    $sql .= qq~,\n    "lastseenchatactive"=CURRENT_TIMESTAMP~ if $active;
    $sql .= qq~\nWHERE "id"=?~;
    $c->dbh_do( $sql, ( @$msgs ? $msgs->[0]->[0] : () ), $s->{userid} );

    # Rückgabe der Statusabfragen inkl. der Anzahlen der neuen Nachrichten und Forenbeiträge für die Titelleiste
    $c->res->headers( 'Cache-Control' => 'public, max-age=0, no-cache' );
    $c->counting();
    $c->stash(isinchat => 1);
    $c->render( json => [
        $msgs, 
        $c->stash('chat_users'),
        $c->stash('newpostcount'), 
        $c->stash('newmsgscount'), 
        $c->render_to_string('layouts/parts/menudynamic'),
    ] );
}

1;
