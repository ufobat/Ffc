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
use Ffc::Data::Auth;
srand;

use Test::More tests => 50;

note('doing some preparations');
my $config = Mock::Config->new->{config};
my $app    = Mojolicious->new();
$app->log->level('error');
Ffc::Data::set_config($app);
Mock::Database::prepare_testdatabase();
my @users = ( map { Mock::Testuser->new_active_user() } 3 .. 5 + int rand 20 );
my @categories = @{
    Ffc::Data::dbh()->selectall_arrayref(
            'SELECT "id", "name", "short" FROM '
          . $Ffc::Data::Prefix
          . 'categories'
    )
};
my $maxcatid = (
    Ffc::Data::dbh()->selectall_arrayref(
        'SELECT MAX("id") FROM ' . $Ffc::Data::Prefix . 'categories'
    )
)[0];
my $maxuserid = (
    Ffc::Data::dbh()->selectall_arrayref(
        'SELECT MAX("id") FROM ' . $Ffc::Data::Prefix . 'users'
    )
)[0];

use_ok('Ffc::Data::General');

sub r {
    my @chars = ( 'a' .. 'z', 'A' .. 'Z', 0 .. 9 );
    return join '',
      map { $chars[ int rand scalar @chars ] } 0 .. 7 + int rand 5;
}
sub _get_rand_category { $categories[ int rand scalar @categories ] }
sub _get_rand_user     { $users[ int rand scalar @users ] }

{
    note('sub check_password_change( $newpw1, $newpw2, $oldpw )');
    my $user         = _get_rand_user();
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
            good => substr( r(), 0, 64 ),
            bad =>
              [ '', '    ', substr( r(), 0, 2 ) . '/' . substr( r(), 0, 3 ) ],
            emptyerror => 'Kein Kategoriekürzel angegeben',
            errormsg   => [
                'Kein Kategoriekürzel angegeben',
                'Kategoriekürzel ungültig'
            ],
        },
    );
    ok(
        Ffc::Data::General::check_category_short_rules( substr( r(), 0, 64 ) ),
        'category short fits the rules'
    );
}
{
    note('sub get_category_id( $cshort )');
    check_call(
        \&Ffc::Data::General::get_category_id,
        get_category_id => {
            name => 'category short name',
            good => _get_rand_category()->[2],
            bad =>
              [ '', '    ', substr( r(), 0, 2 ) . '/' . substr( r(), 0, 3 ) ],
            emptyerror => 'Kein Kategoriekürzel angegeben',
            errormsg   => [
                'Kein Kategoriekürzel angegeben',
                'Kategoriekürzel ungültig'
            ],
        },
    );
    like( Ffc::Data::General::get_category_id( _get_rand_category()->[2] ),
        qr(\d+), 'category id found' );
    {
        my $cat = _get_rand_category();
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
            good => _get_rand_category()->[2],
            bad =>
              [ '', '    ', substr( r(), 0, 2 ) . '/' . substr( r(), 0, 3 ) ],
            emptyerror => 'Kein Kategoriekürzel angegeben',
            errormsg   => [
                'Kein Kategoriekürzel angegeben',
                'Kategoriekürzel ungültig'
            ],
        },
    );
    ok( Ffc::Data::General::check_category( _get_rand_category()->[2] ),
        'category short fits the rules' );
}
{
    note('sub get_category_short( $catid )');
    check_call(
        \&Ffc::Data::General::get_category_short,
        get_category_short => {
            name       => 'category id',
            good       => _get_rand_category()->[0],
            bad        => [ '', '    ', 'aaaa', $maxcatid + 1 ],
            emptyerror => 'Keine Kategorieid angegeben',
            errormsg =>
              [ 'Keine Kategorieid angegeben', 'Kategorieid ungültig' ],
        },
    );
    ok( Ffc::Data::General::get_category_short( _get_rand_category()->[0] ),
        'category id fits the rules' );
    {
        my $cat = _get_rand_category();
        is( Ffc::Data::General::get_category_short( $cat->[0] ),
            $cat->[2], 'category short correct' );
    }
}
{
    note('sub get_useremail( $userid )');
    check_call(
        \&Ffc::Data::General::get_useremail,
        get_usermail => {
            name => 'userid id',
            good => Ffc::Data::Auth::get_userid( _get_rand_user()->{name} ),
            bad  => [ '', '    ', 'aaaa', $maxuserid + 1 ],
            emptyerror => 'Keine Benutzerid angegeben',
            errormsg   => [
                'Keine Benutzerid angegeben',
                'Benutzer ungültig',
                'Benutzer ungültig',
                'Benutzer unbekannt'
            ],
        },
    );
    like(
        Ffc::Data::General::get_useremail(
            Ffc::Data::Auth::get_userid( _get_rand_user()->{name} )
        ),
        qr/.+\@.+\.\w+/,
        'user email retrieved'
    );
    {
        my $user = _get_rand_user();
        is(
            Ffc::Data::General::get_useremail(
                Ffc::Data::Auth::get_userid( $user->{name} )
            ),
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

