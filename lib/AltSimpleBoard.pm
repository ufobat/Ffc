package AltSimpleBoard;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
    my $self = shift;

    # Router
    my $r = $self->routes;

    # Normal route to controller
    $r->route('/')->to('auth#login_form');
    $r->route('/logout')->to('auth#logout');
    $r->route('/login')->to('auth#login');
    my $b = $r->bridge()->to('auth#check_login');
    $r->route('/board')->to('board#frontpage');
}

1;
