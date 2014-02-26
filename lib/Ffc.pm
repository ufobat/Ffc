package Ffc;
use Mojo::Base 'Mojolicious';
use Ffc::Auth;
use Ffc::Data;
use Ffc::Data::Auth;
#use Devel::NYTProf;

our @Keys = qw(act page category msgs_username postid number);

# This method will run once at server start
sub startup {
    my $self = shift;
    $ENV{MOJO_REVERSE_PROXY} = 1;
    my $app  = $self->app;
    Ffc::Data::set_config($app);

    $app->helper( theme => sub { 
        my $s = shift()->session();
        $s->{mobile}
            ? 'breit'
            : $Ffc::Data::FixTheme 
                ? ( $Ffc::Data::Theme || 'default' )
                : ( $s->{theme} || $Ffc::Data::Theme || 'default' )
    } );
    $app->helper( bgcolor => sub { 
        $Ffc::Data::FixBgColor
            ? $Ffc::Data::BgColor
            : ( shift()->session()->{bgcolor} || $Ffc::Data::BgColor )
    } );
    $app->helper( acttitle => sub { $Ffc::Data::Acttitles{shift->stash('act') // 'forum'} // 'Unbekannt' } );
    $app->helper( error => sub { shift->session->{error} // '' } );
    $app->helper( url_for_me => sub {
        my $c = shift;
        my $path = shift;
        my %params = @_;
        %params = map { $_ => exists($params{$_}) ? $params{$_} // $c->stash($_) : $c->stash($_) } @Keys;
        $params{act} = 'forum' unless $params{act};

        if ( $params{act} eq 'forum' and $params{category} ) {
            $path .= '_category';
        }
        else {
            delete $params{category};
        }
        if ( $params{act} eq 'msgs' and $params{msgs_username} and not $path eq 'show_avatar' ) {
            $path .= '_msgs';
        }
        else { 
            delete $params{msgs_username};
        }

        $c->url_for( $path,
            map { 
                if (
                        ( $_ eq 'category' and $params{act} ne 'forum' ) or
                        ( $_ eq 'msgs_username' and $params{act} ne 'msgs' )
                    ) {
                    ()
                }
                elsif ( exists $params{$_} and $params{$_} ) {
                    ( $_ => $params{$_} )
                }
                else {
                    ()
                }
            } @Keys
        );
    } );
    $app->helper( redirect_to_show => sub {
        my $c = shift;
        my $act = $c->stash('act');
        my $cat = $c->stash('category');
        my $usr = $c->stash('msgs_username');
        my %params = ( act => $act );
        my $to = 'show';
        if ( $cat and $act eq 'forum' ) {
            $to .= '_category';
            $params{category} = $cat;
        }
        if ( $usr and $act eq 'msgs' ) {
            $to .= "_msgs";
            $params{msgs_user} = $usr;
        }
        $c->redirect_to( $to, %params );
    } );

    # Router
    my $routes = $self->routes();

    my $loggedin = $routes->under(sub{
        my $c = shift;
        unless ( Ffc::Auth::check_login($c) ) {
            Ffc::Auth::logout( $c, 'Bitte melden Sie sich an' );
            return undef;
        }

        my $act = $c->param('act') // 'forum';
        $c->stash(act => $act);

        my $page = $c->param('page') // 1;
        $page    = 1  unless $page =~ m/\A\d+\z/xmso;
        $c->stash(page   => $page);

        my $postid = $c->param( 'postid' ) // '';
        $postid    = '' unless $postid =~ m/\A\d+\z/xoms;
        $c->stash(postid => $postid);

        my $msgs_username = $c->param('msgs_username') // '';
        $c->stash( msgs_username => $msgs_username );

        my $cat = $c->param('category') // '';
        $c->stash(category => $cat);
        return 1;
    })->name('loggedin_bridge');

    # logged in
    $loggedin->route('/')->to('board#frontpage')->name('frontpage');
    $loggedin->route('/logout')->to('auth#logout')->name('logout');
    $loggedin->route('/session')->to('auth#session_data_json')->name('session_data_json');

    # display help
    $loggedin->route('/help')->to('board#help')->name('help');

    # options
    my $options = $loggedin->route('/options')->name('options_bridge');
    $options->route('/')->via('get')->to('board#options_form')->name('options_form');
    $options->route('/mobile')->via('get')->to('board#options_mobile')->name('options_set_mobile');
    $options->route('/desktop')->via('get')->to('board#options_desktop')->name('options_set_desktop');
    $options->route('/email_save')->via('post')->to('board#options_email_save')->name('options_email_save');
    $options->route('/password_save')->via('post')->to('board#options_password_save')->name('options_password_save');
    $options->route('/showimages_save')->via('post')->to('board#options_showimages_save')->name('options_showimages_save');
    $options->route('/theme_save')->via('post')->to('board#options_theme_save')->name('options_theme_save');
    $options->route('/bgcolor_save')->via('post')->to('board#options_bgcolor_save')->name('options_bgcolor_save');
    $options->route('/avatar_save')->via('post')->to('board#options_avatar_save')->name('options_avatar_save');
    $options->route('/showcat_save')->via('post')->to('board#options_showcat_save')->name('options_showcat_save');
    $options->route('/fontsize_save/:fontsize', fontsize => qr/\-?\d+/xmso)->to('board#options_fontsize_save')->name('options_fontsize_save');

    # admin options
    $options->route('/admin_save')->via('post')->to('board#useradmin_save')->name('useradmin_save');

    # user avatars
    $loggedin->route('/show_avatar/:username', username => $Ffc::Data::UsernameRegex)->to('board#show_avatar')->name('show_avatar');

    # search
    $loggedin->route('/search')->via('post')->to('board#search')->name('search');
    my $numre = qr(\d+)xmso;

    $routes->add_shortcut(complete_set => sub {
        my $r = shift;
        my $name = shift;
        $name = $name ? "_$name" : '';

        # just show the act
        $r->route('/')->to('board#frontpage')->name("show$name");
        # show it without userupdate
        $r->route('/autoreload')->to('board#frontpage_autoreload')->name("show${name}_autoreload");

        # pagination
        $r->route('/:page', page => $numre)->to('board#frontpage')->name("show_page$name");

        # create something
        $r->route('/new')->via('post')->to('board#insert_post')->name("insert_post$name");

        # file uploads
        {
            my $upload = $r->route('/upload')->name("upload_bridge$name");
            $upload->route('/show/:postid/:number', postid => $numre, number => $numre)->via('get')->to('board#get_attachement')->name("upload_show$name");

            my $uploadadd = $upload->route('/add')->name("add_bridge$name");
            $uploadadd->route('/:postid', postid => $numre)->via('get')->to('board#upload_form')->name("upload_form$name");
            $uploadadd->route('/:postid', postid => $numre)->via('post')->to('board#upload')->name("upload$name");
            
            my $uploaddelete = $upload->route('/delete/:postid', postid => $numre)->name("upload_delete_bridge$name");
            $uploaddelete->route('/:number', number => $numre)->via('get')->to('board#upload_delete_check')->name("upload_delete_check$name");
            $uploaddelete->route('/:number', number => $numre)->via('post')->to('board#upload_delete')->name("upload_delete$name");
        }

        if ( $name ne '_msgs' ) { # private messages are immutable
            # update something
            my $edit = $r->route('/edit')->name("edit_bridte$name");
            $edit->route('/:postid', postid => $numre)->via('get' )->to('board#edit_form')->name("edit_form$name");
            $edit->route('/:postid', postid => $numre)->via('post')->to('board#update_post'  )->name("update_post$name");

            # delete something
            my $delete = $r->route('/delete')->name("delete_bridge$name");
            $delete->route('/:postid', postid => $numre)->via('get')->to('board#delete_check')->name("delete_check$name");
            $delete->route('/')->via('post')->to('board#delete_post')->name("delete_post$name");
        }

        return $r;
    });

    # context
    my $act = $loggedin->route('/:act', act => [qw(forum notes msgs)])->name('act_bridge');

    # just the actual frontpage
    $act->complete_set();

    # conversation with single user
    my $user = $act->route('/user/:msgs_username', msgs_username => $Ffc::Data::UsernameRegex)->name('usermsgs_bridge');
    $user->complete_set('msgs');

    # display special category
    my $category = $act->route('/category/:category', category => $Ffc::Data::CategoryRegex)->name('category_bridge');
    $category->complete_set('category');

    # you should be able to login without being logged in allready
    $routes->route('/login')->via('post')->to('auth#login')->name('login');
}

1;
