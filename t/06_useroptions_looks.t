use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 33;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user1, $pass1, $user2, $pass2 ) = qw(test1 test1234 test2 test4321);

sub login { Testinit::test_login( $t, @_ ) }
sub error { Testinit::test_error( $t, @_ ) }
sub info  { Testinit::test_info(  $t, @_ ) }

Testinit::test_add_users($t, $admin, $apass, $user1, $pass1, $user2, $pass2);
login($user1, $pass1);

note 'check user';
$t->get_ok('/')
  ->status_is(200)
  ->content_like(qr~Angemeldet als "$user1"~)
  ->content_unlike(qr'background-color:')
  ->content_unlike(qr'font-size:');


