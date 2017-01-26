use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use Testinit;

use Test::More tests => 824;
use Test::Mojo;
use Data::Dumper;

my ( $t1, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user, $pass ) = ( 'x'.Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t1, $admin, $apass, $user, $pass );
my $t2 = Test::Mojo->new('Ffc');
my $sleepval = 2;
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
    my $aref = $_[1] || 42;
    my $uid = $_[2] // 0;
    my $i = 0;
    for my $u ( sort {uc($a->[0]) cmp uc($b->[0])} [$user,60,2], [$admin,$aref,1] ) {
        $t->json_is("/1/$i/0" => $u->[0])
          ->json_is("/1/$i/2" => $u->[1])
          ->json_is("/1/$i/3" => $u->[2] );
        if ( $uid ) { # PMSGS-Link
            if ( $uid == $u->[2] ) { $t->json_is("/1/$i/4" => '')                  }
            else                   { $t->json_is("/1/$i/4" => '/pmsgs/'. $u->[2] ) }
        }
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
$t1->get_ok('/chat/refresh/42')->status_is(200)->content_is('"ok"');
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
    my $str  = Testinit::test_randstring() . '<b>' . Testinit::test_randstring() . "</b>abc:-)\n\n" . Testinit::test_randstring();
    my $str1 = $str;
    $str1 =~ s~:-\)~<img class="smiley" src="/theme/img/smileys/smile.png" alt=":-)" title=":-)" />~xmso;
    $str1 =~ s~\n+~<br />~xmso;
    $t1->post_ok($url, json => $str)->status_is(200);
    sleep $sleepval;
    $t2->get_ok($url)->status_is(200)
       ->json_is('/0/0/0' => ++$id)->json_is('/0/0/1' => $admin)->json_is('/0/0/2' => $str1)
       ->json_is('/2' => $fcnt)->json_is('/3' => $pcnt);
    bothusers($t2);
    my $lcsa2 = get_lastchatseenactive(2);
    if ( $focused ) { ok $lcsa1 < $lcsa2, 'lastchatseenactive updated'     }
    else            { ok $lcsa1 = $lcsa2, 'lastchatseenactive not updated' }

    $str = Testinit::test_randstring();
    $t1->post_ok($url, json => $str)->status_is(200);
    sleep $sleepval;
    my $str2 = Testinit::test_randstring();
    $t2->post_ok($url, json => $str2)->status_is(200);
    $t2->json_is('/0/1/0' => ++$id)->json_is('/0/1/1' => $admin)->json_is('/0/1/2' => $str );
    $t2->json_is('/0/0/0' => ++$id)->json_is('/0/0/1' => $user )->json_is('/0/0/2' => $str2);
    $t2->json_is('/2' => $fcnt)->json_is('/3' => $pcnt);
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
if ( not $t1->{success} ) {
    $t1->content_is('');
}
check_receive_messages(1,1,2);
check_receive_messages(0,1,2);
$t2->get_ok('/pmsgs/1')->status_is(200)
   ->content_like(qr~$Pmsgs[0]~)->content_like(qr~$Pmsgs[1]~);
check_receive_messages(1,1,0);
check_receive_messages(0,1,0);
# Status für den ersten Benutzer zurücksetzen für die folgenden Tests
$t1->get_ok('/chat/receive/focused')->status_is(200);
$t2->get_ok('/chat/receive/focused')->status_is(200);

# schauen ob chat verlassen funktioniert
$t2->get_ok('/chat/receive/focused')->status_is(200);
bothusers($t2);
$t1->get_ok('/chat/leave')->status_is(200)->content_is('ok');
$t2->get_ok('/chat/receive/focused')->status_is(200);
$t2->json_has('/0');
$t2->json_hasnt('/0/0');
$t2->json_is('/1/0/0' => $user);
$t2->json_is('/1/0/2' => 60);
$t2->json_hasnt('/1/1');
$t2->json_is('/2' => 1)->json_is('/3' => 0);

# und wieder rein in den chat (mit neuen nachrichten)
my $str3 = Testinit::test_randstring();
$t2->post_ok('/chat/receive/focused', json => $str3)->status_is(200);
$t1->get_ok('/chat')->status_is(200)
   ->content_like(qr~<!-- Angemeldet als "$admin" !-->~);
$t1->get_ok('/chat/receive/focused')->status_is(200);
$t1->json_is('/0/0/0' => ++$id);
$t1->json_is('/0/0/1' => $user);
$t1->json_is('/0/0/2' => $str3);
$t2->get_ok('/chat/receive/focused')->status_is(200);
bothusers($t2);
bothusers($t1);

# schauen, ob das automatische ablaufen auch funktioniert
$t1->get_ok('/chat/refresh/1')->status_is(200)->content_is('"ok"');
sleep $sleepval;
$t2->get_ok('/chat/receive/focused')->status_is(200)
   ->json_has('/0')->json_hasnt('/0/0')
   ->json_is('/1/0/0' => $user)->json_is('/1/0/2' => 60)
   ->json_hasnt('/1/1')
   ->json_is('/2' => 1)->json_is('/3' => 0);

# und wieder rein in den chat (mit neuen nachrichten)
$str3 = Testinit::test_randstring();
$t2->post_ok('/chat/receive/focused', json => $str3)->status_is(200);
$t1->get_ok('/chat')->status_is(200);
$t1->content_like(qr~<!-- Angemeldet als "$admin" !-->~);
$t1->get_ok('/chat/receive/focused')->status_is(200);
$t1->json_is('/0/0/0' => ++$id);
$t1->json_is('/0/0/1' => $user);
$t1->json_is('/0/0/2' => $str3);
$t2->get_ok('/chat/receive/focused')->status_is(200);
bothusers($t2,1);
bothusers($t1,1);

# So, und jetzt wird geschaut, ob wir auch sehen, wer kommt und wer geht
$t2->get_ok('/chat/receive/focused')->status_is(200);
my $str4 = Testinit::test_randstring();
$t1->get_ok('/chat/leave')->status_is(200);
$t1->get_ok('/chat/receive/started')->status_is(200);
$t1->post_ok('/chat/receive/focused', json => $str4)->status_is(200);
$t1->get_ok('/chat/leave')->status_is(200);

$t2->get_ok('/chat/receive/focused')->status_is(200);
$t2->json_hasnt('/0/3');
$t2->json_hasnt('/0/2');
#$t2->json_is('/0/3/0' => ++$id + 1, '/0/3/1' => "$admin", '/0/3/2' => "$admin hat den Chat verlassen.", '/0/3/4' => 1);
#$t2->json_is('/0/2/0' => ++$id + 1, '/0/2/1' => "$admin", '/0/2/2' => $str4, '/0/2/4' => 0);
$t2->json_is('/0/1/0' => ++$id, '/0/1/1' => "$admin", '/0/1/2' => "$admin hat den Chat betreten.", '/0/1/4' => 1);
$t2->json_is('/0/0/0' => ++$id, '/0/0/1' => "$admin", '/0/0/2' => "$admin hat den Chat verlassen.", '/0/0/4' => 1);

# Der nächste Test ist dazu da, zu schauen, ob für die User URL's zu PMSGS-Formularen mitgeliefert werden
$t1->get_ok('/chat/receive/focused')->status_is(200);
$t2->get_ok('/chat/receive/focused')->status_is(200);
bothusers($t2,1,2);
bothusers($t1,1,1);

# Testen, ob Privatnachrichten und Forenbeiträge korrekt ankommen
my @Pmsgs2 = map {Testinit::test_randstring()} 1 .. 2;
$t1->post_ok('/pmsgs/2/new', form => { textdata => $_ })
   ->status_is(302) for @Pmsgs2;
$t1->get_ok('/chat/receive/focused')->status_is(200);
$t2->get_ok('/chat/receive/focused')->status_is(200);
bothusers($t2,1,2);
bothusers($t1,1,1);
$t1->json_is('/1/0/5' => 0);
$t2->json_is('/1/0/5' => 2);

# Testen, ob Privatnachrichten und Forenbeiträge korrekt ankommen
# Diesmal mit anderen Nutzern und deaktiviertem Admin
my $t3 = Test::Mojo->new('Ffc');
my $t4 = Test::Mojo->new('Ffc'); # Admin
my $t5 = Test::Mojo->new('Ffc');
my ( $user3, $pass3 ) = ( 'z'.Testinit::test_randstring(), Testinit::test_randstring() );
my ( $user4, $pass4 ) = ( 'w'.Testinit::test_randstring(), Testinit::test_randstring() ); # Admin
my ( $user5, $pass5 ) = ( 'y'.Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t3, $admin, $apass, $user3, $pass3 );
Testinit::test_add_users( $t4, $admin, $apass, $user4, $pass4 ); # Admin
Testinit::test_add_users( $t5, $admin, $apass, $user5, $pass5 );

for my $u (
    [ $t3, $user3, $pass3 ],
    [ $t4, $user4, $pass4 ], # Admin
    [ $t5, $user5, $pass5 ],
) {
    Testinit::test_login(@$u);
    $u->[0]->get_ok('/chat')->status_is(200)
      ->content_like(qr~<!-- Angemeldet als "$u->[1]" !-->~);
}

# Adminuser umswitchen und Admin (userid 1) deaktivieren
$t1->post_ok("/admin/usermod/$user4", form => {overwriteok => 1, newpw1 => $apass, newpw2 => $apass, active => 1, admin => 1})
  ->status_is(302)->content_is('')->header_is(Location => '/admin/form');
$t1->get_ok('/logout')->status_is(200)->content_like(qr'<!-- Angemeldet als "&lt;noone&gt;" !-->');

$t3->post_ok("/admin/usermod/$admin", form => {overwriteok => 1, newpw1 => $apass, newpw2 => $apass, active => 0, admin => 1})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');

$t1->post_ok('/login', form => { form => {username => $admin, password => $apass} } )
   ->status_is(403)->content_like(qr~<h1 class="loginformh1">Anmeldung</h1>~);
$t3->get_ok('/chat')->status_is(200)
   ->content_like(qr~<!-- Angemeldet als "$user3" !-->~);

my @Pmsgs3 = map {Testinit::test_randstring()} 1 .. 2;
$t2->post_ok('/pmsgs/3/new', form => { textdata => $_ })
   ->status_is(302) for @Pmsgs3;

my @Pmsgs4 = map {Testinit::test_randstring()} 1 .. 3;
$t5->post_ok('/pmsgs/4/new', form => { textdata => $_ })
   ->status_is(302) for @Pmsgs4;

$_->get_ok('/chat')->status_is(200) for $t2, $t3, $t4, $t5;
$t2->get_ok('/chat/receive/started')->status_is(200); # 0 Pmsgs
$t3->get_ok('/chat/receive/started')->status_is(200); # 2 Pmsgs von 2
$t4->get_ok('/chat/receive/started')->status_is(200); # 3 Pmsgs von 5
$t5->get_ok('/chat/receive/started')->status_is(200); # 0 Pmsgs
sleep $sleepval;

my @usermap = sort { uc($a->[1]) cmp uc($b->[1]) } [2, $user], [3, $user3], [4, $user4], [5, $user5];
my %usermap = map { $usermap[$_][0] => [$_, @{$usermap[$_]}] } 0 .. $#usermap;
sub check_user_msg_cnt {
    my ( $t, $myuid, $uid, $msgcnt ) = @_;
    my $arrid = $usermap{$uid}[0];
    $t->get_ok('/chat/receive/focused')->status_is(200);
    note("  -----  user '$myuid' received '$msgcnt' pmsgs from user '$uid' (array id '$arrid')");

    $t->json_is("/1/$arrid/3" => $uid);
    unless ( $t->success ) {
        $t->content_is('');
        die Data::Dumper::Dumper \%usermap;
    }
    
    if   ( $myuid == $uid ) { $t->json_is("/1/$arrid/4" => ''              ) }
    else                    { $t->json_is("/1/$arrid/4" => '/pmsgs/'. $uid ) }

    if   ( $msgcnt > 0 ) { $t->json_is("/1/$arrid/5" => $msgcnt ) }
    else                 { $t->json_is("/1/$arrid/5" => 0       ) }
    unless ( $t->success ) {
        die $t->json_is('/1');
    }
}

# User 2
check_user_msg_cnt($t2, 2, 3, 0);
check_user_msg_cnt($t2, 2, 4, 0);
check_user_msg_cnt($t2, 2, 5, 0);
# User 3
check_user_msg_cnt($t3, 3, 2, 2);
check_user_msg_cnt($t3, 3, 4, 0);
check_user_msg_cnt($t3, 3, 5, 0);
# User 4
check_user_msg_cnt($t4, 4, 2, 0);
check_user_msg_cnt($t4, 4, 3, 0);
check_user_msg_cnt($t4, 4, 5, 3);
# User 5
check_user_msg_cnt($t5, 5, 2, 0);
check_user_msg_cnt($t5, 5, 3, 0);
check_user_msg_cnt($t5, 5, 4, 0);

# Check for topic-receive
$t3->get_ok('/topic/sort/chronological');
$t3->get_ok('/topic/1')->status_is(200);
$t3->get_ok('/topic/2')->status_is(200);

my @Texts = (map {Testinit::test_randstring()} 1 .. 5);
$t2->post_ok('/topic/1/new', form => { textdata => $_ })->status_is(302)
    for @Texts[0,1];
$t3->get_ok('/chat/receive/focused')->status_is(200);

$t3->json_is('/4/0/0' => '/topic/1');
$t3->json_is('/4/0/1' => "$Topics[0][0] ...");
$t3->json_is('/4/0/2' => '2');
$t3->json_is('/4/0/3' => 'newpost');

$t3->json_is('/4/1/0' => '/topic/2');
$t3->json_is('/4/1/1' => "$Topics[1][0] ...");
$t3->json_is('/4/1/2' => '0');
$t3->json_is('/4/1/3' => '');

$t3->get_ok('/topic/1')->status_is(200);
$t3->get_ok('/topic/2')->status_is(200);

$t2->post_ok('/topic/2/new', form => { textdata => $_ })->status_is(302)
    for @Texts[2,3,4];
$t3->get_ok('/chat/receive/focused')->status_is(200);

$t3->json_is('/4/0/0' => '/topic/2');
$t3->json_is('/4/0/1' => "$Topics[1][0] ...");
$t3->json_is('/4/0/2' => '3');
$t3->json_is('/4/0/3' => 'newpost');

$t3->json_is('/4/1/0' => '/topic/1');
$t3->json_is('/4/1/1' => "$Topics[0][0] ...");
$t3->json_is('/4/1/2' => '0');
$t3->json_is('/4/1/3' => '');

