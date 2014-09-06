use strict;
use warnings;
use utf8;
use 5.010;

use Testinit;
use Test::Mojo;

our $Postlimit = 3;

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

sub set_postlimit {
    my ( $t ) = @_;
    $t->post_ok('/options/admin/boardsettings/postlimit',
        form => { optionvalue => $Postlimit })
      ->status_is(200);
}

sub run_tests {
    my ( $urlpref, $check_env_sub ) = @_;
    set_postlimit($t);
    my @entries;

    # shortcuts for user logins

    $check_env_sub->($t, \@entries);

    login1();

    $t->post_ok("$urlpref/new", form => {})->status_is(200);
    error('Es wurde zu wenig Text eingegeben \\(min. 2 Zeichen\\)');
}

1;

