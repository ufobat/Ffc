package Ffc::Chat;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';
use Encode qw( encode decode_utf8 );

sub install_routes {
    my $r = $_[0];

    # die route erzeugt lediglich das chatfenster
    $r->route('/chat')->via('get')
         ->to(controller => 'chat', action => 'chat_window_open')
         ->name('chat_window');

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
    $r->route('/chat/refresh/:refresh', refresh => $Ffc::Digit)->via(qw(GET))
         ->to(controller => 'chat', action => 'set_refresh')
         ->name('chat_set_refresh');
}

sub set_refresh {
    my $c = $_[0];
    my $refresh = $c->param('refresh');
    if ( $refresh ) {
        $c->dbh->do('UPDATE "users" SET "chatrefreshsecs"=? WHERE "id"=?', undef,
            $refresh, $c->session->{userid} );
    }
    $c->render( text => 'ok' );
}

sub chat_window_open { $_[0]->render( template => 'chat' ) }

sub leave_chat {
    my $c = $_[0];
    # vermerk in der datenbank: benutzer hat chat verlassen,
    $c->dbh->do('UPDATE "users" SET "inchat"=0 WHERE "id"=?', undef, $c->session->{userid} );
    # kann bei document.on("close"... im javascript verwendet werden
    $c->render( text => 'ok' );
}

sub receive_focused   { _receive($_[0], 1) }
sub receive_unfocused { _receive($_[0], 0) }
sub _receive {
    my ( $c, $active ) = @_;
    my $msg = $c->param('msg');
    my $dbh = $c->dbh;

    if ( $msg ) { # neue nachricht erhalten
        $msg =~ s/\A\s+//xmso;
        $msg =~ s/\s+\z//xmso;
        next unless $msg;
        $dbh->do('INSERT INTO "chat" ("userfromid", "msg") VALUES (?,?)',
            undef, $c->session->{userid}, $msg);
    } # ende neue nachricht erhalten

    # rückgabe erzeugen
    my $sql = << 'EOSQL';
SELECT c."id", uf."name", c."msg", c."posted"
FROM "chat" c 
INNER JOIN "users" uf ON uf."id"=c."userfromid"
WHERE c."id">(SELECT u2."lastchatid" FROM "users" u2 WHERE u2."id"=? LIMIT 1)
ORDER BY c."id" DESC
LIMIT ?;
EOSQL

    my $msgs = $dbh->selectall_arrayref( $sql, undef,
         $c->session->{userid}, $c->configdata->{postlimit} * 3 );
    $_->[3] = $c->format_timestamp($_->[3]) for @$msgs;

    # refresh-timer aktualsieren
    $sql = qq~UPDATE "users" SET\n~;
    $sql .= qq~    "lastchatid"=?,\n~ if @$msgs;
    $sql .= qq~    "inchat"=1,\n    "lastseenchat"=CURRENT_TIMESTAMP~;
    $sql .= qq~,\n    "lastseenchatactive"=CURRENT_TIMESTAMP~ if $active;
    $sql .= qq~\nWHERE "id"=?~;
    $dbh->do( $sql, undef, ( @$msgs ? $msgs->[0]->[0] : () ), $c->session->{userid} );

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

    my $users = $dbh->selectall_arrayref( $sql );
    $_->[1] = $c->format_timestamp( $_->[1] || 0 ) for @$users;

    # und die notwendigen daten als json zurück geben
# # returned dataset:
# [ 
#        # msgs:
#    [ "userfromid", "userfromname", "msg" ],
#        # users:
#    [ "username", "lastseenchatactive", "chatrefreshsecs" ],
#        # countings: 
#    "newpostcount", "newmsgscount"
# ]
    $c->render( json => [$msgs, $users, $c->newpostcount, $c->newmsgscount] );
}

1;

