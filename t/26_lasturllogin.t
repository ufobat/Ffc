use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 44;

###############################################################################
note q~Testsystem vorbereiten~;
###############################################################################
my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $u, $p) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $u, $p );

###############################################################################
note q~Normalen Login-Test ausführen~;
###############################################################################
$t->post_ok('/login', form => { username => $u, password => $p })
  ->status_is(302)->header_is(Location => '/');

$t->post_ok('/topic/new', form => {titlestring => 'abc', textdata => 'def'})
  ->status_is(302)->header_like( Location => qr{\A/topic/1}xms );

note q~Testthema anlegen~;
$t->get_ok('/topic/1')->status_is(200)
  ->content_like(qr'abc')->content_like(qr'def');

note q~Versuch, unangemeldet ins Testthema einzusteigen~;
Testinit::test_logout($t);
$t->get_ok('/topic/1')->status_is(200)
  ->content_like(qr~<title>Anmeldung</title>~);

note q~Anmeldung direkt ins Testthema~;
$t->post_ok('/login', form => { username => $u, password => $p })
  ->status_is(302)->header_is(Location => '/topic/1');

note q~Nicht mehr direkt ins Testthema einsteigen beim Login~;
Testinit::test_logout($t);
$t->post_ok('/login', form => { username => $u, password => $p })
  ->status_is(302)->header_is(Location => '/');

