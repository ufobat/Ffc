package Ffc::Routes;
use strict; use warnings; use utf8;
use Ffc::Options;
use Ffc::Auth;
use Ffc::Avatars;
use Ffc::Forum;
use Ffc::Pmsgs;
use Ffc::Notes;

sub install_routes {
    my $l = Ffc::Auth::install_routes($_[0]->routes);
    Ffc::Avatars::install_routes($l);
    Ffc::Options::install_routes($l);
    Ffc::Forum::install_routes($l);
    Ffc::Pmsgs::install_routes($l);
    Ffc::Notes::install_routes($l);
    _install_routes_helper($l);
}

sub _install_routes_helper {
    my $l = $_[0];
    # Standardseitenauslieferungen
    $l->any('/')->to('forum#show')->name('show');
    $l->any('/help' => sub { $_[0]->render(template => 'help' ) } )
      ->name('help');
    $l->get('/session' => sub { $_[0]->render( json => $_[0]->session() ) } )
      ->name('sessiondata');
    $l->get('/config' => sub { $_[0]->render( json => $_[0]->configdata() ) } )
      ->name('configdata');
}

1;

