use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 23;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user, $pass ) = qw(test test1234);

sub admin_login { Testinit::test_login(  $t, $admin, $apass ) };
sub user_login  { Testinit::test_login(  $t, $user,  $pass  ) };
sub logout      { Testinit::test_logout( $t                 ) };

note 'admin login';
admin_login();
$t->get_ok('/options/form')
  ->content_like(qr'active activeoptions">Optionen<')
  ->content_like(qr'Benutzerverwaltung')
  ->content_like(qr'<form action="/options/useradmin" method="POST">');

note 'nonadmins shall not see useradmin forms';
$dbh->do('UPDATE users SET admin=0 WHERE UPPER(name)=UPPER(?)', undef, $admin);
$t->get_ok('/options/form')
  ->content_like(qr'active activeoptions">Optionen<')
  ->content_unlike(qr'Benutzerverwaltung')
  ->content_unlike(qr'<form action="/options/useradmin" method="POST">');

note 'admins shall see useradmin forms';
$dbh->do('UPDATE users SET admin=1 WHERE UPPER(name)=UPPER(?)', undef, $admin);
$t->get_ok('/options/form')
  ->content_like(qr'active activeoptions">Optionen<')
  ->content_like(qr'Benutzerverwaltung')
  ->content_like(qr'<form action="/options/useradmin" method="POST">');

$t->post_ok('/options/useradmin', form => {})
  ->content_like(qr~Benutzername nicht angegeben~)
