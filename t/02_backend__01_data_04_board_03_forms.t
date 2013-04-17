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
srand;

use Test::More tests => 61;

Test::General::test_prepare();

use_ok('Ffc::Data::Board::Forms');

{
    note('sub insert_post( $username, $data, $category, $recipientname )');
    {
        my $user    = Mock::Testuser->new_active_user();
        my $user2   = Mock::Testuser->new_active_user();
        my $posting = join "\n",
          map { Test::General::test_r() } 0 .. ( 5 + int rand 10 );
        my $category = Test::General::test_get_rand_category()->[2];
        check_call(
            \&Ffc::Data::Board::Forms::insert_post,
            insert_post => {
                name => 'user name',
                good => $user->{name},
                bad =>
                  [ '', '   ', Mock::Testuser::get_noneexisting_username() ],
                errormsg => [
                    'Kein Benutzername angegeben',
                    'Benutzername ungültig',
                    'Benutzer unbekannt',
                ],
                emptyerror => 'Kein Benutzername angegeben',
            },
            {
                name => 'text entry',
                good => $posting,
                bad  => [ '', ' ', 'a' ],
                errormsg   => [ 'Kein Beitrag angegeben', 'Beitrag ungültig' ],
                emptyerror => 'Kein Beitrag angegeben',
            },
            {
                name => 'category short',
                good => $category,
                bad  => [ '   ', Test::General::test_get_non_category_short() ],
                errormsg =>
                  [ 'Kategoriekürzel ungültig', 'Kategorie ungültig' ],
                noemptycheck => 1,
            },
            {
                name => 'recipient name',
                good => $user2->{name},
                bad  => [ '   ', Mock::Testuser::get_noneexisting_username() ],
                errormsg => [ 'Benutzername ungültig', 'Benutzer unbekannt', ],
                noemptycheck => 1,
            },
        );
    }
    {
        my @tests = (
            {
                user    => Mock::Testuser->new_active_user()->{name},
                posting => join( "\n",
                    map { Test::General::test_r() } 0 .. ( 5 + int rand 10 ) ),
                user2    => undef,
                category => undef,
            },
            {
                user    => Mock::Testuser->new_active_user()->{name},
                posting => join( "\n",
                    map { Test::General::test_r() } 0 .. ( 5 + int rand 10 ) ),
                user2    => Mock::Testuser->new_active_user()->{name},
                category => undef,
            },
            {
                user    => Mock::Testuser->new_active_user()->{name},
                posting => join( "\n",
                    map { Test::General::test_r() } 0 .. ( 5 + int rand 10 ) ),
                user2    => undef,
                category => Test::General::test_get_rand_category()->[2],
            },
            {
                user    => Mock::Testuser->new_active_user()->{name},
                posting => join( "\n",
                    map { Test::General::test_r() } 0 .. ( 5 + int rand 10 ) ),
                user2    => Mock::Testuser->new_active_user()->{name},
                category => Test::General::test_get_rand_category()->[2],
            },
        );
        for my $t (@tests) {
            my ( $user, $posting, $user2, $category ) =
              ( $t->{user}, $t->{posting}, $t->{user2}, $t->{category} );
            {
                eval {
                    Ffc::Data::Board::Forms::insert_post( $user, $posting,
                        $category, $user2 );
                };
                ok( !$@, 'test run ok' );
                diag($@) if $@;
            }
            my $dat = Test::General::test_get_max_post();
            is( $posting,                           $dat->[1], 'text is ok' );
            is( Ffc::Data::Auth::get_userid($user), $dat->[2], 'author is ok' );
            is( Ffc::Data::Auth::get_userid($user2),
                $dat->[3], 'recipient is ok' )
              if $user2;
            my $catid = undef;
            $catid = Ffc::Data::General::get_category_id($category) if $category and not $user2;
            is( $catid, $dat->[4], 'author is ok' )
        }
    }
}
{
    note('sub update_post( $username, $data, $postid )');
    my $user    = Mock::Testuser->new_active_user()->{name};
    my $posting = join "\n",
      map { Test::General::test_r() } 0 .. ( 5 + int rand 10 );
    {
        eval { Ffc::Data::Board::Forms::insert_post( $user, $posting ) };
        ok( !$@, 'new test post created' );
        diag($@) if $@;
    }
    my $post = Test::General::test_get_max_post();
    my $postid = $post->[0];
    is( $post->[1], $posting, 'new test post created ok' );
    check_call(
        \&Ffc::Data::Board::Forms::update_post,
        update_post => {
            name => 'user name',
            good => $user,
            bad  => [ '', '   ', Mock::Testuser::get_noneexisting_username() ],
            errormsg => [
                'Kein Benutzername angegeben',
                'Benutzername ungültig',
                'Benutzer unbekannt',
            ],
            emptyerror => 'Kein Benutzername angegeben',
        },
        {
            name => 'text entry',
            good => $posting,
            bad  => [ '', ' ', 'a' ],
            errormsg   => [ 'Kein Beitrag angegeben', 'Beitrag ungültig' ],
            emptyerror => 'Kein Beitrag angegeben',
        },
        {
            name => 'post id',
            good => $postid,
            bad  => [ '', '  ', 'aaaa' ],
            errormsg   => [ 'Keine Postid angegeben', 'Postid ungültig' ],
            emptyerror => 'Keine Postid angegeben',
        },
    );
    is( Test::General::test_get_max_post()->[1],
        $posting, 'posting updated ok' );
}
{
    note('sub delete_post( $username, $postid )');
    my $user    = Mock::Testuser->new_active_user()->{name};
    my $posting = join "\n",
      map { Test::General::test_r() } 0 .. ( 5 + int rand 10 );
    {
        eval { Ffc::Data::Board::Forms::insert_post( $user, $posting ) };
        ok( !$@, 'new test post created' );
        diag($@) if $@;
    }
    my $post = Test::General::test_get_max_post();
    my $postid = $post->[0];
    is( $post->[1], $posting, 'new test post created ok' );
    ok((Ffc::Data::dbh()->selectrow_array('SELECT COUNT(id) FROM '.$Ffc::Data::Prefix.'posts WHERE id=?', undef, $postid ))[0], 'posting does exist before deletion' );
    check_call(
        \&Ffc::Data::Board::Forms::delete_post,
        delete_post => {
            name => 'user name',
            good => $user,
            bad  => [ '', '   ', Mock::Testuser::get_noneexisting_username() ],
            errormsg => [
                'Kein Benutzername angegeben',
                'Benutzername ungültig',
                'Benutzer unbekannt',
            ],
            emptyerror => 'Kein Benutzername angegeben',
        },
        {
            name => 'post id',
            good => $postid,
            bad  => [ '', '  ', 'aaaa' ],
            errormsg   => [ 'Keine Postid angegeben', 'Postid ungültig' ],
            emptyerror => 'Keine Postid angegeben',
        },
    );
    ok(!(Ffc::Data::dbh()->selectrow_array('SELECT COUNT(id) FROM '.$Ffc::Data::Prefix.'posts WHERE id=?', undef, $postid ))[0], 'posting does not exist after deletion anymore' );
}
