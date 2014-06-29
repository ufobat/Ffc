use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 89;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();

my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my ( $user2, $pass2 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1, $user2, $pass2 );

sub logina { Testinit::test_login(   $t, $admin, $apass ) }
sub login1 { Testinit::test_login(   $t, $user1, $pass1 ) }
sub login2 { Testinit::test_login(   $t, $user2, $pass2 ) }

sub check_list {
    my ($lu, $lui, $u1, $u1i, $u1o, $u2, $u2i, $u2o) = @_;
    $t->get_ok('/pmsgs')->status_is(200);
    for my $u ( [$u1, $u1i, $u1o], [$u2, $u2i, $u2o], [$lu, $lui, 0] ) {
        my ( $u, $ui, $uo ) = @$u;
        my $s = qr~<a href="/pmsgs/$ui"\s*title="Privatnachrichten mit Benutzer &quot;$u&quot; ansehen">$u</a>~;
        if ( $uo ) { $t->content_like($s) } else { $t->content_unlike($s) }
    }
}

logina();
check_list($admin, 1, $user1, 2, 1, $user2, 3, 1);

login1();
check_list($user1, 2, $admin, 1, 1, $user2, 3, 1);

login2();
check_list($user2, 3, $admin, 1, 1, $user1, 2, 1);

logina();
$t->post_ok("/options/admin/usermod/$user1", form => {active => 0, overwriteok => 1})->status_is(200);
Testinit::test_info($t, qq~Benutzer \&quot;$user1\&quot; geändert~);

check_list($admin, 1, $user1, 2, 0, $user2, 3, 1);

login2();
check_list($user2, 3, $admin, 1, 1, $user1, 2, 0);
