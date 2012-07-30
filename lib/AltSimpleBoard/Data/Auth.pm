package AltSimpleBoard::Data::Auth;

use 5.010;
use strict;
use warnings;
use utf8;
use AltSimpleBoard::Data;
use Mojo::Utils qw(md5_sum);
use FindBin;

sub get_userdata {
    my ( $user, $pass ) = @_;
    $pass = s/'/\\'/gms;
    $pass = qx(php '$FindBin::Bin/aux/phpbb_hash.php' '$pass' '$AltSimpleBoard::Data::PhpBBPath');
    AltSimpleBoard::Data::dbh()
      ->selectrow_array( 'SELECT id FROM '.$AltSimpleBoard::Data::Prefix.'users WHERE name=? AND password=?'
        , undef, @_[0,1] );
}

1;

