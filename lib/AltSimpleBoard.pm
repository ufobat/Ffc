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

    # options
    $authed->route('/options')->via('get')->to('board#optionsform')->name('optionsform');
    $authed->route('/options')->via('post')->to('board#optionssave')->name('optionssave');

    # search
    $authed->route('/search')->via('post')->to('board#search')->name('search');

    # general action
    my $act = $authed->route('/:act', act => [qw(forum notes msgs)])->to('board#frontpage')->name('frontpage');

    # basic editing of postings
    my $crud = $authed->route('/:act', act => [qw(forum notes)]); # msg work seperatly
    # delete something
    $crud->route('/delete/:id', id => qr(\d+))->via('get')->to('board#delete')->name('delete');
    # create something
    $crud->route('/new')->via('get')->to('board#editform')->name('newform');
    $crud->route('/new')->via('post')->to('board#insert')->name('new');
    # update something
    my $edit = $crud->route('/edit');
    $edit->route('/:id', id => qr(\d+))->via('get')->to('board#editform')->name('editform');
    $crud->route('/:id', id => qr(\d+))->via('post')->to('board#update')->name('edit');

    # message system
    my $msgs  = $authed->route('/msgs');
    $msgs->route('/:userid', userid => qr(\d+))->via('get')->to('board#msgs')->name('msgs');
    $msgs->route('/:userid', userid => qr(\d+))->via('post')->to('board#msgssave')->name('msgssave');

}

1;
