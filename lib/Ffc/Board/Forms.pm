package Ffc::Board;
use strict; use warnings; use utf8;

sub new_entry {
    my $c = shift;
    return $c->redirect_to('show');
}

1;

