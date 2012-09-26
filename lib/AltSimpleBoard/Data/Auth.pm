package AltSimpleBoard::Data::Auth;

use 5.010;
use strict;
use warnings;
use utf8;
use AltSimpleBoard::Data;
use FindBin;

sub get_userdata {
    my ( $user, $pass ) = @_;
    my ( $userid, $lastseen ) = AltSimpleBoard::Data::dbh()->selectrow_array(
        'SELECT id, lastseen FROM '.$AltSimpleBoard::Data::Prefix.'users WHERE name=? and pass=?'
        , undef, $user, crypt($pass, $AltSimpleBoard::Data::CryptSalt));
    return $userid, $lastseen;
}

1;

