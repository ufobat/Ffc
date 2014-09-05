use strict;
use warnings;
use utf8;
use 5.010;

use Testinit;
use Test::Mojo;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();

my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my ( $user2, $pass2 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1, $user2, $pass2 );

sub logina { Testinit::test_login( $t, $admin, $apass ) }
sub login1 { Testinit::test_login( $t, $user1, $pass1 ) }
sub login2 { Testinit::test_login( $t, $user2, $pass2 ) }

sub info    { Testinit::test_info(    $t, @_ ) }
sub error   { Testinit::test_error(   $t, @_ ) }
sub warning { Testinit::test_warning( $t, @_ ) }

sub run_tests {
    my ( $urlpref, $check_env_sub ) = @_;
    my @entries;

    # shortcuts for user logins

    $check_env_sub->($t, \@entries);

    login1();

    $t->post_ok("$urlpref/new", form => {})->status_is(200);
    error('Es wurde zu wenig Text eingegeben \\(min. 2 Zeichen\\)');
}

1;

