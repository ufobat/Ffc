use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use Testinit;

use Test::More tests => 77;
use Test::Mojo;

my ( $t1, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user, $pass ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t1, $admin, $apass, $user, $pass );
my $t2 = Test::Mojo->new('Ffc');

# log users into chat
for my $u (
    [ $t1, $admin, $apass ],
    [ $t2, $user,  $pass  ],
) {
    Testinit::test_login(@$u);
    $u->[0]->get_ok('/chat')
      ->status_is(200)
      ->content_like(qr~<!-- Angemeldet als "$u->[1]" !-->~);
}

# erstmal schaun, ob alle da sind
$t1->get_ok('/chat/refresh/42')->status_is(200)->content_is('ok');
$t1->get_ok('/chat/receive/focused')->status_is(200)
   ->json_is([[[]],[[$admin,'',42]],0,0]);
$t2->get_ok('/chat/receive/focused')->status_is(200)
   ->json_is([[[]],[sort {$a->[0] cmp $b->[0]} [$user,'',60], [$admin,'',42]],0,0]);
$t1->get_ok('/chat/receive/focused')->status_is(200)
   ->json_is([[[]],[sort {$a->[0] cmp $b->[0]} [$user,'',60], [$admin,'',42]],0,0]);

# Nachrichten innerhalb des Chats senden und Empfangen mit Fokus
# Nachrichten innerhalb des Chats senden und Empfangen ohne Fokus
# Forenbeiträge im Chatfenster anzeigen
# Privatnachrichten im Chatfenster anzeigen

# schauen ob chat verlassen funktioniert
$t2->get_ok('/chat/receive/focused')->status_is(200)
   ->json_is([[[]],[sort {$a->[0] cmp $b->[0]} [$user,'',60], [$admin,'',42]],0,0]);
$t1->get_ok('/chat/leave')->status_is(200)->content_is('ok');
$t2->get_ok('/chat/receive/focused')->status_is(200)
   ->json_is([[[]],[[$user,'',60]],0,0]);
$t1->get_ok('/chat')->status_is(200)
   ->content_like(qr~<!-- Angemeldet als "$admin" !-->~);
$t1->get_ok('/chat/receive/focused')->status_is(200)
   ->json_is([[[]],[sort {$a->[0] cmp $b->[0]} [$user,'',60], [$admin,'',42]],0,0]);
$t2->get_ok('/chat/receive/focused')->status_is(200)
   ->json_is([[[]],[sort {$a->[0] cmp $b->[0]} [$user,'',60], [$admin,'',42]],0,0]);

# schauen, ob das automatische ablaufen auch funktioniert
$t2->get_ok('/chat/receive/focused')->status_is(200)
   ->json_is([[[]],[sort {$a->[0] cmp $b->[0]} [$user,'',60], [$admin,'',42]],0,0]);
$t1->get_ok('/chat/receive/focused')->status_is(200)
   ->json_is([[[]],[sort {$a->[0] cmp $b->[0]} [$user,'',60], [$admin,'',42]],0,0]);
$t1->get_ok('/chat/refresh/1')->status_is(200)->content_is('ok');
exit; sleep 2;
$t2->get_ok('/chat/receive/focused')->status_is(200)
   ->json_is([[[]],[[$user,'',60]],0,0]);

