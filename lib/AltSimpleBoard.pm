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
    my $authed = $routes->bridge()->to('auth#check_login');

    # options
    $authed->route('/options')->via('get')->to('board#options_form')->name('options_form');
    $authed->route('/options')->via('post')->to('board#options_save')->name('options_save');
    $authed->route('/options')->via('post')->to('board#useradmin_save')->name('useradmin_save');

    # search
    $authed->route('/search')->via('post')->to('board#search')->name('search');

    # back to the first page
    $authed->route('/show/:page', page => qr(\d+))->to('board#show')->name('show_page');
    # switch context
    $authed->route('/show/:act', act => [qw(forum notes msgs)])->to('board#switch_act')->name('switch');
    # current start page
    $authed->route('/show')->to('board#show')->name('show');


    # delete something
    $authed->route('/delete/:postid', postid => qr(\d+))->via('get')->to('board#delete_check')->name('delete_check');
    $authed->route('/delete')->via('post')->to('board#delete_post')->name('delete_post');
    # create something
    $authed->route('/new')->via('post')->to('board#insert_post')->name('insert_post');
    # update something
    my $edit = $authed->route('/edit');
    $edit->route('/:postid', postid => qr(\d+))->via('get' )->to('board#edit_form')->name('edit_form');
    $edit->route('/:postid', postid => qr(\d+))->via('post')->to('board#update_post'  )->name('update_post');

    # conversation with single user
    $authed->route('/msgs/:msgs_userid', msgs_userid => qr(\d+))->to('board#msgs_user')->name('msgs_user');

    # display special category
    $authed->route('/category/:category', category => qr(\w+))->to('board#switch_category')->name('category');

}

1;
