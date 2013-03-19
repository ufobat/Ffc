package Ffc::Data::Auth;

use 5.010;
use strict;
use warnings;
use utf8;
use Ffc::Data;
use FindBin;

sub check_password_rules {
    my $pass = shift;
    die qq(Kein Passwort angegeben) unless $pass;
    die qq[Passwort ungültig (8 - 64 Zeichen)] unless $pass =~ m/\A\S{8,64}\z/xms;
    return 1;
}

sub check_username_rules {
    my $user = shift;
    die qq(Kein Benutzername angegeben) unless $user;
    die qq[Benutzername ungültig (4 - 64 alphanumerische Zeichen)] unless $user =~ m/\A\w{4,64}\z/xms;
    return 1;
}

sub check_userid_rules {
    my $userid = shift;
    die qq(Keine Benutzerid angegeben) unless $userid;
    die qq{Benutzer ungültig} unless $userid =~ m/\A\d+\z/xms;
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
    die qq{Benutzer oder Passwort passen nicht oder der Benutzer ist inaktiv} unless @$data;
    return @{$data->[0]};
}

sub set_password {
    my ( $userid, $pass ) = @_;
    check_userid_rules( $userid );
    check_password_rules($pass);
    my $sql = 'UPDATE '.$Ffc::Data::Prefix.'users u SET u.password=? WHERE u.id=?';
    Ffc::Data::dbh()->do($sql, undef, crypt($pass, Ffc::Data::cryptsalt()), $userid);
}

sub is_user_admin {
    my $userid = shift;
    check_userid_rules( $userid );
    my $sql = 'SELECT COUNT(u.id) FROM '.$Ffc::Data::Prefix.'users u WHERE u.id=? AND u.active=1 AND u.admin=1';
    return (Ffc::Data::dbh()->selectrow_array($sql, undef, $userid))[0] ? 1 : 0;
}

sub check_user { 
    eval { get_username( shift ) };
    die shift() // $@ if $@;
    return 1;
}
sub get_userid {
    my $username = shift;
    check_username_rules($username);
    my $sql = 'SELECT u.id FROM '.$Ffc::Data::Prefix.'users u WHERE u.name = ?';
    $username = Ffc::Data::dbh()->selectall_arrayref($sql, undef, $username);
    return $username->[0]->[0] if @$username;
    return;
}

sub get_username {
    my $userid = shift;
    check_userid_rules( $userid );
    my $sql = 'SELECT u.name FROM '.$Ffc::Data::Prefix.'users u WHERE u.id=?';
    $userid = Ffc::Data::dbh()->selectall_arrayref($sql, undef, $userid);
    die qq{Benutzer unbekannt} unless @$userid and $userid->[0]->[0];
    return $userid;
}

1;

