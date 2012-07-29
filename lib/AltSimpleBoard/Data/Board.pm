package AltSimpleBoard::Data::Board;

use 5.010;
use strict;
use warnings;
use utf8;
use AltSimpleBoard::Data;

sub get_posts {
    AltSimpleBoard::Data::dbh()
      ->selectall_arrayref( 'SELECT id, user, time, text FROM '.$AltSimpleBoard::Data::Prefix.'posts'
        , undef );
}

1;

