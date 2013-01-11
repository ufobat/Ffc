package AltSimpleBoard;
use Mojo::Base 'Mojolicious';
use AltSimpleBoard::Data;

sub switch_act { 
    my $s = $_[1]->session;
    $s->{act} = $_[2];
    $s->{category} = undef;
}

# This method will run once at server start
sub startup {
    my $self = shift;
    $ENV{MOJO_REVERSE_PROXY} = 1;
    my $app  = $self->app;
    AltSimpleBoard::Data::set_config($app);

    $app->helper( act => sub { shift->session->{act} } );
    $app->helper( acttitle => sub { $AltSimpleBoard::Data::Acttitles{shift->session->{act}} // 'Unbekannt' } );

    # Router
    my $routes = $self->routes;

    # Normal route to controller
    $routes->route('/logout')->to('auth#logout')->name('logout');
    $routes->route('/login')->to('auth#login')->name('login');
    $routes->route('/')->to('board#startpage');
    $routes->route('/registerform')->to('auth#registerform')->name('registerform');
    $routes->route('/registersave')->to('auth#registersave')->name('registersave');
    my $authed = $routes->bridge()->to('auth#check_login');

    # options
    $authed->route('/options')->via('get')->to('board#optionsform')->name('optionsform');
    $authed->route('/options')->via('post')->to('board#optionssave')->name('optionssave');

    # search
    $authed->route('/search')->via('post')->to('board#search')->name('search');

    # back to the first page
    $authed->route('/show/:page', page => qr(\d+))->to('board#show')->name('show_page');
    # switch context
    $authed->route('/show/:act', act => [qw(forum notes msgs)])->to('board#switch')->name('switch');
    # current start page
    $authed->route('/show')->to('board#show')->name('show');


    # delete something
    $authed->route('/delete/:postid', postid => qr(\d+))->via('get')->to('board#delete')->name('delete');
    # create something
    $authed->route('/new')->via('post')->to('board#insert')->name('new');
    # update something
    my $edit = $authed->route('/edit');
    $edit->route('/:postid', postid => qr(\d+))->via('get' )->to('board#editform')->name('editform');
    $edit->route('/:postid', postid => qr(\d+))->via('post')->to('board#update'  )->name('edit');

    # conversation with single user
    $authed->route('/msgs/:msgs_userid', msgs_userid => qr(\d+))->to('board#msgs_user')->name('msgs_user');

    # display special category
    $authed->route('/category/:categoryid', categoryid => qr(\d+))->to('board#switch_category')->name('category');

}

1;
