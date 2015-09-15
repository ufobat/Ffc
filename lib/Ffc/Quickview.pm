package Ffc::Quickview;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

sub install_routes {
    $_[0]->get('/quick')
         ->to(controller => 'quickview', action => 'display_html')
         ->name('quickview_html');
    $_[0]->get('/json')
         ->to(controller => 'quickview', action => 'display_json')
         ->name('quickview_json');
}

sub display_html {
    $_[0]->counting;
    $_[0]->render(template => 'quickview');
}

sub display_json {
    $_[0]->counting;
    $_[0]->render(json => {
        users  => $_[0]->stash('users' ),
        topics => $_[0]->stash('topics'),
    });
}

1;

