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

use Test::More tests => 20;

Test::General::test_prepare();

use_ok('Ffc::Data::Board::OptionsAdmin');

{
    note('sub admin_update_password( $admin, $user, $password1, $password2 )');
    my $admin = Mock::Testuser->new_active_admin();
    my $user = Mock::Testuser->new_active_user();
    my $old_password = $user->{password};
    $user->alter_password();
    my $new_password = $user->{password};
    check_call(
        \&Ffc::Data::Board::OptionsAdmin::admin_update_password,
        admin_update_password =>
        {
            name => 'admin name',
            good => $admin->{name},
            bad => ['', '   ', Mock::Testuser::get_noneexisting_username(), $user->{name}],
            errormsg => ['Kein Benutzername angegeben', 'Benutzername ungültig', 'Benutzer unbekannt', 'Passworte von anderen Benutzern dürfen nur Administratoren ändern'],
            emptyerror => 'Kein Benutzername angegeben',
        },
        {
            name => 'user name',
            good => $user->{name},
            bad => ['', '   ', Mock::Testuser::get_noneexisting_username()],
            errormsg => ['Kein Benutzername angegeben', 'Benutzername ungültig', 'Benutzer unbekannt'],
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
}
{
    note('sub admin_update_active( $admin, $user, $is_active )');
    my $admin = Mock::Testuser->new_active_admin();
    my $user = Mock::Testuser->new_active_user();
    check_call(
        \&Ffc::Data::Board::OptionsAdmin::admin_update_active,
        admin_update_active =>
        {
            name => 'admin name',
            good => $admin->{name},
            bad => ['', '   ', Mock::Testuser::get_noneexisting_username(), $user->{name}],
            errormsg => ['Kein Benutzername angegeben', 'Benutzername ungültig', 'Benutzer unbekannt', 'Benutzer aktivieren oder deaktiveren dürfen nur Administratoren'],
            emptyerror => 'Kein Benutzername angegeben',
        },
        {
            name => 'user name',
            good => $user->{name},
            bad => ['', '   ', Mock::Testuser::get_noneexisting_username()],
            errormsg => ['Kein Benutzername angegeben', 'Benutzername ungültig', 'Benutzer unbekannt'],
            emptyerror => 'Kein Benutzername angegeben',
        },
    );
}
{
    note('sub admin_update_admin( $admin, $user, $is_admin)');
    my $admin = Mock::Testuser->new_active_admin();
    my $user = Mock::Testuser->new_active_user();
    check_call(
        \&Ffc::Data::Board::OptionsAdmin::admin_update_admin,
        admin_update_admin =>
        {
            name => 'admin name',
            good => $admin->{name},
            bad => ['', '   ', Mock::Testuser::get_noneexisting_username(), $user->{name}],
            errormsg => ['Kein Benutzername angegeben', 'Benutzername ungültig', 'Benutzer unbekannt', 'Benutzer zu Administratoren befördern oder ihnen den Adminstratorenstatus wegnehmen dürfen nur Administratoren'],
            emptyerror => 'Kein Benutzername angegeben',
        },
        {
            name => 'user name',
            good => $user->{name},
            bad => ['', '   ', Mock::Testuser::get_noneexisting_username()],
            errormsg => ['Kein Benutzername angegeben', 'Benutzername ungültig', 'Benutzer unbekannt'],
            emptyerror => 'Kein Benutzername angegeben',
        },
    );
}
{
    note('sub admin_create_user( $admin, $user, $password1, $password2, $is_active, $is_admin )');
    my $admin = Mock::Testuser->new_active_admin();
    my $user = Mock::Testuser->new_active_user();
    check_call(
        \&Ffc::Data::Board::OptionsAdmin::admin_create_user,
        admin_create_user =>
        {
            name => 'admin name',
            good => $admin->{name},
            bad => ['', '   ', Mock::Testuser::get_noneexisting_username(), $user->{name}],
            errormsg => ['Kein Benutzername angegeben', 'Benutzername ungültig', 'Benutzer unbekannt', 'Neue Benutzer anlegen dürfen nur Administratoren'],
            emptyerror => 'Kein Benutzername angegeben',
        },
        {
            name => 'user name',
            good => $user->{name},
            bad => ['', '   ', Mock::Testuser::get_noneexisting_username()],
            errormsg => ['Kein Benutzername angegeben', 'Benutzername ungültig', 'Benutzer unbekannt'],
            emptyerror => 'Kein Benutzername angegeben',
        },
    );
}

