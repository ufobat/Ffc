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

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my ( $user2, $pass2 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1, $user2, $pass2 );
sub ladmin { Testinit::test_login($t, $admin, $apass) }
sub login1 { Testinit::test_login($t, $user1, $pass1) }
sub login2 { Testinit::test_login($t, $user2, $pass2) }

my $id = 1; my @forums; my @pmsgss;

# Forenbeitrag erstellen
sub add_forum {
    my ($uid, $cnt) = ($_[0], $_[1] // 1);
    for my $i ( 1 .. $cnt ) {
        my $str = Testinit::test_randstring();
        note "add to forum: $str";
        push @forums, [$uid, $id++,$str];
        $t->post_ok("/topic/1/new", form => { textdata => $str })
          ->status_is(302)->content_is('')
          ->header_like(location => qr~/topic/1~);
        $t->get_ok("/topic/1")->status_is(200)->content_like(qr~$str~);
    }
}

# Privatnachricht erstellen
sub add_pmsgs {
    my ( $uid, $tuid, $cnt ) = ( $_[0], $_[1], $_[2] // 1 );
    for my $i ( 1 .. $cnt ) {
        my $str = Testinit::test_randstring();
        note "add to pmsgs: $str";
        push @pmsgss, [$uid, $id++,$str];
        $t->post_ok("/pmsgs/$tuid/new", form => { textdata => $str })
          ->status_is(302)->content_is('')
          ->header_like(location => qr~/pmsgs/$tuid~);
        $t->get_ok("/pmsgs/$tuid")->status_is(200)->content_like(qr~$str~);
    }
}

# Prüfen, ob was da ist, oder ob gerade das nicht da ist
sub _check_ajax {
    my ( $luid, $usertoid, @new ) = @_;
    $t->get_ok( ($usertoid ? "/pmsgs/$usertoid": '/topic/1') . '/fetch/new' );
    $t->status_is(200)->json_has( "/$#new" );
    for my $r ( 0 .. $#new ) {
        my $p = $new[$r];
        my ( $uid, $id, $str ) = @$p;
        if ( $usertoid ) {
            $t->json_like( "/$r", qr~<a href="/pmsgs/$usertoid/display/$id"~ );
        }
        else {
            $t->json_like( "/$r", qr~<a href="/topic/1/display/$id"~ );
        }
        $t->json_like( "/$r", qr~<p>$str</p>~ );
        $t->json_like("/$r", qr~<div class="postbox ownpost">~)
            if $uid == $luid;
        $t->json_like("/$r", qr~<div class="postbox newpost">~)
            if $uid != $luid;
    }
}
sub check_forum { _check_ajax( shift(), undef,   @_ ) }
sub check_pmsgs { _check_ajax( shift(), shift(), @_ ) }

# Neues Thema mit paar Beiträgen - wir benutzen immer das selbe, warum auch nicht
login1();
$t->post_ok('/topic/new', 
    form => {
        titlestring => 'Topic1',
        textdata => 'Testbeitrag1',
    })->status_is(302)->content_is('');
push @forums, [2, $id++, 'Testbeitrag1'];

add_forum(2,3);

# Beiträge für neue Privatunterhaltung anlegen
add_pmsgs(2,3,3);

# Forenbeiträge und Privatnachrichten im AJAX-Fetch prüfen
login1();
check_forum(2,    reverse @forums);
check_pmsgs(2, 3, reverse @pmsgss);
login2();
check_forum(3,    reverse @forums);
check_pmsgs(3, 2, reverse @pmsgss);

