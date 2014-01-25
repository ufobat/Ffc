package Ffc::Data::Auth;

use 5.010;
use strict;
use warnings;
use utf8;

use Carp;

use Ffc::Data;

sub check_password_rules {
    my $pass = shift;
    croak qq(Kein Passwort angegeben) unless $pass;
    croak qq[Passwort ungültig (8 - 64 Zeichen)] unless $pass =~ m/\A$Ffc::Data::PasswordRegex\z/xmso;
    return 1;
}

sub check_username_rules {
    my $user = shift;
    croak shift() // qq(Kein Benutzername angegeben) unless $user;
    croak shift() // qq[Benutzername ungültig (4 - 64 alphanumerische Zeichen)] unless $user =~ m/\A$Ffc::Data::UsernameRegex\z/xoms;
    return 1;
}

sub check_userid_rules {
    my $userid = shift;
    croak qq(Keine Benutzerid angegeben) unless $userid;
    croak qq{Benutzer ungültig} unless $userid =~ m/\A\d+\z/xmso;
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
    my $sql = 'SELECT u.id, u.lastseenmsgs, u.admin, u.show_images, u.theme, u.name, u.bgcolor FROM '.$Ffc::Data::Prefix.'users u WHERE UPPER(u.name)=UPPER(?) AND u.password=? AND u.active=1';
    my $data = Ffc::Data::dbh()->selectall_arrayref( $sql, undef, $user, crypt($pass, Ffc::Data::cryptsalt()));
    croak qq{Benutzer oder Passwort passen nicht oder der Benutzer ist inaktiv} unless @$data;
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
    croak shift() // $@ if $@;
    return 1;
}
sub check_username { 
    eval { get_userid( shift ) };
    croak shift() // $@ if $@;
    return 1;
}
sub check_user_exists { 
    eval { get_userid( shift ) };
    return $@ ? 0 : 1;
}
our %UserIds;
sub get_userid {
    my $username = shift;
    check_username_rules($username);
    return $UserIds{$username} if exists $UserIds{$username};
    my $sql = 'SELECT u.id FROM '.$Ffc::Data::Prefix.'users u WHERE u.name = ?';
    my $userid = Ffc::Data::dbh()->selectall_arrayref($sql, undef, $username);
    croak qq(Benutzer unbekannt).($_[0] ? " ($_[0])" : '') unless @$userid and $userid->[0]->[0];
    $UserIds{$username} = $userid->[0]->[0];
    return $userid->[0]->[0];
}
our %UserNames;
sub get_username {
    my $userid = shift;
    check_userid_rules( $userid, $_[0] );
    return $UserNames{$userid} if exists $UserNames{$userid};
    my $sql = 'SELECT u.name FROM '.$Ffc::Data::Prefix.'users u WHERE u.id=?';
    my $username = Ffc::Data::dbh()->selectall_arrayref($sql, undef, $userid);
    croak qq(Benutzer unbekannt).($_[0] ? " ($_[0])" : '') unless @$username and $username->[0]->[0];
    $UserNames{$userid} = $username->[0]->[0];
    return $username->[0]->[0];
}

1;

