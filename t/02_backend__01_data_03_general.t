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
use Mock::Testuser;
use Ffc::Data::Auth;
srand;

Test::General::test_prepare();

my $maxuserid = $Test::General::Maxuserid;
my $maxcatid = $Test::General::Maxcatid;
my @users = @Test::General::Users;
my @categories = @Test::General::Categories;
sub test_r { &Test::General::test_r }
sub get_noneexisting_username { &Mock::Testuser::get_noneexisting_username }
sub test_get_rand_user { &Test::General::test_get_rand_user }
sub test_get_rand_category { &Test::General::test_get_rand_category }

use Test::More tests => 50;

use_ok('Ffc::Data::General');

{
    note('sub check_password_change( $newpw1, $newpw2, $oldpw )');
    my $user         = test_get_rand_user();
    my $old_password = $user->{password};
    $user->alter_password();
    my $new_password = $user->{password};
    check_call(
        \&Ffc::Data::General::check_password_change,
        check_password_change => {
            name => 'new password',
            good => $new_password,
            bad  => [ '', '        ', substr( $new_password, 0, 5 ) ],
            errormsg   => [ 'Kein Passwort', 'Passwort ungültig' ],
            emptyerror => 'Kein Passwort',
        },
        {
            name => 'new password repeat',
            good => $new_password,
            bad =>
              [ $old_password, '', '        ', substr( $new_password, 0, 5 ) ],
            errormsg => [
                'Das neue Passwort und dessen Wiederholung stimmen nicht',
                'Kein Passwort',
                'Passwort ungültig'
            ],
            emptyerror => 'Kein Passwort',
        },
        {
            name         => 'old password',
            good         => $old_password,
            bad          => [ '        ', substr( $old_password, 0, 5 ) ],
            errormsg     => ['Passwort ungültig'],
            noemptycheck => 1,
        },
    );
}
{
    note(' sub check_category_short_rules( $cshort )');
    check_call(
        \&Ffc::Data::General::check_category_short_rules,
        check_category_short_rules => {
            name => 'category short name',
            good => substr( test_r(), 0, 64 ),
            bad =>
              [ '', '    ', substr( test_r(), 0, 2 ) . '/' . substr( test_r(), 0, 3 ) ],
            emptyerror => 'Kein Kategoriekürzel angegeben',
            errormsg   => [
                'Kein Kategoriekürzel angegeben',
                'Kategoriekürzel ungültig'
            ],
        },
    );
    ok(
        Ffc::Data::General::check_category_short_rules( substr( test_r(), 0, 64 ) ),
        'category short fits the rules'
    );
}
{
    note('sub get_category_id( $cshort )');
    check_call(
        \&Ffc::Data::General::get_category_id,
        get_category_id => {
            name => 'category short name',
            good => test_get_rand_category()->[2],
            bad =>
              [ '', '    ', substr( test_r(), 0, 2 ) . '/' . substr( test_r(), 0, 3 ) ],
            emptyerror => 'Kein Kategoriekürzel angegeben',
            errormsg   => [
                'Kein Kategoriekürzel angegeben',
                'Kategoriekürzel ungültig'
            ],
        },
    );
    like( Ffc::Data::General::get_category_id( test_get_rand_category()->[2] ),
        qr(\d+), 'category id found' );
    {
        my $cat = test_get_rand_category();
        is( Ffc::Data::General::get_category_id( $cat->[2] ),
            $cat->[0], 'category id correct' );
    }
}
{
    note('sub check_category( $cshort )');
    check_call(
        \&Ffc::Data::General::check_category,
        check_category => {
            name => 'category short name',
            good => test_get_rand_category()->[2],
            bad =>
              [ '', '    ', substr( test_r(), 0, 2 ) . '/' . substr( test_r(), 0, 3 ) ],
            emptyerror => 'Kein Kategoriekürzel angegeben',
            errormsg   => [
                'Kein Kategoriekürzel angegeben',
                'Kategoriekürzel ungültig'
            ],
        },
    );
    ok( Ffc::Data::General::check_category( test_get_rand_category()->[2] ),
        'category short fits the rules' );
}
{
    note('sub get_category_short( $catid )');
    check_call(
        \&Ffc::Data::General::get_category_short,
        get_category_short => {
            name       => 'category id',
            good       => test_get_rand_category()->[0],
            bad        => [ '', '    ', 'aaaa', $maxcatid + 1 ],
            emptyerror => 'Keine Kategorieid angegeben',
            errormsg =>
              [ 'Keine Kategorieid angegeben', 'Kategorieid ungültig' ],
        },
    );
    ok( Ffc::Data::General::get_category_short( test_get_rand_category()->[0] ),
        'category id fits the rules' );
    {
        my $cat = test_get_rand_category();
        is( Ffc::Data::General::get_category_short( $cat->[0] ),
            $cat->[2], 'category short correct' );
    }
}
{
    note('sub get_useremail( $username )');
    check_call(
        \&Ffc::Data::General::get_useremail,
        get_usermail => {
            name => 'username',
            good => test_get_rand_user()->{name},
            bad  => [ '', '    ', 'aaaa', get_noneexisting_username() ],
            emptyerror => 'Kein Benutzername angegeben',
            errormsg   => [
                'Kein Benutzername angegeben',
                'Benutzername ungültig',
                'Benutzer unbekannt'
            ],
        },
    );
    like(
        Ffc::Data::General::get_useremail( test_get_rand_user()->{name} ),
        qr/.+\@.+\.\w+/,
        'user email retrieved'
    );
    {
        my $user = test_get_rand_user();
        is(
            Ffc::Data::General::get_useremail($user->{name} ),
            $user->{email},
            'user email retrieved correctly'
        );
    }
}
{
    note('sub get_userlist()');
    my $ret = Ffc::Data::General::get_userlist();
    ok( @$ret, 'user list is not empty' );
    is_deeply(
        [ sort { $a->[1] cmp $b->[1] } @$ret ],
        [
            map {
                [
                    Ffc::Data::Auth::get_userid( $_->{name} ),
                    $_->{name}, $_->{active}, $_->{admin}
                ]
            } sort { $a->{name} cmp $b->{name} } grep { $_->{active} } @users
        ],
        'userlist retrieved'
    );
}

