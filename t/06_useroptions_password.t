use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 78;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user, $pass ) = qw(test test1234);

sub login { Testinit::test_login( $t, $user, $pass ) }
sub error { Testinit::test_error( $t, @_           ) }
sub info  { Testinit::test_info(  $t, @_           ) }

sub check_optionsform {
    $t->status_is(200)
      ->content_like(qr'active activeoptions">Optionen<')
      ->content_unlike(qr'Benutzerverwaltung')
      ->content_unlike(qr'<form action="/options/useradmin" method="POST">');
}

Testinit::test_add_users($t, $admin, $apass, $user, $pass);
login();
my $newpass = "$pass#";

note 'check user';
$t->get_ok('/')
  ->status_is(200)
  ->content_like(qr~Angemeldet als "$user"~)
  ->content_unlike(qr'background-color:')
  ->content_unlike(qr'font-size:');

$t->get_ok('/options/form');
check_optionsform();

note 'wrong use of password change form';
$t->post_ok('/options/password');
error('Altes Passwort nicht angegeben');
check_optionsform();

$t->post_ok('/options/password', form => { oldpw => $pass });
error('Neues Passwort nicht angegeben');
check_optionsform();

$t->post_ok('/options/password', form => { oldpw => $pass, newpw1 => $newpass });
error('Neues Passwort nicht angegeben');
check_optionsform();

$t->post_ok('/options/password', form => { oldpw => $pass, newpw1 => $newpass, newpw2 => $pass });
error('Neue Passworte stimmen nicht überein');
check_optionsform();

note 'working password change';
$t->post_ok('/options/password', form => { oldpw => $pass, newpw1 => $newpass, newpw2 => $newpass });
info('Passwortwechsel erfolgreich');
check_optionsform();
Testinit::test_logout($t);
$t->post_ok('/login', form => { username => $user, password => $pass })
  ->status_is(200);
error('Fehler bei der Anmeldung');
$pass = $newpass;
login();

