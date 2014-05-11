package Ffc::Routes;
use strict; use warnings; use utf8;
use Ffc::Routes::Options;
use Ffc::Routes::Auth;
use Ffc::Routes::Avatars;
use Ffc::Routes::Acts;

sub install_routes {
    my $app = $_[0];
    my $l = Ffc::Routes::Auth::_install_routes_auth($app->routes);
    Ffc::Routes::Avatars::_install_routes_avatars($l);
    Ffc::Routes::Options::_install_routes_options($l);
    Ffc::Routes::Acts::_install_routes_acts($l);
    _install_routes_helper($l);
    _install_routebuilder($app);
}

sub _install_routes_helper {
    my $l = $_[0];
    # Standardseitenauslieferungen
    $l->any('/')->to('board#frontpage')->name('show');
    $l->any('/help')->to('board#help')->name('help');
    $l->get('/session' => sub { $_[0]->render( json => $_[0]->session() ) } )
      ->name('sessiondata');
    $l->get('/config' => sub { $_[0]->render( json => $_[0]->configdata() ) } )
      ->name('configdata');
}

sub _install_routebuilder {
    my $app = shift;
    $app->helper( url_for_me => sub {
        my $c = shift;
        my $path = shift;
        my %params = @_;
        $params{act} = 'forum' unless $params{act};
        $c->url_for( $path );
    });
}

1;

