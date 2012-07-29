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
    my $r = $self->routes;

    # Normal route to controller
    $r->route('/')->to('auth#login_form')->name('login_form');
    $r->route('/logout')->to('auth#logout')->name('logout');
    $r->route('/login')->to('auth#login')->name('login');
    my $b = $r->bridge()->to('auth#check_login');
    $b->route('/board')->to('board#frontpage')->name('frontpage');
}

1;
