use strict;
use warnings;
use utf8;
use 5.010;

sub run_tests {
    my ( $urlpref, $check_env_sub, $t, $users ) = @_;
    my @entries;

    # shortcuts for user logins
    my $logina = sub { Testinit::test_login( $t, $users->[0][0], $users->[0][1] ) };
    my $login1 = sub { Testinit::test_login( $t, $users->[1][0], $users->[1][1] ) };
    my $login2 = sub { Testinit::test_login( $t, $users->[2][0], $users->[2][1] ) };

    my $i = sub { Testinit::test_info(    $t, @_ ) };
    my $e = sub { Testinit::test_error(   $t, @_ ) };
    my $w = sub { Testinit::test_warning( $t, @_ ) };

    $check_env_sub->(\@entries);

    $login1->();

    $t->post_ok("$urlpref/new", form => {})->status_is(200);
    $e->('Es wurde zu wenig Text eingegeben \\(min. 2 Zeichen\\)');
}

1;

