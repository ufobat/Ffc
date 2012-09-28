package AltSimpleBoard;
use Mojo::Base 'Mojolicious';
use AltSimpleBoard::Data;

# This method will run once at server start
sub startup {
    my $self = shift;
    $ENV{MOJO_REVERSE_PROXY} = 1;
    my $app  = $self->app;
    AltSimpleBoard::Data::set_config($app);

    # Router
    my $routes = $self->routes;

    # Normal route to controller
    $routes->route('/logout')->to('auth#logout')->name('logout');
    $routes->route('/login')->to('auth#login')->name('login');
    $routes->route('/')->to('board#startpage');
    my $authed = $routes->bridge()->to('auth#check_login');

    # general action
    my $act = $authed->route('/:act', act => [qw(forum notes msgs)])->name('act');
    $act->route('/:page', page => qr(\d+))->to('board#frontpage')->name('frontpage');
    $act->route('/')->to(controller => 'board', action => 'frontpage', page => 1);

    # search
    $act->route('/search')->via('post')->to('board#search')->name('search');

    # options
    $act->route('/options')->via('get')->to('board#optionsform')->name('optionsform');
    $act->route('/options')->via('post')->to('board#optionssave')->name('optionssave');
}

1;
