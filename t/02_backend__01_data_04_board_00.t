use strict;
use warnings;
use 5.010;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Mojolicious;
use Mock::Config;
use Mock::Database;
use Mock::Testuser;
use Mock::Controller::App;
use Test::Callcheck;
use Test::General;
use Ffc::Data::Auth;
srand;

use Test::More tests => 24;

Test::General::test_prepare();

use_ok('Ffc::Data::Board');

{
    note('sub update_user_stats( $username, $act, $category ); # call_check');
    check_call(
        \&Ffc::Data::Board::update_user_stats,
        update_user_stats => {
            name => 'username',
            good => Test::General::test_get_rand_user()->{name},
            bad  => [
                '',                      '        ',
                Test::General::test_get_non_username()
            ],
            errormsg => [
                'Kein Benutzername angegeben',
                'Benutzername ungültig',
                'Benutzer unbekannt'
            ],
            emptyerror => 'Kein Benutzername angegeben',
        },
        {
            name         => 'act',
            good         => 'forum',
            bad          => [ '', '   ', 'aaa' ],
            errormsg     => ['Abschnitt ungültig'],
            noemptycheck => 1,
        },
        {
            name => 'category short',
            good => Test::General::test_get_rand_category()->[2],
            bad => [ '        ', Test::General::test_get_non_category_short() ],
            errormsg => [ 'Kategoriekürzel ungültig', 'Kategorie ungültig' ],
            noemptycheck => 1,
        },
    );
}
{
    note('sub update_user_stats( $username, "msgs" ); # data test msgs');
    my $user         = Test::General::test_get_rand_user();
    my $username     = $user->{name};
    my $userid       = Ffc::Data::Auth::get_userid( $username );
    my $dbh          = Ffc::Data::dbh();
    my $get_lastseen = sub {
        (
            @{
                $dbh->selectall_arrayref(
                    'SELECT u.lastseenmsgs, u.lastseenforum FROM '
                      . $Ffc::Data::Prefix
                      . 'users u WHERE u.id=?',
                    undef, $userid
                )
            }
        )[0];
    };
    my $before = $get_lastseen->();
    sleep 1.1;
    ok(
        (
            just_call(
                sub { Ffc::Data::Board::update_user_stats( $username, 'msgs' ) }
            )
        )[0],
        'test run ok'
    );
    my $after = $get_lastseen->();
    cmp_ok( $before->[0], 'lt', $after->[0], 'msgs lastseen ok (altered)' );
    cmp_ok( $before->[1], 'eq', $after->[1], 'forum lastseen ok (unaltered)' );
}
{
    note(
'sub update_user_stats( $username, "forum" ); # data test forum without category'
    );
    my $user         = Test::General::test_get_rand_user();
    my $username     = $user->{name};
    my $userid       = Ffc::Data::Auth::get_userid( $username );
    my $dbh          = Ffc::Data::dbh();
    my $get_lastseen = sub {
        (
            @{
                $dbh->selectall_arrayref(
                    'SELECT u.lastseenmsgs, u.lastseenforum FROM '
                      . $Ffc::Data::Prefix
                      . 'users u WHERE u.id=?',
                    undef, $userid
                )
            }
        )[0];
    };
    my $before = $get_lastseen->();
    sleep 1.1;
    ok(
        (
            just_call(
                sub {
                    Ffc::Data::Board::update_user_stats( $username, 'forum' );
                }
            )
        )[0],
        'test run ok'
    );
    my $after = $get_lastseen->();
    cmp_ok( $before->[0], 'eq', $after->[0], 'msgs lastseen ok (unaltered)' );
    cmp_ok( $before->[1], 'lt', $after->[1], 'forum lastseen ok (altered)' );
}
{
    note(
'sub update_user_stats( $username, "forum", $category ); # data test forum with category'
    );
    my $user         = Test::General::test_get_rand_user();
    my $username     = $user->{name};
    my $userid       = Ffc::Data::Auth::get_userid( $username );
    my $category     = Test::General::test_get_rand_category();
    my $dbh          = Ffc::Data::dbh();
    my $get_lastseen = sub {
        (
            @{
                $dbh->selectall_arrayref(
                    'SELECT u.lastseenmsgs, u.lastseenforum FROM '
                      . $Ffc::Data::Prefix
                      . 'users u WHERE u.id=?',
                    undef, $userid
                )
            }
        )[0];
    };
    my $get_lastseen_cat = sub {
        $dbh->selectall_arrayref(
            'SELECT l.lastseen FROM '
              . $Ffc::Data::Prefix
              . 'lastseenforum l WHERE l.userid=? AND l.category=?',
            undef, $userid, $category->[0]
        )->[0]->[0];
    };
    my $before     = $get_lastseen->();
    my $before_cat = $get_lastseen_cat->();
    ok( !$before_cat, 'nothing yet to see' );
    sleep 1.1;
    ok(
        (
            just_call(
                sub {
                    Ffc::Data::Board::update_user_stats( $username, 'forum',
                        $category->[2] );
                }
            )
        )[0],
        'first test run ok'
    );
    my $after           = $get_lastseen->();
    my $after_first_cat = $get_lastseen_cat->();
    cmp_ok( $before->[0], 'eq', $after->[0], 'msgs lastseen ok (unaltered)' );
    cmp_ok( $before->[1], 'eq', $after->[1], 'forum lastseen ok (unaltered)' );
    ok( $after_first_cat, 'after first run, lastseenforum-stat was inserted' );
    sleep 1.1;
    ok(
        (
            just_call(
                sub {
                    Ffc::Data::Board::update_user_stats( $username, 'forum',
                        $category->[2] );
                }
            )
        )[0],
        'second test run ok'
    );
    my $after_second_cat = $get_lastseen_cat->();
    cmp_ok( $after_first_cat, 'lt', $after_second_cat,
        'statistics updated ok in lastseenforum' );
}

