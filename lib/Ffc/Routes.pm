package Ffc::Routes;
use strict; use warnings; use utf8;
use Ffc::Routes::Options;
use Ffc::Routes::Auth;
use Ffc::Routes::Avatars;
use Ffc::Routes::Forum;
use Ffc::Routes::Pmsgs;
use Ffc::Routes::Notes;

sub install_routes {
    my $app = $_[0];
    my $l = Ffc::Routes::Auth::install_routes_auth($app->routes);
    Ffc::Routes::Avatars::install_routes_avatars($l);
    Ffc::Routes::Options::install_routes_options($l);
    Ffc::Routes::Forum::install_routes_forum($l);
    Ffc::Routes::Pmsgs::install_routes_pmsgs($l);
    Ffc::Routes::Notes::install_routes_notes($l);
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

