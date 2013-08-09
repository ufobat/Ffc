use Mojo::Base -strict;

use Test::Mojo;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Mock::Controller;
use Test::General;

use Test::More tests => 4;

my $t = Test::General::test_prepare_frontend('Ffc');
$t->get_ok('/')->status_is(200)->content_like(qr{Bitte melden Sie sich an});

