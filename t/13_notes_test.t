use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use Posttest;

use Test::Mojo;
use Test::More tests => 39;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();

my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my ( $user2, $pass2 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1, $user2, $pass2 );

# runs a standardized test suite
run_tests(
    '/notes', 
    \&check_env, 
    $t, 
    [[$admin, $apass], [$user1, $pass1], [$user2, $pass2]]
);

# checks for correct appearance of side effects
sub check_env {
    my ( $entries ) = @_;
    Testinit::test_login( $t, $user1, $pass1 );
    if ( @$entries ) {
        $t->get_ok( '/notes/' )->status_is(200);
        for my $e ( @$entries ) {
            $t->content_like(qr/$e->[0]/);
        }
    }
    else {
        $t->get_ok( '/notes/' )->status_is(200);
    }
}



