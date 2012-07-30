package AltSimpleBoard::Data::Auth;

use 5.010;
use strict;
use warnings;
use utf8;
use AltSimpleBoard::Data;
use FindBin;

sub get_userdata {
    my ( $user, $pass ) = @_;
    my ( $id, $hash ) = AltSimpleBoard::Data::dbh()->selectrow_array(
        'SELECT id, password FROM '.$AltSimpleBoard::Data::Prefix.'users WHERE name=?'
        , undef, $user);
    my $res = qx(php '$FindBin::Bin/../aux/phpbb_hash.php' '$AltSimpleBoard::Data::PhpBBPath' '$pass' '$hash');
    return $id;
}

1;

