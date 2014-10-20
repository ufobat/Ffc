use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use Testinit;

use Test::More tests => 335;
use Test::Mojo;
use Data::Dumper;

my ( $t1, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user, $pass ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t1, $admin, $apass, $user, $pass );
my $t2 = Test::Mojo->new('Ffc');
my $id = 0;

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

# schaun, ob bei einer rückantwort im json-format beide user in richtiger reihenfolge auftauchen
sub bothusers {
    my $t = $_[0];
    my $i = 0;
    for my $u ( sort {$a->[0] cmp $b->[0]} [$user,60], [$admin,42] ) {
        $t->json_is("/1/$i/0" => $u->[0])
          ->json_is("/1/$i/2" => $u->[1]);
        $i++;
    }
}

# den zeitstempel der letzten anwesenheit eines nutzers (nach id) ermitteln
sub get_lastchatseenactive { 
    $dbh->selectall_arrayref(
        q~SELECT COALESCE(STRFTIME('%s',"lastseenchatactive"),0) FROM "users" WHERE "id"=?~,
        undef, $_[0])->[0]->[0];
}

# erstmal schaun, ob alle da sind
$t1->get_ok('/chat/refresh/42')->status_is(200)->content_is('ok');
$t1->get_ok('/chat/receive/focused')->status_is(200)
   ->json_has('/0')->json_hasnt('/0/0')
   ->json_is('/1/0/0' => $admin)->json_is('/1/0/2' => 42)
   ->json_is('/2' => 0)->json_is('/3' => 0);
$t2->get_ok('/chat/receive/focused')->status_is(200)
   ->json_has('/0')->json_hasnt('/0/0')
   ->json_is('/2' => 0)->json_is('/3' => 0);
bothusers($t2);
$t1->get_ok('/chat/receive/focused')->status_is(200)
   ->json_has('/0')->json_hasnt('/0/0')
   ->json_is('/2' => 0)->json_is('/3' => 0);
bothusers($t1);

sub check_receive_messages {
    my $focused = $_[0] || 0;
    my $fcnt    = $_[1] || 0;
    my $pcnt    = $_[2] || 0;
    my $url     = '/chat/receive/'.($focused ? 'focused' : 'unfocused');

    my $lcsa1 = get_lastchatseenactive(2);
    my $str = Testinit::test_randstring();
    $t1->post_ok($url, form => { msg => $str })->status_is(200);
    sleep 2;
    $t2->get_ok($url)->status_is(200)
       ->json_is('/0/0' => [++$id,$admin,qq~"$str"~])
       ->json_is('/2' => $fcnt)->json_is('/3' => $pcnt);
    bothusers($t2);
    my $lcsa2 = get_lastchatseenactive(2);
    if ( $focused ) { ok $lcsa1 < $lcsa2, 'lastchatseenactive updated'     }
    else            { ok $lcsa1 = $lcsa2, 'lastchatseenactive not updated' }

    $str = Testinit::test_randstring();
    $t1->post_ok($url, form => { msg => $str })->status_is(200);
    sleep 2;
    my $str2 = Testinit::test_randstring();
    $t2->post_ok($url, form => { msg => $str2 })->status_is(200)
       ->json_is('/0/1' => [++$id,$admin,qq~"$str"~])
       ->json_is('/0/0' => [++$id,$user,qq~"$str2"~])
       ->json_is('/2' => $fcnt)->json_is('/3' => $pcnt);
    bothusers($t2);

    my $lcsa3 = get_lastchatseenactive(2);
    if ( $focused ) {
        ok $lcsa1 < $lcsa2, 'lastchatseenactive updated';
    }
    else {
        ok $lcsa1 = $lcsa2, 'lastchatseenactive not updated';
    }
}

# Nachrichten innerhalb des Chats senden und Empfangen mit Fokus
check_receive_messages(1);

# Nachrichten innerhalb des Chats senden und Empfangen ohne Fokus
check_receive_messages(0);

# Forenbeiträge im Chatfenster anzeigen
my @Topics = (map {[Testinit::test_randstring(), Testinit::test_randstring]} 1 .. 2);
$t1->post_ok('/topic/new', form => { titlestring => $_->[0], textdata => $_->[1] })
   ->status_is(302) for @Topics;
check_receive_messages(1,2,0);
check_receive_messages(0,2,0);
$t2->get_ok('/topic/1')->status_is(200)
   ->content_like(qr~$Topics[0][0]~)->content_like(qr~$Topics[0][1]~);
check_receive_messages(1,1,0);
check_receive_messages(0,1,0);

# Privatnachrichten im Chatfenster anzeigen
my @Pmsgs = map {Testinit::test_randstring()} 1 .. 2;
$t1->post_ok('/pmsgs/2/new', form => { textdata => $_ })
   ->status_is(302) for @Pmsgs;
check_receive_messages(1,1,2);
check_receive_messages(0,1,2);
$t2->get_ok('/pmsgs/1')->status_is(200)
   ->content_like(qr~$Pmsgs[0]~)->content_like(qr~$Pmsgs[1]~);
check_receive_messages(1,1,0);
check_receive_messages(0,1,0);

exit;

# Status für den ersten Benutzer zurücksetzen für die folgenden Tests
$t1->get_ok('/chat/receive/focused')->status_is(200);

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

