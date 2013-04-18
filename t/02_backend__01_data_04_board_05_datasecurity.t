use strict;
use warnings;
use 5.010;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Test::Callcheck;
use Test::General;
use Mock::Controller;
use Mock::Testuser;
use Ffc::Data::Board::Forms;
srand;

use Test::More tests => 9361;

Test::General::test_prepare();
sub r { &Test::General::test_r }

sub get_post { &Ffc::Data::Board::Views::get_post };

my %get_dispatch = (
    notes => sub { &Ffc::Data::Board::Views::get_notes },
    forum => sub { &Ffc::Data::Board::Views::get_forum },
    msgs  => sub { &Ffc::Data::Board::Views::get_msgs  },
);

my %usertable = (
    u1 => Mock::Testuser->new_active_user(),
    u2 => Mock::Testuser->new_active_user(),
    u3 => Mock::Testuser->new_active_user(),
);

my @testdata = (
  # [ text, from, to, cat, fetchcodename (which sub and which not), [who is allowed to see it] ],
    [ 'u1', undef, undef, 'forum', [ qw(u1 u2 u3) ] ],
    [ 'u2', undef, undef, 'forum', [ qw(u1 u2 u3) ] ],
    [ 'u3', undef, undef, 'forum', [ qw(u1 u2 u3) ] ],
    map({; [ 'u1', undef, $_->[2], 'forum', [ qw(u1 u2 u3 ) ] ] } @Test::General::Categories ),
    map({; [ 'u2', undef, $_->[2], 'forum', [ qw(u1 u2 u3 ) ] ] } @Test::General::Categories ),
    map({; [ 'u3', undef, $_->[2], 'forum', [ qw(u1 u2 u3 ) ] ] } @Test::General::Categories ),
    map({; [ $_, $_, undef, 'notes', [$_] ] } qw(u1 u2 u3)),
    [ 'u1', 'u2', undef, 'msgs', [ qw(u1 u2) ] ],
    [ 'u2', 'u1', undef, 'msgs', [ qw(u1 u2) ] ],
    [ 'u1', 'u3', undef, 'msgs', [ qw(u1 u3) ] ],
    [ 'u3', 'u1', undef, 'msgs', [ qw(u1 u3) ] ],
    [ 'u2', 'u3', undef, 'msgs', [ qw(u2 u3) ] ],
    [ 'u3', 'u2', undef, 'msgs', [ qw(u2 u3) ] ],
);

{
    my $i = 1;
    my $t = sub { sprintf '%s%03d', r(), $i++ };
    unshift @$_, $t->() for @testdata;
}

my @Categories = map { $_->[2] } @Test::General::Categories;
my $controller = Mock::Controller->new();

#note(Dumper \@testdata);

use_ok('Ffc::Data::Board::Views');

sub run_through_all {
    my $sub = shift;
    my $note = shift;
    for my $t ( @testdata ) {
        my $text             = $t->[0];
        my $from             = $usertable{$t->[1]};
        my $to               = defined $t->[2] ? $usertable{$t->[2]} : undef;
        my $cat              = $t->[3];
        my $code_returns     = $get_dispatch{$t->[4]};
        my @code_returns_not = map { $get_dispatch{$_} } grep {$t->[4] ne $_} keys %get_dispatch;
        my @users_see        = map { $usertable{$_} } @{$t->[5]};
        my @users_dont_see   = map { $usertable{$_} } grep { my $u = $_; if ( grep {$u eq $_} @{$t->[5]} ) { () } else { $u } } keys %usertable;
        note('test case: '
            .'from='      . $from->{name}
            .', to='      . ( $to->{name} // '<undef>' )
            .', cat='     . ( $cat // '<undef>' )
            .', sub=get_' . $t->[4]
        ) if $note;
        $sub->(
            text             => $text,
            from             => $from,
            to               => $to,
            cat              => $cat,
            code_returns     => $code_returns,
            code_returns_not => \@code_returns_not,
            users_see        => \@users_see,
            users_dont_see   => \@users_dont_see,
            get_dispatch     => \%get_dispatch,
            usertable        => \%usertable,
            categories       => \@Categories,
            controller       => $controller,
        );
    }
}

sub run_code { my ( $code, $user, $query, $cat, $p ) = @_;
    my $ret = [];
    eval { $ret = $code->($user, 1, $query, $cat, $p->{controller}) };
    ok(!$@, 'code ran ok');
    diag("ERROR: $@") if $@;
    return $ret;
}

sub run_code_returning { my ( $code, $user, $query, $cat, $p, $match ) = @_;
    my $ret = run_code($code, $user, $query, $cat, $p);
    if ( $match ) {
        my @good = grep { $match eq $_->{raw} } @$ret;
        ok(@good, 'code returned the desired post');
    }
    else {
        ok(@$ret, 'code returned something');
    }
}
sub run_code_not_returning { my ( $code, $user, $query, $cat, $p, $match ) = @_;
    my $ret = run_code($code, $user, $query, $cat, $p);
    if ( $match ) {
        my @good = grep { $match eq $_->{raw} } @$ret;
        ok(!@good, 'code returned the post also it should have not');
    }
    else {
        ok(!@$ret, 'code returned nothing as expected');
    }
}

run_through_all(sub{ # Testdaten einspielen
    my %p = @_;
    Ffc::Data::Board::Forms::insert_post($p{from}{name}, $p{text}, $p{cat}, $p{to}{name});
});

$Ffc::Data::Limit = scalar(@testdata) + 1;

run_through_all(sub{ # Tests durchführen
    my %p = @_;
    note('check that the post will not be visible from wrong methods');
    for my $code ( @{$p{code_returns_not}} ) {
        for my $user ( map {$_->{name}} values %{$p{usertable}} ) {
            for my $cat ( undef, @{$p{categories}} ) {
                run_code_not_returning($code, $user, undef,    $cat, \%p, $p{text}); # ohne query
                run_code_not_returning($code, $user, $p{text}, $cat, \%p, $p{text}); # mit query
            }
        }
    }
    note('check that the post will not be visible to the wrong users from the right methods');
    note('check that the post will is visible to the right users from the right methods');
}, 1); # with notes

diag('counts müssen auch noch alle getestet werden!!!');
sleep 1.1; # just to be on the save side


