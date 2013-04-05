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

use Test::More tests => 91;

Test::General::test_prepare();

use_ok('Ffc::Data::Board::Views');

{
    my $user  = Mock::Testuser->new_active_user();
    my $user2 = Mock::Testuser->new_active_user();
    my @tests = (
        {
            name    => 'count_newmsgs',
            act     => 'msgs',
            note    => q{sub count_newmsgs( $username )},
            code    => \&Ffc::Data::Board::Views::count_newmsgs,
            insert1 => $user2->{name},
            insert2 => $user->{name},
        },
        {
            name    => 'count_newposts',
            act     => 'forum',
            note    => q{sub count_newpost( $username )},
            code    => \&Ffc::Data::Board::Views::count_newposts,
            insert1 => $user2->{name},
            insert2 => undef,
        },
        {
            name    => 'count_notes',
            act     => 'notes',
            note    => q{sub count_notes( $username )},
            code    => \&Ffc::Data::Board::Views::count_notes,
            insert1 => $user->{name},
            insert2 => $user->{name},
            count   => sub { $_[0]->{count_before} + $_[0]->{count_after} },
        }
    );
    note('preparing count tests');
    for my $t (@tests) {
        {
            my $ret;
            eval { $ret = $t->{code}->( $user->{name} ) };
            ok( !$@, qq'counting code "$t->{name}" ran good' );
            is( $ret, 0,
qq'counting code "$t->{name}" returned zero because the database is still empty'
            );
        }
    }
    for my $t (@tests) {
        my $cnt = 10 + int rand 30;
        $t->{count_before} = $cnt;
        for ( 1 .. $cnt ) {
            my $text = Test::General::test_r();
            eval {
                Ffc::Data::Board::Forms::insert_post( $t->{insert1}, $text,
                    undef, $t->{insert2} );
            };
            diag("insert test data before userstats update failed: $@") if $@;
        }
    }

    sleep 1.1
      ; # Das System funktionert nur sekundengenau und gibt im Zweifelsfall immer mehr zurück
    for (qw(forum msgs notes)) {
        eval { Ffc::Data::Board::update_user_stats( $user->{name}, $_ ) };
        diag(qq(update users status for act "$_" before next insert failed: $@))
          if $@;
    }
    sleep 1.1
      ; # Das System funktionert nur sekundengenau und gibt im Zweifelsfall immer mehr zurück

    for my $t (@tests) {
        my $cnt = 10 + int rand 30;
        $t->{count_after} = $cnt;
        for ( 1 .. $cnt ) {
            my $text = Test::General::test_r();
            eval {
                Ffc::Data::Board::Forms::insert_post( $t->{insert1}, $text,
                    undef, $t->{insert2} );
            };
            diag("insert test data after userstats update failed: $@") if $@;
        }
    }

    for my $t (@tests) {
        note( $t->{note} );
        $t->{count} =
          exists $t->{count} ? $t->{count}->($t) : $t->{count_after};
        check_call(
            $t->{code},
            $t->{name} => {
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
        );
        {
            my $ret;
            eval { $ret = $t->{code}->( $user->{name} ) };
            ok( !$@, qq'counting code "$t->{name}" ran good' );
            ok( $ret,
                qq'counting code "$t->{name}" returned something as expected' );
            is( $ret, $t->{count}, qq'counting of "$t->{name}" works' );
        }
    }
}
{
    note(q{sub get_categories( $username )});
    my $user = Mock::Testuser->new_active_user();
    sleep 1.1
      ; # Das System funktionert nur sekundengenau und gibt im Zweifelsfall immer mehr zurück
    for (qw(forum msgs notes)) {
        eval { Ffc::Data::Board::update_user_stats( $user->{name}, $_ ) };
        diag(qq(update users status for act "$_" before next insert failed: $@))
          if $@;
    }
    sleep 1.1
      ; # Das System funktionert nur sekundengenau und gibt im Zweifelsfall immer mehr zurück
    my @ret = check_call(
        \&Ffc::Data::Board::Views::get_categories,
        get_categories => {
            name => 'user name',
            good => $user->{name},
            bad  => [ '', '   ', Mock::Testuser::get_noneexisting_username() ],
            errormsg => [
                'Kein Benutzername angegeben',
                'Benutzername ungültig',
                'Benutzer unbekannt',
            ],
            emptyerror => 'Kein Benutzername angegeben',
        },
    );
    ok( @ret, 'something was returned' );
    my @cats = map { $_->[2] } @Test::General::Categories;
    is(
        scalar( @{ $ret[0] } ),
        ( scalar(@cats) + 1 ),
        'data for every single category including "Allgemein" returned'
    );
    for my $r ( @{ $ret[0] } ) {
        ok( grep( $r->[1], @cats ), qq'return value "$r->[1]" is a category' )
          if $r->[1];
        is( $r->[2], 0,
            qq'return value of "$r->[1]" is zero before the actual inserts' );
    }

    for my $i ( 0 .. 2 )
    {    # run multiple tests to test creation of category-logging
        note("category count run number '$i'");
        sleep 1.1
          ; # Das System funktionert nur sekundengenau und gibt im Zweifelsfall immer mehr zurück
        for (qw(forum msgs notes)) {
            eval { Ffc::Data::Board::update_user_stats( $user->{name}, $_ ); };
            diag(
qq(update users status for act "$_" before next insert failed: $@)
            ) if $@;
        }
        sleep 1.1
          ; # Das System funktionert nur sekundengenau und gibt im Zweifelsfall immer mehr zurück
        my $user2 = Mock::Testuser->new_active_user();
        my %catcounter;
        for my $cat ( '', @cats ) {
            my $cnt = 10 + int rand 30;
            $catcounter{$cat} = $cnt;
            for ( 1 .. $cnt ) {
                my $text = Test::General::test_r();
                eval {
                    Ffc::Data::Board::Forms::insert_post( $user2->{name},
                        $text, $cat );
                };
                diag("insert test data before userstats update failed: $@")
                  if $@;
            }

# diag( qq(inserted "$cnt" posts from "$user2->{name}" into "$cat" to read for "$user->{name}"));
        }
        my $ret;
        {
            eval {
                $ret = Ffc::Data::Board::Views::get_categories( $user->{name} );
            };
            ok( !$@, 'categories retrieved' );
            diag($@) if $@;
        }
        ok( @$ret, 'data for categories retrieved' );
        is(
            scalar(@$ret),
            ( scalar(@cats) + 1 ),
            'data for every single category including "Allgemein" returned'
        );
        my %ret = map { $_->[1] => $_->[2] } @$ret;
        for my $cat ( '', @cats ) {

            # diag("$cat => $ret{$cat} / $catcounter{$cat}");
            is( $ret{$cat}, $catcounter{$cat},
                qq(counter for category "$cat" returned the correct value) );
        }

        if ( $i < 2 ) {
            sleep 1.1
              ; # Das System funktionert nur sekundengenau und gibt im Zweifelsfall immer mehr zurück
            for (@cats) {
                eval {
                    Ffc::Data::Board::update_user_stats( $user->{name},
                        'forum', $_ );
                };
                diag("update users status before next insert failed: $@")
                  if $@;
            }
            sleep 1.1;
        }
    }
}

{
    note('testing date retrieving');
    sleep 1.1;    # works only on seconds scale
    my $user = Mock::Testuser->new_active_user();
    for (qw(forum msgs notes)) {
        eval { Ffc::Data::Board::update_user_stats( $user->{name}, $_ ) };
        diag(qq(update users status for act "$_" before next insert failed: $@))
          if $@;
    }
    my $usertest = {
        name     => 'user name',
        good     => $user->{name},
        bad      => [ '', '   ', Mock::Testuser::get_noneexisting_username() ],
        errormsg => [
            'Kein Benutzername angegeben',
            'Benutzername ungültig',
            'Benutzer unbekannt',
        ],
        emptyerror => 'Kein Benutzername angegeben',
    };
    my @paramstest = (
        { name => 'page',  good => 1,                       noemptycheck => 1 },
        { name => 'query', good => Test::General::test_r(), noemptycheck => 1 },
        {
            name     => 'category',
            good     => Test::General::test_get_rand_category()->[2],
            bad      => [ ' ', 'a', Test::General::test_get_non_category_short() ],
            errormsg => ['Kategoriekürzel ungültig', 'Kategorie ungültig'],
            noemptycheck => 1
        },
        {
            name         => 'controller',
            good         => Mock::Controller->new(),
            noemptycheck => 1
        },
    );
    {
        note(
q{sub get_post( $action, $username, $postid, $page, $search, $category, $controller )}
        );
        my $code     = \&Ffc::Data::Board::Views::get_post;
        my $name     = 'get_post';
        my $acttest = {
            name       => 'action',
            good       => 'forum',
            bad        => [ '', '   ', 'aaaaaaaaaaaaa' ],
            emptyerror => 'Aktion nicht angegeben',
            errormsg   => [ 'Aktion nicht angegeben', 'Aktion unbekannt' ],
        };
        my $posttest = {
            name => 'postid',
            good => do {
                my @ids = map { $_->[0] } @{
                    Ffc::Data::dbh()->selectall_arrayref(
                            'SELECT id FROM '
                          . $Ffc::Data::Prefix
                          . 'posts WHERE user_to IS NULL'
                    )
                };
                $ids[ int rand $ids ];
            },
            bad        => [ '', '  ', 'aaaa', (Test::General::test_get_max_postid + 1)],
            errormsg  => [q{Keine ID für den Beitrag angegeben}, (q{Ungültige ID für den Beitrag}) x 2, q{Kein Datensatz gefunden}],
            emptyerror => q{Keine ID für den Beitrag angegeben},
        };
        my $post = check_call( $code, $name, $acttest, $usertest, $posttest,
            @paramstest );
        is(
            $post->{raw},
            (
                Ffc::Data::dbh()->selectrow_array(
                    'SELECT textdata FROM '
                      . $Ffc::Data::Prefix
                      . 'posts WHERE id=?',
                    undef,
                    $posttest->{good}
                )
              )[0],
            'returned a single post ok'
        );
    }
    die;
    {
        note(
q{sub get_notes( $username, $page, $search, $category, $controller )}
        );
        my $code = \&Ffc::Data::Board::Views::get_notes;
        my $name = 'get_notes';
        check_call( $code, $name, $usertest, @paramstest );
    }
    {
        note(
q{sub get_forum( $username, $page, $search, $category, $controller )}
        );
        my $code = \&Ffc::Data::Board::Views::get_forum;
        my $name = 'get_forum';
        check_call( $code, $name, $usertest, @paramstest );
    }
    {
        note(
            q{sub get_msgs( $username, $page, $search, $category, $controller )}
        );
        my $code = \&Ffc::Data::Board::Views::get_msgs;
        my $name = 'get_msgs';
        check_call( $code, $name, $usertest, @paramstest );
    }
}
