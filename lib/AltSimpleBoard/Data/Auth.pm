package AltSimpleBoard::Data::Auth;

use 5.010;
use strict;
use warnings;
use utf8;
use AltSimpleBoard::Data;
use FindBin;

sub check_password {
    my ( $userid, $pass ) = @_;
    my $sql = 'SELECT COUNT(id) FROM '.$AltSimpleBoard::Data::Prefix.'users WHERE name=? and password=? AND active=1';
    return (AltSimpleBoard::Data::dbh()->selectrow_array( $sql, undef, $userid, crypt($pass, AltSimpleBoard::Data::cryptsalt())))[0];
}

sub get_userdata {
    my ( $user, $pass ) = @_;
    my $sql = 'SELECT id, lastseen, admin FROM '.$AltSimpleBoard::Data::Prefix.'users WHERE name=? and password=? AND active=1';
    my $data = AltSimpleBoard::Data::dbh()->selectall_arrayref( $sql, undef, $user, crypt($pass, AltSimpleBoard::Data::cryptsalt()));
    die qq{Benutzer oder Passwort passen nicht} unless @$data;
    return @{$data->[0]};
}

sub set_password {
    my ( $userid, $pass ) = @_;
    die qq{Das Passwort entspricht nicht der Norm (4-16 Zeichen)} unless $pass =~ m/\A.{4,16}\z/xms;
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'users SET password=? WHERE id=? AND active=1';
    AltSimpleBoard::Data::dbh()->do($sql, undef, crypt($pass, AltSimpleBoard::Data::cryptsalt()), $userid);
}

1;

