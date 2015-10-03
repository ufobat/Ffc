use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use utf8;

use Test::Mojo;
use Test::More tests => 43;

###############################################################################
note q~Testsystem vorbereiten~;
###############################################################################
my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1 );
sub login_admin { Testinit::test_login( $t, $admin, $apass ) }
sub login_user1 { Testinit::test_login( $t, $user1, $pass1 ) }

###############################################################################
note q~Testdatenhaltung~;
###############################################################################
my ( $email, $emailon ,$birthdate, $infos ) = ('', '');

###############################################################################
note q~Testroutinen~;
###############################################################################
sub check_data {
    login_admin();
    $t->get_ok('/pmsgs')->status_is(200);
    if ( $birthdate ) {
        $t->content_like(qr~$user1~);
    }
}

sub test_data {
    my ( $em, $eo, $bd, $io, $berr, $ierr ) = @_;
    login_user1();
}

