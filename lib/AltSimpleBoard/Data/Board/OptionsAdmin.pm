package AltSimpleBoard::Data::Board::OptionsAdmin;

use 5.010;
use strict;
use warnings;
use utf8;

use AltSimpleBoard::Data;
use AltSimpleBoard::Data::Auth;
use AltSimpleBoard::Data::Board::General;

sub check_user { &AltSimpleBoard::Data::Board::General::check_user }
sub _check_password_change { &AltSimpleBoard::Data::Board::General::check_password_change }
sub get_userid { &AltSimpleBoard::Data::Board::General::get_userid }

sub admin_update_password {
    my $adminuid = shift;
    die 'Passworte von anderen Benutzern dürfen nur Administratoren ändern'
        unless AltSimpleBoard::Data::Auth::is_user_admin($adminuid);
    my $userid = shift;
    check_user( $userid );
    my $pw1 = shift;
    my $pw2 = shift;
    _check_password_change( $pw1, $pw2 );
    AltSimpleBoard::Data::Auth::set_password($userid, $pw1);
}

sub admin_update_active {
    my $adminuid = shift;
    die 'Benutzern aktivieren oder deaktiveren dürfen nur Administratoren'
        unless AltSimpleBoard::Data::Auth::is_user_admin($adminuid);
    my $userid = shift;
    check_user( $userid );
    my $active = shift() ? 1 : 0;
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'users u SET u.active=? WHERE u.id=?';
    AltSimpleBoard::Data::dbh()->do($sql, undef, $active, $userid);
}

sub admin_update_admin {
    my $adminuid = shift;
    die 'Benutzern zu Administratoren befördern oder ihnen den Adminstratorenstatus wegnehmen dürfen nur Administratoren'
        unless AltSimpleBoard::Data::Auth::is_user_admin($adminuid);
    my $userid = shift;
    check_user( $userid );
    my $admin = shift() ? 1 : 0;
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'users u SET u.admin=? WHERE u.id=?';
    AltSimpleBoard::Data::dbh()->do($sql, undef, $admin, $userid);
}

sub admin_create_user {
    my $adminuid = shift;
    die 'Neue Benutzer anlegen dürfen nur Administratoren'
        unless AltSimpleBoard::Data::Auth::is_user_admin($adminuid);
    my $username = shift;
    die qq(Benutzer "$username" existiert bereits und darf nicht neu angelegt werden)
        if get_userid($username);
    my $pw1 = shift;
    my $pw2 = shift;
    _check_password_change( $pw1, $pw2 );
    my $active = shift() ? 1 : 0;
    my $admin  = shift() ? 1 : 0;
    my $sql = 'INSERT INTO '.$AltSimpleBoard::Data::Prefix.'users (name, password, active, admin) VALUES (?,?,?,?)';
    AltSimpleBoard::Data::dbh()->do($sql, undef, $username, crypt($pw1, AltSimpleBoard::Data::cryptsalt()), $active, $admin);
}


1;

