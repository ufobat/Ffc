use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
require Posttest;

use Test::Mojo;
use Test::More tests => 179;

# runs a standardized test suite
run_tests('/notes', \&check_env);

# checks for correct appearance of side effects
sub check_env {
    my ( $t, $entries ) = @_;
    login1();
    check_pages();
    login2();
    $t->get_ok('/notes')->status_is(200);
    $t->content_unlike(qr~$_->[1]~) for @$entries;
}



