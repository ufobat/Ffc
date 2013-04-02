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

use Test::More tests => 139;

Test::General::test_prepare();

use_ok('Ffc::Data::Board::OptionsAdmin');

{
    note('sub admin_update_password( $admin, $user, $password1, $password2 )');
    my $admin        = Mock::Testuser->new_active_admin();
    my $user         = Mock::Testuser->new_active_user();
    my $old_password = $user->{password};
    $user->alter_password();
    my $new_password = $user->{password};
    check_call(
        \&Ffc::Data::Board::OptionsAdmin::admin_update_password,
        admin_update_password => {
            name => 'admin name',
            good => $admin->{name},
            bad  => [
                '',                                          '   ',
                Mock::Testuser::get_noneexisting_username(), $user->{name}
            ],
            errormsg => [
                'Kein Benutzername angegeben',
                'Benutzername ungültig',
                'Benutzer unbekannt',
'Passworte von anderen Benutzern dürfen nur Administratoren ändern'
            ],
            emptyerror => 'Kein Benutzername angegeben',
        },
        {
            name => 'user name',
            good => $user->{name},
            bad  => [ '', '   ', Mock::Testuser::get_noneexisting_username() ],
            errormsg => [
                'Kein Benutzername angegeben',
                'Benutzername ungültig',
                'Benutzer unbekannt'
            ],
            emptyerror => 'Kein Benutzername angegeben',
        },
        {
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
    );
    {
        my $user_ok      = Mock::Testuser->new_active_user();
        my $userid       = Ffc::Data::Auth::get_userid( $user_ok->{name} );
        my $old_password = $user_ok->{password};
        $user_ok->alter_password();
        my $new_password = $user_ok->{password};
        ok( Ffc::Data::Auth::check_password( $userid, $old_password ),
            'old password works' );
        ok( !Ffc::Data::Auth::check_password( $userid, $new_password ),
            'new password does not work yet' );
        ok(
            Ffc::Data::Board::OptionsAdmin::admin_update_password(
                $admin->{name}, $user_ok->{name},
                $new_password,  $new_password
            ),
            'call returned true'
        );
        ok( !Ffc::Data::Auth::check_password( $userid, $old_password ),
            'old password does not work anymore' );
        ok( Ffc::Data::Auth::check_password( $userid, $new_password ),
            'new password works now' );
    }
}
{
    note('sub admin_update_active( $admin, $user, $is_active )');
    my $admin = Mock::Testuser->new_active_admin();
    my $user  = Mock::Testuser->new_active_user();
    check_call(
        \&Ffc::Data::Board::OptionsAdmin::admin_update_active,
        admin_update_active => {
            name => 'admin name',
            good => $admin->{name},
            bad  => [
                '',                                          '   ',
                Mock::Testuser::get_noneexisting_username(), $user->{name}
            ],
            errormsg => [
                'Kein Benutzername angegeben',
                'Benutzername ungültig',
                'Benutzer unbekannt',
'Benutzer aktivieren oder deaktiveren dürfen nur Administratoren'
            ],
            emptyerror => 'Kein Benutzername angegeben',
        },
        {
            name => 'user name',
            good => $user->{name},
            bad  => [ '', '   ', Mock::Testuser::get_noneexisting_username() ],
            errormsg => [
                'Kein Benutzername angegeben',
                'Benutzername ungültig',
                'Benutzer unbekannt'
            ],
            emptyerror => 'Kein Benutzername angegeben',
        },
        {
            name => 'boolean (0/1) is_active value',
            good => int( rand 2 ),
            bad  => [ '', 4, 'asd', '   ' ],
            errormsg =>
              ['Benutzer-Aktivstatus muss mit "0" oder "1" angegeben werden'],
            emptyerror => 'Benutzer-Aktivstatus muss mit angegeben werden',
        },
    );
    {
        my $user_ok   = Mock::Testuser->new_active_user();
        my $get_value = sub {
            Ffc::Data::dbh()->selectrow_arrayref(
                'SELECT active FROM '
                  . $Ffc::Data::Prefix
                  . 'users WHERE name=?',
                undef, $user_ok->{name}
            )->[0];
        };
        my $order = $get_value->() ? [ 0, 1, 0, 1 ] : [ 1, 0, 1, 0 ];
        for my $value (@$order) {
            ok(
                Ffc::Data::Board::OptionsAdmin::admin_update_active(
                    $admin->{name}, $user_ok->{name}, $value
                ),
                qq(call with "$value" ok)
            );
            is( $value, $get_value->(), 'database update ok' );
        }
    }
}
{
    note('sub admin_update_admin( $admin, $user, $is_admin)');
    my $admin = Mock::Testuser->new_active_admin();
    my $user  = Mock::Testuser->new_active_user();
    check_call(
        \&Ffc::Data::Board::OptionsAdmin::admin_update_admin,
        admin_update_admin => {
            name => 'admin name',
            good => $admin->{name},
            bad  => [
                '',                                          '   ',
                Mock::Testuser::get_noneexisting_username(), $user->{name}
            ],
            errormsg => [
                'Kein Benutzername angegeben',
                'Benutzername ungültig',
                'Benutzer unbekannt',
'Benutzer zu Administratoren befördern oder ihnen den Adminstratorenstatus wegnehmen dürfen nur Administratoren'
            ],
            emptyerror => 'Kein Benutzername angegeben',
        },
        {
            name => 'user name',
            good => $user->{name},
            bad  => [ '', '   ', Mock::Testuser::get_noneexisting_username() ],
            errormsg => [
                'Kein Benutzername angegeben',
                'Benutzername ungültig',
                'Benutzer unbekannt'
            ],
            emptyerror => 'Kein Benutzername angegeben',
        },
        {
            name => 'boolean (0/1) is_admin value',
            good => int( rand 2 ),
            bad  => [ '', 4, 'asd', '   ' ],
            errormsg =>
              ['Administratorenstatus muss mit "0" oder "1" angegeben werden'],
            emptyerror => 'Administratorenstatus muss mit angegeben werden',
        },
    );
    {
        my $user_ok   = Mock::Testuser->new_active_user();
        my $get_value = sub {
            Ffc::Data::Auth::is_user_admin(
                Ffc::Data::Auth::get_userid( $user_ok->{name} ) );
        };
        my $order = $get_value->() ? [ 0, 1, 0, 1 ] : [ 1, 0, 1, 0 ];
        for my $value (@$order) {
            ok(
                Ffc::Data::Board::OptionsAdmin::admin_update_admin(
                    $admin->{name}, $user_ok->{name}, $value
                ),
                qq(call with "$value" ok)
            );
            is( $value, $get_value->(), 'database update ok' );
        }
    }
}
{
    note(
'sub admin_create_user( $admin, $user, $password1, $password2, $is_active, $is_admin )'
    );
    my $admin        = Mock::Testuser->new_active_admin();
    my $user_exists  = Mock::Testuser->new_active_user();
    my $user_name    = Mock::Testuser::get_noneexisting_username();
    my $new_password = Test::General::test_r();
    my $is_active    = int rand 2;
    my $is_admin     = int rand 2;
    check_call(
        \&Ffc::Data::Board::OptionsAdmin::admin_create_user,
        admin_create_user => {
            name => 'admin name',
            good => $admin->{name},
            bad  => [
                '', '   ', Mock::Testuser::get_noneexisting_username(),
                $user_exists->{name}
            ],
            errormsg => [
                'Kein Benutzername angegeben',
                'Benutzername ungültig',
                'Benutzer unbekannt',
                'Neue Benutzer anlegen dürfen nur Administratoren'
            ],
            emptyerror => 'Kein Benutzername angegeben',
        },
        {
            name     => 'user name',
            good     => $user_name,
            bad      => [ $user_exists->{name}, '', '   ' ],
            errormsg => [
qq(Benutzer "$user_exists->{name}" existiert bereits und darf nicht neu angelegt werden),
                'Kein Benutzername angegeben',
                'Benutzername ungültig',
            ],
            emptyerror => 'Kein Benutzername angegeben',
        },
        {
            name => 'new password',
            good => $new_password,
            bad  => [ '', '        ', substr( $new_password, 0, 5 ) ],
            errormsg   => [ 'Kein Passwort', 'Passwort ungültig' ],
            emptyerror => 'Kein Passwort',
        },
        {
            name => 'new password repeat',
            good => $new_password,
            bad  => [ '', '        ', substr( $new_password, 0, 5 ) ],
            errormsg   => [ 'Kein Passwort', 'Passwort ungültig', ],
            emptyerror => 'Kein Passwort',
        },
        {
            name => 'boolean (0/1) is_active value',
            good => $is_active,
            bad  => [ '', 4, 'asd', '   ' ],
            errormsg =>
              ['Benutzer-Aktivstatus muss mit "0" oder "1" angegeben werden'],
            emptyerror => 'Benutzer-Aktivstatus muss mit angegeben werden',
        },
        {
            name => 'boolean (0/1) is_admin value',
            good => $is_admin,
            bad  => [ '', 4, 'asd', '   ' ],
            errormsg =>
              ['Administratorenstatus muss mit "0" oder "1" angegeben werden'],
            emptyerror => 'Administratorenstatus muss mit angegeben werden',
        },
    );

    for my $w ( [ 0, 0 ], [ 0, 1 ], [ 1, 0 ], [ 1, 1 ] ) {
        my $admin        = Mock::Testuser->new_active_admin();
        my $user_name    = Mock::Testuser::get_noneexisting_username();
        my $new_password = Test::General::test_r();
        my $is_active    = $w->[0], my $is_admin = $w->[1];
        note(
qq(creating user "$user_name" from admin "$admin->{name}" with password "$new_password", who is ")
              . ( $is_active ? '' : 'in' )
              . q(active" and )
              . ( $is_admin ? '' : 'no ' )
              . 'administrator' );
        {
            eval {
                Ffc::Data::Board::OptionsAdmin::admin_create_user(
                    $admin->{name}, $user_name, $new_password,
                    $new_password,  $is_active, $is_admin
                );
            };
            ok( !$@, 'user generation successful: ' . $@ );
        }
        my $userid;
        {
            eval { $userid = Ffc::Data::Auth::get_userid($user_name) };
            ok( !$@, 'user generated ok: ' . $@ );
        }
        ok( defined($userid), 'user exists in database' );
        {
            my @row;
            eval {
                @row = Ffc::Data::dbh()->selectrow_array(
                    'SELECT active FROM '
                      . $Ffc::Data::Prefix
                      . 'users WHERE id=?',
                    undef, $userid
                );
            };
            ok( @row, 'got information about active status' );
            is( $row[0], $is_active,
                'information about active status correct' );
        }
        {
            my $is_admin_now;
            eval { $is_admin_now = Ffc::Data::Auth::is_user_admin($userid) };
            ok( !$@, 'user checked for is_admin ok: ' . $@ );
            ok( defined($is_admin_now),
                'got information about admin status of new user' );
            is( ( $is_active ? $is_admin : 0 ),
                $is_admin_now, 'user admin status ok' );
        }
        {
            my @row;
            eval {
                @row = Ffc::Data::dbh()->selectrow_array(
                    'SELECT admin FROM '
                      . $Ffc::Data::Prefix
                      . 'users WHERE id=?',
                    undef, $userid
                );
            };
            ok( @row, 'got database information about admin status' );
            is( $row[0], $is_admin, 'information about admin status correct' );
        }
    }
}

