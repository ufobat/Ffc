package Ffc::Chat;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util 'xml_escape';
use Mojo::JSON 'encode_json';

sub _noop { $Ffc::Digqr };

sub install_routes {
    my $r = $_[0];

    # die route erzeugt lediglich das chatfenster
    $r->route('/chat')->via('get')
         ->to(controller => 'chat', action => 'chat_window_open')
         ->name('chat_window');

    # die route liefert die notwendigen Nachrichten beim Start einer Chatsession
    $r->route('/chat/receive/started')->via(qw(GET))
         ->to(controller => 'chat', action => 'receive_started')
         ->name('chat_receive_started');
    # die route ist für nachrichten genauso wie für statusabfragen zuständig
    $r->route('/chat/receive/focused')->via(qw(GET POST))
         ->to(controller => 'chat', action => 'receive_focused')
         ->name('chat_receive_focused');

    $r->route('/chat/receive/unfocused')->via(qw(GET POST))
         ->to(controller => 'chat', action => 'receive_unfocused')
         ->name('chat_receive_unfocused');

    # benutzer verlässt den chat (schließt das fenster)
    $r->route('/chat/leave')->via(qw(GET))
         ->to(controller => 'chat', action => 'leave_chat')
         ->name('chat_leave');

    # refresh-timer umsetzen
    $r->route('/chat/refresh/:refresh', refresh => $Ffc::Digqr)->via(qw(GET))
         ->to(controller => 'chat', action => 'set_refresh')
         ->name('chat_set_refresh');
}

sub set_refresh {
    my $c = $_[0];
    my $refresh = $c->param('refresh');
    if ( $refresh ) {
        $c->dbh_do('UPDATE "users" SET "chatrefreshsecs"=? WHERE "id"=?',
            $refresh, $c->session->{userid} );
    }
    $c->render( json => 'ok' );
}

sub chat_window_open {
    my $c = $_[0];
    my @history_list = map {$_->[0]} reverse @{ $c->dbh_selectall_arrayref(
            'SELECT c."msg" FROM "chat" c WHERE c."userfromid"=? ORDER BY c."id" DESC LIMIT ?',
            $c->session->{userid}, 10) };
    $c->stash(history_list => encode_json \@history_list);
    $c->stash(history_pointer => scalar @history_list);
    $c->render( template => 'chat' );
}

sub leave_chat {
    my $c = $_[0];
    # vermerk in der datenbank: benutzer hat chat verlassen,
    $c->dbh_do('UPDATE "users" SET "inchat"=0 WHERE "id"=?', $c->session->{userid} );
    # kann bei document.on("close"... im javascript verwendet werden
    $c->render( text => 'ok' );
}

sub receive_started   { _receive($_[0], 1, 1) }
sub receive_focused   { _receive($_[0], 1, 0) }
sub receive_unfocused { _receive($_[0], 0, 0) }
sub _receive {
    my ( $c, $active, $started ) = @_;
    my $msg = '';
    $msg = $c->req->json if $c->req->method eq 'POST';
    if ( $msg ) { # neue nachricht erhalten
        $msg =~ s/\A\s+//xmso;
        $msg =~ s/\s+\z//xmso;
        if ( $msg ) {
            $c->dbh_do('INSERT INTO "chat" ("userfromid", "msg") VALUES (?,?)',
                $c->session->{userid}, $msg);
        }
    } # ende neue nachricht erhalten

    # rückgabe erzeugen
    my $sql = << 'EOSQL';
SELECT c."id", uf."name", c."msg", datetime(c."posted", 'localtime')
FROM "chat" c 
INNER JOIN "users" uf ON uf."id"=c."userfromid"
EOSQL
    if ( $started ) {
        $sql .= << 'EOSQL';
ORDER BY c."id" DESC
LIMIT ?;
EOSQL
    }
    else {
        $sql .= << 'EOSQL';
LEFT OUTER JOIN "users" u2 ON u2."id"=?
WHERE c."id">COALESCE(u2."lastchatid",0)
ORDER BY c."id" DESC
EOSQL
    }

    my $msgs = $c->dbh_selectall_arrayref( $sql,
        ( $started ? 50 : $c->session->{userid} )
    );
    for my $m ( @$msgs ) {
        $m->[$_] = xml_escape($m->[$_]) for 1, 2;
        $m->[3] = $c->format_timestamp($m->[3], 1);
    }

    # refresh-timer aktualsieren
    $sql = qq~UPDATE "users" SET\n~;
    $sql .= qq~    "lastchatid"=?,\n~ if @$msgs;
    $sql .= qq~    "inchat"=1,\n    "lastseenchat"=CURRENT_TIMESTAMP~;
    $sql .= qq~,\n    "lastseenchatactive"=CURRENT_TIMESTAMP~ if $active;
    $sql .= qq~\nWHERE "id"=?~;
    $c->dbh_do( $sql, ( @$msgs ? $msgs->[0]->[0] : () ), $c->session->{userid} );

    # benutzerliste ermitteln, die im chat sind
    $sql = << 'EOSQL';
SELECT 
    "name", 
    DATETIME("lastseenchatactive",'localtime'),
    "chatrefreshsecs",
    "id"
FROM "users"
WHERE 
    (CAST(STRFTIME('%s',"lastseenchat") AS integer)+"chatrefreshsecs")>=CAST(STRFTIME('%s',CURRENT_TIMESTAMP) AS integer)
    AND "inchat"=1
ORDER BY UPPER("name"), "id"
EOSQL

    my $users = $c->dbh_selectall_arrayref( $sql );
    for my $u ( @$users ) {
        $u->[1] = $c->format_timestamp( $u->[1] || 0 );
        $u->[0] = xml_escape($u->[0]);
    }

    # und die notwendigen daten als json zurück geben
# # returned dataset:
# [ 
#        # msgs:
#    [ "userfromname", "msg" ],
#        # users:
#    [ "username", "lastseenchatactive", "chatrefreshsecs" ],
#        # countings: 
#    "newpostcount", "newmsgscount"
# ]
    $c->render( json => [$msgs, $users, $c->newpostcount, $c->newmsgscount] );
}

1;

