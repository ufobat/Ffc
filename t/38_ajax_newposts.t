use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use Ffc::Plugin::Config;
use File::Temp qw~tempfile tempdir~;
use File::Spec::Functions qw(catfile catdir splitdir);
use Mojo::Util 'xml_escape';

use Test::Mojo;
use Test::More tests => 152;

my ( $t1, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my   $t2 = Test::Mojo->new('Ffc');
my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my ( $user2, $pass2 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t1, $admin, $apass, $user1, $pass1, $user2, $pass2 );
sub ladmin { Testinit::test_login($t1, $admin, $apass) }
sub login1 { Testinit::test_login($t1, $user1, $pass1) }
sub login2 { Testinit::test_login($t2, $user2, $pass2) }

my $id = 1; my @forums; my @pmsgss;

# Forenbeitrag erstellen
sub add_forum {
    my ($uid, $cnt) = ($_[0], $_[1] // 1);
    for my $i ( 1 .. $cnt ) {
        my $str = Testinit::test_randstring();
        note "add to forum: $str";
        push @forums, [$uid, $id++,$str,($uid == 2 ? 0 : 1), ($uid == 3 ? 0 : 1)];
        $t1->post_ok("/topic/1/new", form => { textdata => $str })
          ->status_is(302)->content_is('')
          ->header_like(location => qr~/topic/1~);
        $t1->get_ok("/topic/1")->status_is(200)->content_like(qr~$str~);
    }
}

# Privatnachricht erstellen
sub add_pmsgs {
    my ( $uid, $tuid, $cnt ) = ( $_[0], $_[1], $_[2] // 1 );
    for my $i ( 1 .. $cnt ) {
        my $str = Testinit::test_randstring();
        note "add to pmsgs: $str";
        push @pmsgss, [$uid, $id++,$str,($uid == 2 ? 0 : 1), ($uid == 3 ? 0 : 1)];
        $t1->post_ok("/pmsgs/$tuid/new", form => { textdata => $str })
          ->status_is(302)->content_is('')
          ->header_like(location => qr~/pmsgs/$tuid~);
        $t1->get_ok("/pmsgs/$tuid")->status_is(200)->content_like(qr~$str~);
    }
}

# Prüfen, ob was da ist, oder ob gerade das nicht da ist
sub _check_ajax {
    my ( $t, $luid, $usertoid, @new ) = @_;
    $t->get_ok( ($usertoid ? "/pmsgs/$usertoid": '/topic/1') . '/fetch/new' );
    $t->status_is(200)->json_has( "/$#new" );
    for my $r ( 0 .. $#new ) {
        my $p = $new[$r];
        my ( $uid, $id, $str, $u2new, $u3new ) = @$p;
        note qq~----- checkdata: logeinuserid=$luid, postid=$id, str=$str, u2new=$u2new, u3new=$u3new, pmsgs=~.($usertoid // '');
        if ( $usertoid ) {
            $t->json_like( "/$r", qr~<a href="/pmsgs/$usertoid/display/$id"~ );
        }
        else {
            $t->json_like( "/$r", qr~<a href="/topic/1/display/$id"~ );
        }
        $t->json_like( "/$r", qr~<p>$str</p>~ );
        if ( $uid == $luid ) {
            $t->json_like(   "/$r", qr~<div class="postbox ownpost">~ );
            $t->json_unlike( "/$r", qr~<div class="postbox newpost">~ );
        }
        else {
            $t->json_unlike( "/$r", qr~<div class="postbox ownpost">~ );
            if ( ( $luid == 2 and $u2new ) or ( $luid == 3 and $u3new ) ) {
                $t->json_like( "/$r", qr~<div class="postbox newpost">~ );
            }
            else {
                $t->json_like( "/$r", qr~<div class="postbox">~ );
            }
        }
    }
}
sub check_forum { _check_ajax( shift(), shift(), undef,   @_ ) }
sub check_pmsgs { _check_ajax( shift(), shift(), shift(), @_ ) }

login1();
login2();

# Neues Thema mit paar Beiträgen - wir benutzen immer das selbe, warum auch nicht
note "---------- insert start";
$t1->post_ok('/topic/new', 
    form => {
        titlestring => 'Topic1',
        textdata => 'Testbeitrag1',
    })->status_is(302)->content_is('');
push @forums, [2, $id++, 'Testbeitrag1', 0, 1];
add_forum(2,3);
add_pmsgs(2,3,3);

# Forenbeiträge und Privatnachrichten im AJAX-Fetch prüfen
note "---------- test start";
check_forum( $t1, 2,    reverse @forums);
check_pmsgs( $t1, 2, 3, reverse @pmsgss);
check_forum( $t2, 3,    reverse @forums);
check_pmsgs( $t2, 3, 2, reverse @pmsgss);

# Reset für User 2
note "---------- reset all";
$t2->get_ok('/topic/1')->status_is(200);
$_->[4] = 0 for @forums;
$t2->get_ok('/pmsgs/2')->status_is(200);
$_->[4] = 0 for @pmsgss;

# Neue Beiträge durch User 1
note "--------- new single entry";
add_forum(2,1);
check_forum( $t2, 3, reverse @forums);
