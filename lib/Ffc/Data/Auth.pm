package Ffc::Data::Auth;

use 5.010;
use strict;
use warnings;
use utf8;
use Ffc::Data;
use FindBin;

sub check_password {
    my ( $userid, $pass ) = @_;
    my $sql = 'SELECT COUNT(u.id) FROM '.$Ffc::Data::Prefix.'users u WHERE u.id=? and u.password=? AND u.active=1';
    return (Ffc::Data::dbh()->selectrow_array( $sql, undef, $userid, crypt($pass, Ffc::Data::cryptsalt())))[0];
}

sub get_userdata_for_login { # for login only
    my ( $user, $pass ) = @_;
    my $sql = 'SELECT u.id, u.lastseenmsgs, u.admin, u.show_images, u.theme FROM '.$Ffc::Data::Prefix.'users u WHERE u.name=? AND u.password=? AND u.active=1';
    my $data = Ffc::Data::dbh()->selectall_arrayref( $sql, undef, $user, crypt($pass, Ffc::Data::cryptsalt()));
    die qq{Benutzer oder Passwort passen nicht oder der Benutzer ist inaktiv} unless @$data;
    return @{$data->[0]};
}

sub set_password {
    my ( $userid, $pass ) = @_;
    die qq{Das Passwort entspricht nicht der Norm (4-16 Zeichen)} unless $pass =~ m/\A.{4,16}\z/xms;
    my $sql = 'UPDATE '.$Ffc::Data::Prefix.'users u SET u.password=? WHERE u.id=?';
    Ffc::Data::dbh()->do($sql, undef, crypt($pass, Ffc::Data::cryptsalt()), $userid);
}

sub is_user_admin {
    my $id = shift;
    die qq{Benutzerid ungültig} unless $id =~ m/\A\d+\z/xms;
    my $sql = 'SELECT COUNT(u.id) FROM '.$Ffc::Data::Prefix.'users u WHERE u.id=? AND u.active=1 AND u.admin=1';
    return (Ffc::Data::dbh()->selectrow_array($sql, undef, $id))[0];
}


1;

