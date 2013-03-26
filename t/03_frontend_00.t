use Mojo::Base -strict;

use Test::More tests => 5;
use Test::Mojo;
use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok('Ffc');
my $t = Test::Mojo->new('Ffc');
$t->get_ok('/')->status_is(200)->content_like(qr{Bitte melden Sie sich an});

{
    note('sub switch_category( $app, $controller, $act, $category, $msgsuserid )');
}
