use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
require Posttest;

use Test::Mojo;
use Test::More tests => 1146;

my $cname = 'pmsgs';

# runs a standardized test suite
#   run_tests( $Urlpref, $Check_env, $do_attachements, $do_edit, $do_delete );
# using $user1 (id=2) writing to $user2 (id=3), but not to $admin (id=1)
run_tests("/$cname/3", \&check_env, 1, 0, 0);

# checks for correct appearance of side effects
sub check_env {
    my ( $t, $entries, $delents, $delatts, $cnt ) = @_;
    $cnt = @$entries unless $cnt;
    ok 1, 'checked that sub "check_env" ran';
    my $newcnt = grep { $_->[5] } @$entries;
    test_data_security($t, $entries, $delents, $delatts);
}

# test that no one other than the conversationists have access to their messages
sub test_data_security {
    my ($t, $entries, $delents, $delatts) = @_;
    logina();
    for my $e ( @$entries, @$delents ) {
        for my $i ( 1 .. 3 ) {
            $t->get_ok("/$cname/$i/display/$e->[0]")->status_is(200);
            $t->content_unlike(qr~$e->[1]~)->content_unlike(qr~postbox~);
            for my $att ( @{ $e->[4] } ) {
                $t->content_unlike(qr"/$cname/$i/download/$att->[0]")
                  ->content_unlike(qr~alt="$att->[2]"~);
            }
            for my $att ( @{ $e->[4] } ) {
                $t->get_ok("/$cname/$i/download/$att->[0]")
                  ->status_is(404)
                  ->content_unlike(qr~$att->[1]~);
            }
        }
    }
}


