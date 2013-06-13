package Ffc;
use Mojo::Base 'Mojolicious';
use Ffc::Auth;
use Ffc::Data;
use Ffc::Data::Auth;

# This method will run once at server start
sub startup {
    my $self = shift;
    $ENV{MOJO_REVERSE_PROXY} = 1;
    my $app  = $self->app;
    Ffc::Data::set_config($app);

    $app->helper( theme => sub { $Ffc::Data::Theme } );
    $app->helper( acttitle => sub { $Ffc::Data::Acttitles{shift->stash('act')} // 'Unbekannt' } );
    $app->helper( error => sub { shift->session->{error} // '' } );
    $app->helper( url_for_me => sub {
        my $c = shift;
        my $path = shift;
        my %params = @_;
        $c->url_for( $path,
            map { 
                if ( $params{$_} ) {
                    ( $_ => $params{$_} )
                }
                elsif ( $c->stash($_) ) {
                    ( $_ => $c->stash($_) )
                }
                else {
                    ()
                }
            } qw(act page category msgs_username postid)
        );
    } );

    # Router
    my $routes = $self->routes;

    # Normal route to controller
    $routes->route('/login')->via('post')->to('auth#login')->name('login');

    my $loggedin = $routes->under(sub{
        my $c = shift;
        unless ( Ffc::Auth::check_login($c) ) {
            return Ffc::Auth::logout( $c, 'Bitte melden Sie sich an' );
        }

        my $act = $c->param('act') // 'forum';
        $c->stash(act => $act);

        my $page = $c->param('page') // 1;
        $page    = 1  unless $page =~ m/\A\d+\z/xms;
        $c->stash(page   => $page);

        my $postid = $c->param( 'postid' ) // '';
        $postid    = '' unless $postid =~ m/\A\d+\z/xms;
        $c->stash(postid => $postid);

        my $msgs_username = $c->param('msgs_username') // '';
        $c->stash( msgs_username => $msgs_username );

        my $cat = $c->param('category') // '';
        $c->stash(category => $cat);

        return 1;
    });

    # logged in
    $loggedin->route('/logout')->to('auth#logout')->name('logout');
    $loggedin->route('/')->to('board#frontpage')->name('show');

    # options
    my $options = $loggedin->route('/options');
    $options->route('/')->via('get')->to('board#options_form')->name('options_form');
    $options->route('/email_save')->via('post')->to('board#options_email_save')->name('options_email_save');
    $options->route('/password_save')->via('post')->to('board#options_password_save')->name('options_password_save');
    $options->route('/showimages_save')->via('post')->to('board#options_showimages_save')->name('options_showimages_save');
    $options->route('/theme_save')->via('post')->to('board#options_theme_save')->name('options_theme_save');
    $options->route('/avatar_save')->via('post')->to('board#options_avatar_save')->name('options_avatar_save');

    # admin options
    $options->route('/admin_save')->via('post')->to('board#useradmin_save')->name('useradmin_save');

    # user avatars
    $loggedin->route('/show_avatar/:username', username => $Ffc::Data::UsernameRegex)->to('board#show_avatar')->name('show_avatar');

    # search
    $loggedin->route('/search')->via('post')->to('board#search')->name('search');

    $routes->add_shortcut(complete_set => sub {
        my $r = shift;

        # just show the act
        $r->route('/')->to('board#frontpage')->name('show');

        # pagination
        $r->route('/:page', page => qr(\d+))->to('board#frontpage')->name('show_page');

        # delete something
        my $delete = $r->route('/delete');
        $delete->route('/:postid', postid => qr(\d+))->via('get')->to('board#delete_check')->name('delete_check');
        $delete->route('/')->via('post')->to('board#delete_post')->name('delete_post');

        # create something
        $r->route('/new')->via('post')->to('board#insert_post')->name('insert_post');

        # update something
        my $edit = $r->route('/edit');
        $edit->route('/:postid', postid => qr(\d+))->via('get' )->to('board#edit_form')->name('edit_form');
        $edit->route('/:postid', postid => qr(\d+))->via('post')->to('board#update_post'  )->name('update_post');

        return $r;
    });

    # context
    my $act = $loggedin->route('/:act', act => [qw(forum notes msgs)]);

    # just the actual frontpage
    $act->complete_set;

    # conversation with single user
    my $user = $act->route('/user/:msgs_username', msgs_username => $Ffc::Data::UsernameRegex)->to('board#msgs_user')->name('msgs_user');
    $user->complete_set;

    # display special category
    my $category = $act->route('/category/:category', category => $Ffc::Data::CategoryRegex)->to('board#switch_category')->name('category');
    $category->complete_set;

}

1;
