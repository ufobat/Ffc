package Ffc::Data::Board::OptionsAdmin;

use 5.010;
use strict;
use warnings;
use utf8;

use Ffc::Data;
use Ffc::Data::Auth;
use Ffc::Data::General;

sub _check_username { &Ffc::Data::Auth::check_username }
sub _check_password_change { &Ffc::Data::General::check_password_change }
sub _get_userid { &Ffc::Data::Auth::get_userid }

sub admin_update_password {
    my $adminuid = _get_userid(shift, 'Administrator für Passwortänderung');
    die 'Passworte von anderen Benutzern dürfen nur Administratoren ändern'
        unless Ffc::Data::Auth::is_user_admin($adminuid);
    my $userid = _get_userid(shift, 'zu bearbeitender Benutzer für Passwortänderung');
    my $pw1 = shift;
    my $pw2 = shift;
    _check_password_change( $pw1, $pw2 );
    Ffc::Data::Auth::set_password($userid, $pw1);
}

sub admin_update_active {
    my $adminuid = _get_userid(shift, 'Administrator für Aktivierung/Deaktivierung');
    die 'Benutzer aktivieren oder deaktiveren dürfen nur Administratoren'
        unless Ffc::Data::Auth::is_user_admin($adminuid);
    my $userid = _get_userid(shift, 'zu bearbeitender Benutzer für Aktivierung/Deaktivierung');
    my $active = shift;
    die 'Benutzer-Aktivstatus muss mit angegeben werden' unless defined $active;
    die 'Benutzer-Aktivstatus muss mit "0" oder "1" angegeben werden' unless $active =~ m/\A0|1\z/xms;
    my $sql = 'UPDATE '.$Ffc::Data::Prefix.'users SET active=? WHERE id=?';
    Ffc::Data::dbh()->do($sql, undef, $active, $userid);
}

sub admin_update_admin {
    my $adminuid = _get_userid(shift, 'Administrator für Administratoreneinstellung');
    die 'Benutzer zu Administratoren befördern oder ihnen den Adminstratorenstatus wegnehmen dürfen nur Administratoren'
        unless Ffc::Data::Auth::is_user_admin($adminuid);
    my $userid = _get_userid(shift, 'zu bearbeitender Benutzer für Administratoreneinstellung');
    my $admin = shift;
    die 'Administratorenstatus muss mit angegeben werden' unless defined $admin;
    die 'Administratorenstatus muss mit "0" oder "1" angegeben werden' unless $admin =~ m/\A0|1\z/xms;
    my $sql = 'UPDATE '.$Ffc::Data::Prefix.'users SET admin=? WHERE id=?';
    Ffc::Data::dbh()->do($sql, undef, $admin, $userid);
}

sub admin_create_user {
    my $adminuid = _get_userid(shift, 'Administrator zum Anlegen eines neuen Benutzers');
    die 'Neue Benutzer anlegen dürfen nur Administratoren'
        unless Ffc::Data::Auth::is_user_admin($adminuid);
    my $username = shift;
    _check_username($username) or die qq(Benutzer "$username" existiert bereits und darf nicht neu angelegt werden);
    my $pw1 = shift;
    my $pw2 = shift;
    _check_password_change( $pw1, $pw2 );
    my $active = shift;
    die 'Benutzer-Aktivstatus muss mit angegeben werden' unless defined $active;
    die 'Benutzer-Aktivstatus muss mit "0" oder "1" angegeben werden' unless $active =~ m/\A0|1\z/xms;
    my $admin = shift;
    die 'Administratorenstatus mit angegeben werden' unless defined $admin;
    die 'Administratorenstatus muss mit "0" oder "1" angegeben werden' unless $admin =~ m/\A0|1\z/xms;
    my $sql = 'INSERT INTO '.$Ffc::Data::Prefix.'users (name, password, active, admin) VALUES (?,?,?,?)';
    Ffc::Data::dbh()->do($sql, undef, $username, crypt($pw1, Ffc::Data::cryptsalt()), $active, $admin);
}


1;

