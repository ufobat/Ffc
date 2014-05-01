use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 149;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();

Testinit::test_login($t, $admin, $apass);
my ( $user, $pass ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_user( $t, $admin, $apass, $user, $pass );
Testinit::test_login($t, $admin, $apass);

$t->get_ok('/session')
  ->status_is(200)
  ->json_is('/admin', 1)
  ->json_is('/user', $admin)
  ->json_is('/backgroundcolor', '');

$t->get_ok('/options/bgcolor/color/Green')->status_is(200);
$t->get_ok('/session')
  ->status_is(200)
  ->json_is('/admin', 1)
  ->json_is('/user', $admin)
  ->json_is('/backgroundcolor', 'Green');

Testinit::test_login($t, $user, $pass);
$t->get_ok('/session')
  ->status_is(200)
  ->json_is('/admin', 0)
  ->json_is('/user', $user)
  ->json_is('/backgroundcolor', '');
$t->get_ok('/options/bgcolor/color/Yellow')->status_is(200);
$t->get_ok('/session')
  ->status_is(200)
  ->json_is('/admin', 0)
  ->json_is('/user', $user)
  ->json_is('/backgroundcolor', 'Yellow');

my %settings = %Ffc::Plugins::Config::Defaults;
delete $settings{cookiename};

sub test_config {
    $t->get_ok('/config')
      ->status_is(200);
    for my $sk ( keys %settings ) {
        $t->json_is("/$sk", $settings{$sk});
    }
    for my $k ( qw(cookiesecret cryptsalt ) ) {
        $t->json_hasnt("/$k");
    }
}

Testinit::test_login($t, $admin, $apass);
test_config();
Testinit::test_login($t, $user, $pass);
test_config();

%settings = (
    title => 'Webseitentitel',
    postlimit => 12,
    sessiontimeout => 21,
    commoncattitle => 'Ffc-Test',
    urlshorten => 4,
    backgroundcolor => 'Hintergrundfarbe',
    fixbackgroundcolor => 1,
    favicon => 'Favoritenicon-Link',
);

Testinit::test_login($t, $admin, $apass);
for my $key ( keys %settings ) {
    $t->post_ok("/options/admin/boardsettings/$key", form => { optionvalue => $settings{$key} } )
      ->status_is(200);
}
test_config();
Testinit::test_login($t, $user, $pass);
test_config();

