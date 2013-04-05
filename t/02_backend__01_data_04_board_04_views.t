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

    sleep 2
      ; # Das System funktionert nur sekundengenau und gibt im Zweifelsfall immer mehr zurück
    {
        for (qw(forum msgs notes)) {
            eval { Ffc::Data::Board::update_user_stats( $user->{name}, $_ ) };
            diag(
qq(update users status for act "$_" before next insert failed: $@)
            ) if $@;
        }
    }
    sleep 2
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
    sleep 2
      ; # Das System funktionert nur sekundengenau und gibt im Zweifelsfall immer mehr zurück
    {
        for (qw(forum msgs notes)) {
            eval { Ffc::Data::Board::update_user_stats( $user->{name}, $_ ) };
            diag(
qq(update users status for act "$_" before next insert failed: $@)
            ) if $@;
        }
    }
    sleep 2
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
        sleep 2
          ; # Das System funktionert nur sekundengenau und gibt im Zweifelsfall immer mehr zurück
        {
            for (qw(forum msgs notes)) {
                eval {
                    Ffc::Data::Board::update_user_stats( $user->{name}, $_ );
                };
                diag(
qq(update users status for act "$_" before next insert failed: $@)
                ) if $@;
            }
        }
        sleep 2
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
            sleep 2
              ; # Das System funktionert nur sekundengenau und gibt im Zweifelsfall immer mehr zurück
            {
                for (@cats) {
                    eval {
                        Ffc::Data::Board::update_user_stats( $user->{name},
                            'forum', $_ );
                    };
                    diag("update users status before next insert failed: $@")
                      if $@;
                }
            }
            sleep 2;
        }
    }
}
{
    note(q{sub get_notes( $username )});
}
{
    note(q{sub get_forum( $username )});
}
{
    note(q{sub get_msgs( $username )});
}
{
    note(q{sub get_post( $username )});
}
