package AltSimpleBoard::Data::Auth;

use 5.010;
use strict;
use warnings;
use utf8;
use AltSimpleBoard::Data;

sub get_userdata {
    AltSimpleBoard::Data::dbh()
      ->selectrow_array( 'SELECT id FROM '.$AltSimpleBoard::Data::Prefix.'users WHERE name=? AND password=?'
        , undef, @_[0,1] );
}

1;

