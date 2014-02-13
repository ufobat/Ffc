#!/usr/bin/perl
use 5.010;
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Mojolicious;
use Mock::Database;
use Mock::Config;
use Mock::Testuser;
use Test::Callcheck;
use Test::General;
use Ffc::Data;

use Test::More tests => 218;

BEGIN { use_ok('Ffc::Data::Auth') }

note('doing some preparations');
my $config = Mock::Config->new->{config};
my $app    = Mojolicious->new();
$app->log->level('error');
Ffc::Data::set_config($app);
Mock::Database::prepare_testdatabase();

my $activeadmin       = Mock::Testuser->new_active_admin();
my $activeuser        = Mock::Testuser->new_active_user();
my $inactiveadmin     = Mock::Testuser->new_inactive_admin();
my $inactiveuser      = Mock::Testuser->new_inactive_user();
my $activefaultyadmin = Mock::Testuser->new_active_admin();
my $activefaultyuser  = Mock::Testuser->new_active_user();
$activefaultyadmin->alter_password;
$activefaultyuser->alter_password;
my @users = (
    $activeadmin, $activeuser, $inactiveadmin, $inactiveuser,
    $activefaultyadmin, $activefaultyuser
);

sub _run_failures {
    my $code        = shift;
    my $params      = shift;
    my $run_failure = sub {
        my ( $code, $user, $params ) = @_;
        my $name = $user->{pseudoname};
        my @params = map { $user->{$_} } @$params;
        my ( $ok, $return, $error ) = just_call( $code, @params );
        ok( !$ok,              "nothing is ok with $name" );
        ok( $error,            "errors with $name" );
        ok( !defined($return), "nothing came back with $name" );
        like(
            $error,
qr/Benutzer oder Passwort passen nicht oder der Benutzer ist inaktiv/,
            "error message ok with $name"
        );
    };
    $run_failure->(
        \&Ffc::Data::Auth::get_userdata_for_login,
        $inactiveuser, $params
    );
    $run_failure->(
        \&Ffc::Data::Auth::get_userdata_for_login,
        $inactiveadmin, $params
    );
    $run_failure->(
        \&Ffc::Data::Auth::get_userdata_for_login,
        $activefaultyuser, $params
    );
    $run_failure->(
        \&Ffc::Data::Auth::get_userdata_for_login,
        $activefaultyadmin, $params
    );
}

{
    note('TESTING check_username_rules( $username )');
    check_call( \&Ffc::Data::Auth::check_username_rules,
        check_username_rules => Mock::Testuser::get_username_check_hash(), );
}

{
    note('TESTING check_password_rules( $password )');
    check_call( \&Ffc::Data::Auth::check_password_rules,
        check_password_rules => Mock::Testuser::get_password_check_hash(), );
}

{
    note('TESTING check_userid_rules( $userid )');
    check_call( \&Ffc::Data::Auth::check_userid_rules,
        check_userid_rules => Mock::Testuser::get_userid_check_hash(), );
}
sub set_settings {
    my $u = shift;
    Ffc::Data::dbh()->do('UPDATE '.$Ffc::Data::Prefix
        .'users SET show_images=?, theme=?, bgcolor=?, fontsize=?'
        .' WHERE LOWER(name)=LOWER(?)',
        undef,
        (
            $u->{show_images} = 3 + int rand 10,
            $u->{theme}       = Test::General::test_r(),
            $u->{bgcolor}     = Test::General::test_r(),
            $u->{fontsize}    = 3 + int rand 10,
        ),
        $u->{name});
    return 1;
}
        
{

    note('TESTING get_userdata_for_login( $user, $pass )');
    check_call(
        \&Ffc::Data::Auth::get_userdata_for_login,
        get_userdata_for_login =>
          Mock::Testuser::get_username_check_hash( $activeuser->{name} ),
        Mock::Testuser::get_password_check_hash( $activeuser->{password} ),
    );
    {
        my ( $ok, $return, $error ) =
          just_call( \&Ffc::Data::Auth::get_userdata_for_login,
            lc($activeuser->{name}), $activeuser->{password} );
        ok( $ok,     'everything is ok with good active user' );
        ok( !$error, 'no error with good active user' );

        # u.id, u.name
        like( $return->[0], qr/\d+/, 'userid is valid' );
        is( $return->[1], $activeuser->{name}, 'user name is ok' );
        $activeuser->{id} = $return->[0];

        set_settings( $activeuser );

        ( $ok, $return, $error ) =
          just_call( \&Ffc::Data::Auth::get_usersettings,
            lc($activeuser->{name}) );
        ok( $ok,     'everything is ok with good active user' );
        ok( !$error, 'no error with good active user' );

        # u.admin, u.show_images, u.theme, u.bgcolor, u.fontsize
        ok(!$return->[0], 'normal user is no admin');
        is($return->[1], $activeuser->{show_images}, 'normal user wants to see images');
        is($return->[2], $activeuser->{theme},       'normal user has the correct theme set');
        is($return->[3], $activeuser->{bgcolor},     'normal user has the correct background color');
        is($return->[4], $activeuser->{fontsize},    'normal user hsa the correct font size');
    }
    {
        my ( $ok, $return, $error ) =
          just_call( \&Ffc::Data::Auth::get_userdata_for_login,
            lc($activeadmin->{name}), $activeadmin->{password} );
        ok( $ok,     'everything is ok with good active admin' );
        ok( !$error, 'no error with good active admin' );

        # u.id, u.name
        like( $return->[0], qr/\d+/, 'adminid is valid' );
        is( $return->[1], $activeadmin->{name}, 'admin name is ok' );
        $activeadmin->{id} = $return->[0];

        set_settings( $activeadmin );

        ( $ok, $return, $error ) =
          just_call( \&Ffc::Data::Auth::get_usersettings,
            lc($activeadmin->{name}) );
        ok( $ok,     'everything is ok with good active user' );
        ok( !$error, 'no error with good active user' );

        # u.admin, u.show_images, u.theme, u.bgcolor, u.fontsize
        ok($return->[0], 'admin user is admin');
        is($return->[1], $activeadmin->{show_images}, 'admin user wants to see images');
        is($return->[2], $activeadmin->{theme},       'admin user has the correct theme set');
        is($return->[3], $activeadmin->{bgcolor},     'admin user has the correct background color');
        is($return->[4], $activeadmin->{fontsize},    'admin user hsa the correct font size');
    }
    _run_failures( \&Ffc::Data::Auth::get_userdata_for_login,
        [qw(name password)] );
}

{
    note('TESTING is_user_admin( $userid )');
    for my $user ( $inactiveadmin, $inactiveuser, $activefaultyuser,
        $activefaultyadmin )
    {
        $user->{id} = Ffc::Data::dbh()->selectrow_arrayref(
            'SELECT u.id FROM ' . $Ffc::Data::Prefix . 'users u WHERE u.name=?',
            undef, $user->{name}
        )->[0];
    }
    my $c = sub {
        my $user = shift;
        my $code = \&Ffc::Data::Auth::is_user_admin;
        my $ret;
        eval { $ret = $code->( $user->{id} ) };
        return $ret;
    };
    for my $user (@users) {
        my $ret = $c->($user);
        if ( $user->{active} ) {
            is( $ret, $user->{admin},
qq(checked for true administrational being of "$user->{pseudoname}")
            );
        }
        else {
            ok( !$ret,
qq(checked for false administrational being of "$user->{pseudoname}")
            );
        }
    }
}

{
    note('TESTING check_password( $userid, $pass )');
    my $code = \&Ffc::Data::Auth::check_password;
    check_call(
        $code,
        check_password =>
          Mock::Testuser::get_userid_check_hash( $activeuser->{id} ),
        Mock::Testuser::get_password_check_hash( $activeuser->{password} ),
    );
    for my $user (@users) {
        my ( $ok, $return, $error ) =
          just_call( $code, $user->{id}, $user->{password} );
        $return = $return->[0];
        ok( !$error, qq'no error reported "$user->{pseudoname}"' );
        ok( $ok,     qq'code ran ok for "$user->{pseudoname}"' );
        if ( $user->{faulty} or not $user->{active} ) {
            ok( !$return, qq'false return is ok for "$user->{pseudoname}"' );
        }
        else {
            ok( $return, qq'true return is good for "$user->{pseudoname}"' );
        }
    }
}

{
    note('TESTING check_username( $username )');
    my $code = \&Ffc::Data::Auth::check_username;
    check_call( $code,
        check_username =>
          Mock::Testuser::get_username_check_hash( $activeuser->{name} ), );
    for my $user (@users) {
        my ( $ok, $return, $error ) = just_call( $code, $user->{name} );
        $return = $return->[0];
        ok( $return, qq'true return is good for "$user->{pseudoname}"' );
    }
    {
        my $newname = Mock::Testuser::get_noneexisting_username();
        my ( $ok, $return, $error ) = just_call( $code, $newname );
        $return = $return->[0];
        ok( $error, qq'error is good for none existing user' );
    }
}

{
    note('TESTING check_user_exists( $username )');
    my $code = \&Ffc::Data::Auth::check_user_exists;
    for my $user (@users) {
        my ( $ok, $return, $error ) = just_call( $code, $user->{name} );
        $return = $return->[0];
        ok( $return, qq'true return is good for "$user->{pseudoname}"' );
        ok(!$error, qq'error is empty for "$user->{pseudoname}"' );
    }
    {
        my $newname = Mock::Testuser::get_noneexisting_username();
        my ( $ok, $return, $error ) = just_call( $code, $newname );
        $return = $return->[0];
        ok(!$return, qq'false for non existing user' );
        ok(!$error, qq'error is empty for non existing user' );
    }
}

{
    note('TESTING check_userid( $userid )');
    my $code = \&Ffc::Data::Auth::check_userid;
    check_call( $code,
        check_userid =>
          Mock::Testuser::get_userid_check_hash( $activeuser->{id} ), );
    for my $user (@users) {
        my ( $ok, $return, $error ) = just_call( $code, $user->{id} );
        $return = $return->[0];
        ok( $return, qq'true return is good for "$user->{pseudoname}"' );
    }
    {
        my $newid = (
            Ffc::Data::dbh->selectrow_array(
                'SELECT MAX(u.id) + 1 FROM ' . $Ffc::Data::Prefix . 'users u'
            )
        )[0];
        my ( $ok, $return, $error ) = just_call( $code, $newid );
        $return = $return->[0];
        ok( $error, qq'error is good for none existing user' );
    }
}

{
    note('TESTING get_userid( $username )');
    my $code = \&Ffc::Data::Auth::get_userid;
    check_call( $code,
        get_userid =>
          Mock::Testuser::get_username_check_hash( $activeuser->{name} ), 
        );
    for ( 0 .. 2 ) {
        for my $user (@users) {
            my ( $ok, $return, $error ) = just_call( $code, $user->{name} );
            $return = $return->[0];
            is( $return, $user->{id},
                qq'user id returned ok for "$user->{pseudoname}"' );
        }
    }
    {
        my $newname = Mock::Testuser::get_noneexisting_username();
        my $teststr = Test::General::test_r();
        my ( $ok, $return, $error ) = just_call( $code, $newname, $teststr );
        ok( !defined($return),
            qq'undefined return is good for none existing user' );
        ok( $error, qq'error returned is good for non existing user' );
        like( $error, qr/$teststr/, 'error message contains parameter element' );
        ok( !$ok,   qq'false return is good for non existing user' );
    }
}

{
    note('TESTING get_username( $userid )');
    my $code = \&Ffc::Data::Auth::get_username;
    check_call( $code,
        get_username =>
          Mock::Testuser::get_userid_check_hash( $activeuser->{id} ), );
    for ( 0 .. 2 ) {
        for my $user (@users) {
            my ( $ok, $return, $error ) = just_call( $code, $user->{id} );
            $return = $return->[0];
            is( $return, $user->{name},
                qq'user name returned ok for "$user->{pseudoname}"' );
        }
    }
    {
        my $newid = Mock::Testuser::get_noneexisting_userid();
        my $teststr = Test::General::test_r();
        my ( $ok, $return, $error ) = just_call( $code, $newid, $teststr );
        ok( !defined($return),
            qq'undefined return is good for none existing user' );
        ok( $error, qq'error returned is good for non existing user' );
        like( $error, qr/$teststr/, 'error message contains parameter element' );
        ok( !$ok,   qq'false return is good for non existing user' );
    }
}

{
    note('TESTING set_password( $userid, $pass )');
    my $code = \&Ffc::Data::Auth::set_password;
    check_call(
        $code,
        check_password =>
          Mock::Testuser::get_userid_check_hash( $activeuser->{id} ),
        Mock::Testuser::get_password_check_hash( $activeuser->{password} ),
    );
    my $check = \&Ffc::Data::Auth::check_password;
    {
        {
            my $return =
              $check->( $activefaultyuser->{id},
                $activefaultyuser->{password} );
            ok( !$return, 'user with wrong password generates false results' );
        }
        {
            eval {
                $code->(
                    $activefaultyuser->{id},
                    $activefaultyuser->{password}
                );
            };
            ok( !$@, 'no errors reported' )
        }
        {
            my $return =
              $check->( $activefaultyuser->{id},
                $activefaultyuser->{password} );
            ok( $return, 'user with reset password generates true results' );
        }
        {
            my $return = $check->(
                $activefaultyadmin->{id},
                $activefaultyadmin->{password}
            );
            ok( !$return,
                'but user with wrong password generates also false results' );
        }
    }
}

