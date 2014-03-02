package Ffc;
use Mojo::Base 'Mojolicious';
use Digest::SHA 'sha512_base64';
use Ffc::Config;

# This method will run once at server start
sub startup {
    my $app    = shift;

    my $config = Ffc::Config::Config();
    my $path   = Ffc::Config::Datapath();
    my $dbh    = Ffc::Config::Dbh();

    $app->secret($config->{cookiesecret});
    $app->sessions->cookie_name(
        $config->{cookiename} || $Ffc::Config::Defaults{cookiename});

    $app->defaults({
        map( {;$_ => ''} qw(error info) ),
        map( {;$_ => $config->{$_} || $Ffc::Config::Defaults{$_}} 
            qw(favicon commoncattitle title) ),
    });

    $app->helper(fontsize => sub { $Ffc::Config::FontSizeMap{$_[0]} || 1 });
    $app->helper(config   => sub { $config } );
    $app->helper(path     => sub { $path   } );
    $app->helper(dbh      => sub { $dbh    } );
    $app->helper(password => 
        sub { sha512_base64 $_[0], $config->{cryptsalt} } );

    $app->before_render(sub{
        my $c = $_[0];
        my $s = $c->session;
        $c->stash(fontsize => $s->{fontsize} // 0);
        $c->stash(backgroundcolor => 
            $config->{fixbackgroundcolor}
                ? $config->{backgroundcolor}
                : ( $s->{backgroundcolor} || $config->{backgroundcolor} )
        );
    });

    # Router
    my $r = $app->routes;

    # Normal route to controller
    $r->post('/login')->to('auth#login')->name('login');
    $r->any('/logout')->to('auth#logout')->name('logout');
    my $l = $r->under(\&Ffc::Auth::check_login)->name('login_check');
    $r->get('/')->to('example#welcome')->name('show');;
}

1;
