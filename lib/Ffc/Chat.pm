package Ffc::Chat;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util 'quote';
use Encode qw( encode decode_utf8 );

sub install_routes {
    # die route erzeugt lediglich das chatfenster
    $_[0]->route('/chat')->via('get')
         ->to(controller => 'chat', action => 'chat_window_open')
         ->name('chat_window');

    # die route ist für nachrichten genauso wie für statusabfragen zuständig
    $_[0]->route('/chat/receive/focused')->via(qw(GET POST))
         ->to(controller => 'chat', action => 'receive_focused')
         ->name('chat_receive_focused');

    $_[0]->route('/chat/receive/unfocused')->via(qw(GET POST))
         ->to(controller => 'chat', action => 'receive_unfocused')
         ->name('chat_receive_unfocused');

    # benutzer verlässt den chat (schließt das fenster)
    $_[0]->route('/chat/leave')->via(qw(GET))
         ->to(controller => 'chat', action => 'leave_chat')
         ->name('chat_leave');

    # refresh-timer umsetzen
    $_[0]->route('/chat/refresh/:refresh', refresh => $Ffc::Digit)->via(qw(GET))
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
        $dbh->do('INSERT INTO "chat" ("userfromid", "text") VALUES (?,?)',
            undef, $c->session->{userid}, $msg);
    } # ende neue nachricht erhalten

    # rückgabe erzeugen
    my $sql = << 'EOSQL';
SELECT c."id", u."name", c."msg" 
FROM "chat" c 
INNER JOIN "users" u ON u."id"=c."userfromid"
WHERE c."id" > ( SELECT u2."lastchatid" FROM "users" u2 WHERE u2."id"=? LIMIT 1 )
ORDER BY c."id" DESC
LIMIT ?;
EOSQL

    my $msgs = $dbh->selectall_arrayref( $sql, undef,
         $c->session->{userid}, $c->configdata->{postlimit} );
    $_->[2] = quote($_->[2]) for @$msgs;

    # refresh-timer aktualsieren
    $sql = << 'EOSQL';
UPDATE "users" SET 
    "lastchatid"=CASE WHEN COALESCE(?,0)>0 THEN ? ELSE COALESCE((SELECT MAX("id") FROM "chat" LIMIT 1),0) END, 
    "inchat"=1, 
    "lastseenchat"=CURRENT_TIMESTAMP,
    "lastseenchatactive"=CASE WHEN ?=1 THEN CURRENT_TIMESTAMP ELSE 0 END
WHERE "id"=?
EOSQL

    $dbh->do( $sql, undef, $msgs->[0]->[0], $msgs->[0]->[0], $active, $c->session->{userid} );

    # benutzerliste ermitteln, die im chat sind
    $sql = << 'EOSQL';
SELECT 
    "name", 
    CASE WHEN COALESCE("lastseenchatactive",0)>0 THEN DATETIME("lastseenchatactive",'localtime') ELSE '' END,
    "chatrefreshsecs"
FROM "users"
WHERE 
    CASE WHEN COALESCE("lastseenchat",0)>0 THEN STRFTIME('%f',"lastseenchat") ELSE 0 END +"chatrefreshsecs"<=CURRENT_TIMESTAMP
    AND "inchat"=1
ORDER BY "name", "id"
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

