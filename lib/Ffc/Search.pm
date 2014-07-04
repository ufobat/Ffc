package Ffc::Search;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

sub install_routes { 
    my $l = shift;
    $l->route('/search')->via('post')
      ->to(controller => 'search', action => 'search_form')
      ->name('search_form');
}

sub search_form {
    my $c = shift;
    my $query = $c->param('query');
    if ( defined $query ) {
        $c->session->{query} = $query;
    }
    else {
        $query = $c->session->{query} // '';
    }
}

1;

