package Ffc;
use Mojo::Base 'Mojolicious';
use Digest::SHA 'sha512_base64';
use File::Spec::Functions qw(catdir);
use Ffc::Config;
use Ffc::Auth;

# This method will run once at server start
sub startup {
    $_[0]->_apply_preparations();
    $_[0]->_install_routes();
}

sub _apply_preparations {
    my $app = $_[0];

    my @path   = Ffc::Config::Datapath();
    my $config = Ffc::Config::Config();
    my $bpath  = catdir @path;
    my $dbh    = Ffc::Config::Dbh();

    $app->secrets([$config->{cookiesecret}]);
    $app->sessions->cookie_name(
        $config->{cookiename} || $Ffc::Config::Defaults{cookiename});

    $app->defaults({
        map( {;$_ => ''} qw(error info) ),
        map( {;$_ => $config->{$_} || $Ffc::Config::Defaults{$_}} 
            qw(favicon commoncattitle title) ),
    });

    $app->helper(fontsize  => sub { $Ffc::Config::FontSizeMap{$_[1]} || 1 });
    $app->helper(config    => sub { $config } );
    $app->helper(path      => sub { $bpath  } );
    $app->helper(dbh       => \&Ffc::Config::Dbh );
    $app->helper(stylefile => 
        sub { $Ffc::Config::Styles[$_[0]->session()->{style} ? 1 : 0] } );
    $app->helper(password  => 
        sub { sha512_base64 $_[1], $config->{cryptsalt} } );

    $app->hook(before_render => sub { 
        my $c = $_[0];
        my $s = $c->session;
        $c->stash(fontsize => $s->{fontsize} // 0);
        $c->stash(backgroundcolor => 
            $config->{fixbackgroundcolor}
                ? $config->{backgroundcolor}
                : ( $s->{backgroundcolor} || $config->{backgroundcolor} )
        );
    });
}

sub _install_routes {
    my $app = $_[0];

    # Router
    my $r = $app->routes;

    # Normal route to controller
    $r->post('/login')->to('auth#login')->name('login');
    $r->any('/logout')->to('auth#logout')->name('logout');
    my $l = $r->under(\&Ffc::Auth::check_login)->name('login_check');
    $l->get('/')->to('board#frontpage')->name('show');;
}

1;
