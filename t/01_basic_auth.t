use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use Testinit;

use Test::More tests => 3;
use Test::Mojo;

my ( $t, $path, $admin, $pass ) = Testinit::start_test();
$t->get_ok('/')->status_is(200)->content_like(qr/Mojolicious/i);

