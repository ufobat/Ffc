package AltSimpleBoard::Data::Board;

use 5.010;
use strict;
use warnings;
use utf8;
use AltSimpleBoard::Data;

sub get_posts {
    my $data = AltSimpleBoard::Data::dbh()
      ->selectall_arrayref( 'SELECT id, user, time, text, avatar FROM '.$AltSimpleBoard::Data::Prefix.'posts'
        , undef );
    for my $p ( @$data ) {
        my @t = localtime $p->[2];
        $t[5] += 1900; $t[4]++;
        $p->[2] = sprintf '%d.%d.%d, %d:%02d', @t[3,4,5,2,1];
        $p->[3] =~ s{\n}{</p>\n<p>}gsm;
        $p->[3] = "<p>$p->[3]</p>";
    }
    return $data;
}

1;

