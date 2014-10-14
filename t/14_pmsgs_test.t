use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
require Posttest;

use Test::Mojo;
use Test::More tests => 333;

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
    #check_pages(\&login2, "/$cname/2");
}


