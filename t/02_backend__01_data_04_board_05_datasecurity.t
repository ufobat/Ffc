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
use Ffc::Data::Auth;
use Ffc::Data::Board;
use Ffc::Data::Board::Forms;
srand;

use Test::More tests => 1;

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
    [ 'u1', undef, undef, 'posts', [ qw(u1 u2 u3) ] ],
    [ 'u2', undef, undef, 'posts', [ qw(u1 u2 u3) ] ],
    [ 'u3', undef, undef, 'posts', [ qw(u1 u2 u3) ] ],
    map({; [ 'u1', undef, $_->[2], 'posts', [ qw(u1 u2 u3 ) ] ] } @Test::General::Categories ),
    map({; [ 'u2', undef, $_->[2], 'posts', [ qw(u1 u2 u3 ) ] ] } @Test::General::Categories ),
    map({; [ 'u3', undef, $_->[2], 'posts', [ qw(u1 u2 u3 ) ] ] } @Test::General::Categories ),
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

note(Dumper \@testdata);

use_ok('Ffc::Data::Board::Views');

