package Ffc::Data::Auth;

use 5.010;
use strict;
use warnings;
use utf8;

use Carp;

use Ffc::Data;

sub check_password_rules {
    my $pass = shift;
    confess qq(Kein Passwort angegeben) unless $pass;
    confess qq[Passwort ungültig (8 - 64 Zeichen)] unless $pass =~ m/\A$Ffc::Data::PasswordRegex\z/xms;
    return 1;
}

sub check_username_rules {
    my $user = shift;
    confess shift() // qq(Kein Benutzername angegeben) unless $user;
    confess shift() // qq[Benutzername ungültig (4 - 64 alphanumerische Zeichen)] unless $user =~ m/\A$Ffc::Data::UsernameRegex\z/xms;
    return 1;
}

sub check_userid_rules {
    my $userid = shift;
    confess qq(Keine Benutzerid angegeben) unless $userid;
    confess qq{Benutzer ungültig} unless $userid =~ m/\A\d+\z/xms;
    return 1;
}

sub check_password {
    my ( $userid, $pass ) = @_;
    check_userid_rules( $userid );
    check_password_rules($pass);
    my $sql = 'SELECT COUNT(u.id) FROM '.$Ffc::Data::Prefix.'users u WHERE u.id=? and u.password=? AND u.active=1';
    return (Ffc::Data::dbh()->selectrow_array( $sql, undef, $userid, crypt($pass, Ffc::Data::cryptsalt())))[0];
}

sub get_userdata_for_login { # for login only
    my ( $user, $pass ) = @_;
    check_username_rules($user);
    check_password_rules($pass);
    my $sql = 'SELECT u.id, u.lastseenmsgs, u.admin, u.show_images, u.theme FROM '.$Ffc::Data::Prefix.'users u WHERE u.name=? AND u.password=? AND u.active=1';
    my $data = Ffc::Data::dbh()->selectall_arrayref( $sql, undef, $user, crypt($pass, Ffc::Data::cryptsalt()));
    confess qq{Benutzer oder Passwort passen nicht oder der Benutzer ist inaktiv} unless @$data;
    return @{$data->[0]};
}

sub set_password {
    my ( $userid, $pass ) = @_;
    check_userid_rules( $userid );
    check_password_rules($pass);
    my $sql = 'UPDATE '.$Ffc::Data::Prefix.'users SET password=? WHERE id=?';
    Ffc::Data::dbh()->do($sql, undef, crypt($pass, Ffc::Data::cryptsalt()), $userid);
    return 1;
}

sub is_user_admin {
    my $userid = shift;
    check_userid_rules( $userid );
    my $sql = 'SELECT COUNT(u.id) FROM '.$Ffc::Data::Prefix.'users u WHERE u.id=? AND u.active=1 AND u.admin=1';
    return( (Ffc::Data::dbh()->selectrow_array($sql, undef, $userid))[0] ? 1 : 0 );
}

sub check_userid { 
    eval { get_username( shift ) };
    confess shift() // $@ if $@;
    return 1;
}
sub check_username { 
    eval { get_userid( shift ) };
    confess shift() // $@ if $@;
    return 1;
}
sub check_user_exists { 
    eval { get_userid( shift ) };
    return $@ ? 0 : 1;
}
sub get_userid {
    my $username = shift;
    check_username_rules($username);
    my $sql = 'SELECT u.id FROM '.$Ffc::Data::Prefix.'users u WHERE u.name = ?';
    $username = Ffc::Data::dbh()->selectall_arrayref($sql, undef, $username);
    confess qq(Benutzer unbekannt).($_[0] ? " ($_[0])" : '') unless @$username and $username->[0]->[0];
    return $username->[0]->[0];
}

sub get_username {
    my $userid = shift;
    check_userid_rules( $userid, $_[0] );
    my $sql = 'SELECT u.name FROM '.$Ffc::Data::Prefix.'users u WHERE u.id=?';
    $userid = Ffc::Data::dbh()->selectall_arrayref($sql, undef, $userid);
    confess qq(Benutzer unbekannt).($_[0] ? " ($_[0])" : '') unless @$userid and $userid->[0]->[0];
    return $userid->[0]->[0];
}

1;

