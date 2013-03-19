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
use Ffc::Data;

use Test::More tests => 107;

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
            $activeuser->{name}, $activeuser->{password} );
        ok( $ok,     'everything is ok with good active user' );
        ok( !$error, 'no error with good active user' );

        # u.id, u.lastseenmsgs, u.admin, u.show_images, u.theme
        like( $return->[0], qr/\d+/, 'userid is valid' );
        ok( $return->[1], 'user was lastseen in msgs' );
        is( $return->[2], 0, 'user is no admin' );
        is( $return->[3], 1, 'user wants to see images' );
        ok( !$return->[4], 'user has not set a theme yet' );
        $activeuser->{id} = $return->[0];
    }
    {
        my ( $ok, $return, $error ) =
          just_call( \&Ffc::Data::Auth::get_userdata_for_login,
            $activeadmin->{name}, $activeadmin->{password} );
        ok( $ok,     'everything is ok with good active admin' );
        ok( !$error, 'no error with good active admin' );

        # u.id, u.lastseenmsgs, u.admin, u.show_images, u.theme
        like( $return->[0], qr/\d+/, 'adminid is valid' );
        ok( $return->[1], 'admin was lastseen in msgs' );
        is( $return->[2], 1, 'admin is no admin' );
        is( $return->[3], 1, 'admin wants to see images' );
        ok( !$return->[4], 'admin has not set a theme yet' );
        $activeadmin->{id} = $return->[0];
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
    for my $user ( $activeuser, $activeadmin, $inactiveadmin, $inactiveuser,
        $activefaultyuser, $activefaultyadmin )
    {
        my $ret = $c->($user);
        if ( $user->{faulty} or not $user->{active} ) {
            ok( !$ret,
                qq(checked for administrational being of "$user->{pseudoname}")
            );
        }
        else {
            is( $ret, $user->{admin},
                qq(checked for administrational being of "$user->{pseudoname}")
            );
        }
    }
}

{
    note('TESTING check_password( $userid, $pass )');
    my $code = \&Ffc::Data::Auth::check_password;
    check_call(
        $code, check_password =>
        Mock::Testuser::get_userid_check_hash( $activeuser->{id} ),
        Mock::Testuser::get_password_check_hash( $activeuser->{password} ),
    );
}

{
    note('TESTING check_user( $userid )');
    my $code = \&Ffc::Data::Auth::check_user;
    check_call(
        $code, check_user =>
        Mock::Testuser::get_userid_check_hash( $activeuser->{id} ),
    );
}

{
    note('TESTING get_userid( $username )');
    my $code = \&Ffc::Data::Auth::get_userid;
    check_call(
        $code, get_userid =>
          Mock::Testuser::get_username_check_hash( $activeuser->{name} ),
    );
}

{
    note('TESTING get_username( $userid )');
    my $code = \&Ffc::Data::Auth::get_username;
    check_call(
        $code, get_username =>
        Mock::Testuser::get_userid_check_hash( $activeuser->{id} ),
    );
}

{
    note('TESTING set_password( $userid, $pass )');
    my $code = \&Ffc::Data::Auth::set_password;
#    check_call(
#        $code, check_password =>
#        Mock::Testuser::get_userid_check_hash( $activefaultyuser->{id} ),
#        Mock::Testuser::get_password_check_hash( $activefaultyuser->{password} ),
#    );
}

