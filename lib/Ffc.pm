package Ffc;
use Mojo::Base 'Mojolicious';
use Ffc::Data;

sub switch_act { 
    return unless $_[1] and $_[1]->isa('Mojolicious::Controller');
    my $s = $_[1]->session;
    $s->{act} = $_[2] // 'forum';
    $s->{act} = 'forum' unless $s->{act} =~ m/\A(?:forum|notes|msgs)\z/xms;
    $s->{category} = undef;
    delete $s->{msgs_userid}; delete $s->{msgs_username};
    return 1;
}

# This method will run once at server start
sub startup {
    my $self = shift;
    $ENV{MOJO_REVERSE_PROXY} = 1;
    my $app  = $self->app;
    Ffc::Data::set_config($app);

    $app->helper( act => sub { shift->session->{act} // 'forum' } );
    $app->helper( theme => sub { $Ffc::Data::Theme } );
    $app->helper( acttitle => sub { $Ffc::Data::Acttitles{shift->session->{act}} // 'Unbekannt' } );
    $app->helper( error => sub { shift->session->{error} // '' } );

    # Router
    my $routes = $self->routes;

    # Normal route to controller
    $routes->route('/logout')->to('auth#logout')->name('logout');
    $routes->route('/login')->to('auth#login')->name('login');
    $routes->route('/')->to('board#frontpage')->name('show');

    # options
    $routes->route('/options')->via('get')->to('board#options_form')->name('options_form');
    $routes->route('/options')->via('post')->to('board#options_save')->name('options_save');
    $routes->route('/optionsadmin')->via('post')->to('board#useradmin_save')->name('useradmin_save');

    # search
    $routes->route('/search')->via('post')->to('board#search')->name('search');

    # back to the first page
    $routes->route('/:page', page => qr(\d+))->to('board#frontpage')->name('show_page');
    # switch context
    $routes->route('/:act', act => [qw(forum notes msgs)])->to('board#switch_act')->name('switch');

    # delete something
    $routes->route('/delete/:postid', postid => qr(\d+))->via('get')->to('board#delete_check')->name('delete_check');
    $routes->route('/delete')->via('post')->to('board#delete_post')->name('delete_post');
    # create something
    $routes->route('/new')->via('post')->to('board#insert_post')->name('insert_post');
    # update something
    my $edit = $routes->route('/edit');
    $edit->route('/:postid', postid => qr(\d+))->via('get' )->to('board#edit_form')->name('edit_form');
    $edit->route('/:postid', postid => qr(\d+))->via('post')->to('board#update_post'  )->name('update_post');

    # conversation with single user
    $routes->route('/msgs/:msgs_userid', msgs_userid => qr(\d+))->to('board#msgs_user')->name('msgs_user');

    # display special category
    $routes->route('/category/:category', category => qr(\w+))->to('board#switch_category')->name('category');

}

1;
