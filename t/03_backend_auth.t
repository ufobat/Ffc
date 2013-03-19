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

use Test::More tests => 52;

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
        ok( $ok,    'everything is ok with good active user' );
        ok( !$error, 'no error with good active user' );

        # u.id, u.lastseenmsgs, u.admin, u.show_images, u.theme
        like( $return->[0], qr/\d+/, 'userid is valid' );
        ok( $return->[1], 'user was lastseen in msgs' );
        is( $return->[2], 0, 'user is no admin' );
        is( $return->[3], 1, 'user wants to see images' );
        ok( !$return->[4], 'user has not set a theme yet' );
    }
    {
        my ( $ok, $return, $error ) =
          just_call( \&Ffc::Data::Auth::get_userdata_for_login,
            $activeadmin->{name}, $activeadmin->{password} );
        ok( $ok,    'everything is ok with good active admin' );
        ok( !$error, 'no error with good active admin' );

        # u.id, u.lastseenmsgs, u.admin, u.show_images, u.theme
        like( $return->[0], qr/\d+/, 'adminid is valid' );
        ok( $return->[1], 'admin was lastseen in msgs' );
        is( $return->[2], 1, 'admin is no admin' );
        is( $return->[3], 1, 'admin wants to see images' );
        ok( !$return->[4], 'admin has not set a theme yet' );
    }
}

{
    note('TESTING is_user_admin( $userid )');
}

{
    note('TESTING check_password( $userid, $pass )');
}

{
    note('TESTING set_password( $userid, $pass )');
}

{
    note('TESTING check_user( $userid )');
}

{
    note('TESTING get_userid( $username )');
}

{
    note('TESTING get_username( $userid )');
}
