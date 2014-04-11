use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 51;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user, $pass ) = qw(test test1234);
Testinit::test_add_user( $t, $admin, $apass, $user, $pass );
sub admin { Testinit::test_login( $t, $admin, $apass ) }
sub user  { Testinit::test_login( $t, $user,  $pass  ) }
sub check_user {
    user();
    $t->get_ok('/options/form')
      ->status_is(200)
      ->content_unlike(qr~<h1>Kategorieverwaltung</h1>~)
      ->content_unlike(qr~<h2>Neue Kategorie anlegen:</h2>~)
      ->content_unlike(qr~<h2>Kategorie \&quot;[^<]*\&quot; ändern:</h2>~);
    admin();
}

admin();

note 'check whether category handling is available for admins, not for normal users';
$t->get_ok('/options/form')
  ->status_is(200)
  ->content_like(qr~<h1>Kategorieverwaltung</h1>~)
  ->content_like(qr~<h2>Neue Kategorie anlegen:</h2>~)
  ->content_unlike(qr~<h2>Kategorie \&quot;[^<]*\&quot; ändern:</h2>~);

check_user();



