use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
require Posttest;

use Test::Mojo;
use Test::More tests => 52;

# runs a standardized test suite
run_tests( '/notes', \&check_env );

# checks for correct appearance of side effects
sub check_env {
    my ( $t, $entries ) = @_;
    #die $main::Postlimit;
    login1();
    if ( @$entries ) {
        $t->get_ok( '/notes/' )->status_is(200);
        for my $e ( @$entries ) {
            $t->content_like(qr/$e->[2]/);
        }
    }
    else {
        $t->get_ok( '/notes' )->status_is(200);
    }
    login2();
    $t->get_ok('/notes')->status_is(200);
    $t->content_unlike(qr~$_->[2]~) for @$entries;
}



