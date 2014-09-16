use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
require Posttest;

use Test::Mojo;
use Test::More tests => 905;

# runs a standardized test suite
run_tests('/notes', \&check_env);

# checks for correct appearance of side effects
sub check_env {
    my ( $t, $entries ) = @_;
    login1();
    check_pages();
    login2();
    check_wrong_user($t, $entries);
    logina();
    check_wrong_user($t, $entries);
}

sub check_wrong_user {
    my ( $t, $entries ) = @_;
    $t->get_ok('/notes')->status_is(200);
    $t->content_unlike(qr~$_->[1]~) for @$entries;
    for my $e ( @$entries ) {
        $t->get_ok("/notes/display/$e->[0]")->status_is(200);
        $t->content_unlike(qr~$e->[1]~)->content_unlike(qr~postbox~);
        for my $att ( @{ $e->[4] } ) {
            $t->content_unlike(qr"/notes/download/$att->[0]")
              ->content_unlike(qr~alt="$att->[2]"~);
        }
        for my $att ( @{ $e->[4] } ) {
            $t->get_ok("/notes/download/$att->[0]")
              ->status_is(404)
              ->content_unlike(qr~$att->[1]~);
        }
    }
}



