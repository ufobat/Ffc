package AltSimpleBoard::Board;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use AltSimpleBoard::Data::Board;

sub frontpage {
    my $c = shift;
    $c->stash( posts => AltSimpleBoard::Data::Board::get_posts() );
}

1;

