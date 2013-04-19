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

use Test::More tests => 10261;

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

sleep 1.1; # we want to count new posts
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

    if ( @{$p{users_dont_see}} ) {
        note('check that the post will not be visible to the wrong users from the right methods');
        for my $user ( map {$_->{name}} @{$p{users_dont_see}} ) {
            for my $cat ( undef, @{$p{categories}} ) {
                run_code_not_returning($p{code_returns}, $user, undef,    $cat, \%p, $p{text}); # ohne query
                run_code_not_returning($p{code_returns}, $user, $p{text}, $cat, \%p, $p{text}); # mit query
            }
        }
    }
    else {
        note('everyone shall be able to see the post with the right method');
    }

    if ( $p{to} ) {
        note(q[for notes and msgs categories are allways ignored, so we don't need to check them]);
    }
    else {
        note('check that the post will not be visible to the right users from the right methods with the wrong categories');
        for my $user ( map {$_->{name}} @{$p{users_see}} ) {
            for my $cat ( grep {
                    if ( defined $p{cat} ) {
                        if ( !defined($_) or $p{cat} ne $_ ) { 1 } else { 0 }
                    }
                    else {
                        if ( defined($_) ) { 1 } else { 0 }
                    }
                } undef, @{$p{categories}} ) {
                run_code_not_returning($p{code_returns}, $user, undef,    $cat, \%p, $p{text}); # ohne query
                run_code_not_returning($p{code_returns}, $user, $p{text}, $cat, \%p, $p{text}); # mit query
            }
        }
    }
    note('check that the post will be visible to the right users from the right methods with the right category');
    for my $user ( map {$_->{name}} @{$p{users_see}} ) {
        run_code_returning($p{code_returns}, $user, undef,    $p{cat}, \%p, $p{text}); # ohne query
        run_code_returning($p{code_returns}, $user, $p{text}, $p{cat}, \%p, $p{text}); # mit query
    }
}, 1); # with notes

{
    for my $user ( keys %usertable ) {
        my $username = $usertable{$user}{name};
        my $userid = Ffc::Data::Auth::get_userid($username);
        note(qq'check counts for user "$user"');
        {
            my $privmsgs_count = Ffc::Data::Board::Views::count_newmsgs($username);
            my $privmsgs_test = (Ffc::Data::dbh()->selectrow_array('SELECT COUNT(id) FROM '.$Ffc::Data::Prefix.'posts WHERE user_to IS NOT NULL AND user_to=? AND user_from<>user_to', undef, $userid))[0];
            is($privmsgs_count, $privmsgs_test, 'new private message count is ok');
        }
        {
            my $notes_count = Ffc::Data::Board::Views::count_notes($username);
            my $notes_test = (Ffc::Data::dbh()->selectrow_array('SELECT COUNT(id) FROM '.$Ffc::Data::Prefix.'posts WHERE user_to IS NOT NULL AND user_to=? AND user_from=user_to', undef, $userid))[0];
            is($notes_count, $notes_test, 'notes count is ok');
        }
        {
            my $post_count = Ffc::Data::Board::Views::count_newposts($username);
            my $post_test = (Ffc::Data::dbh()->selectrow_array('SELECT COUNT(id) FROM '.$Ffc::Data::Prefix.'posts WHERE user_to IS NULL AND user_from<>?', undef, $userid))[0];
            is($post_count, $post_test, 'new posts count is ok');
        }
        {
            my $cats_count = Ffc::Data::Board::Views::get_categories($username);
            for my $cat ( undef, @Categories ) {
                my @params = ( $userid );
                my $sql = 'SELECT COUNT(p.id) FROM '.$Ffc::Data::Prefix.'posts p';
                if ( defined $cat ) {
                    $sql .= ' INNER JOIN '.$Ffc::Data::Prefix.'categories c ON c.id=p.category'
                }
                $sql .= ' WHERE user_from<>? AND user_to IS NULL';
                if ( defined $cat ) {
                    $sql .= ' AND c.short=?';
                    push @params, $cat;
                }
                else {
                    $sql .= ' AND p.category IS NULL';
                }

                my $cat_test = (Ffc::Data::dbh()->selectrow_array($sql, undef, @params))[0];

                my $cat_count = do{
                    if ( defined $cat ) {
                        (grep { $_->[1] eq $cat } @$cats_count)[0][2];
                    }
                    else {
                        (grep { $_->[1] eq '' } @$cats_count)[0][2];
                    }
                };

                is($cat_count, $cat_test, qq'new category "'.($cat//'<undef>').'" count ok');
            }
        }
    }
}

