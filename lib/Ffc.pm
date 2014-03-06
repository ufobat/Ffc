package Ffc;
use Mojo::Base 'Mojolicious';
use Digest::SHA 'sha512_base64';
use File::Spec::Functions qw(catdir);
use Ffc::Config;
use Ffc::Auth;

# This method will run once at server start
sub startup {
    _apply_preparations(@_);
    _install_routes(@_);
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
        act => 'forum',
        map( {;$_.'count' => 0} qw(newmsgs newpost note) ),
        map( {;$_ => ''} qw(error info) ),
        map( {;$_ => $config->{$_} || $Ffc::Config::Defaults{$_}} 
            qw(favicon commoncattitle title) ),
        map( {;$_ => ( $config->{$_} && $config->{$_} =~ m/(\d+)/xmso ) ? $1 : $Ffc::Config::Defaults{$_}} 
            qw(urlshorten) ),
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
    my $l = _install_routes_auth($_[0]->routes);

    # Standardseitenauslieferungen
    $l->get('/')->to('board#frontpage')->name('show');
    $l->get('/session')
      ->to( sub { $_[0]->render( json => $_[0]->session() ) } )
      ->name('sessiondata');

    # Optionen-Routen
    _install_routes_options($l);
}

sub _install_routes_auth {
    my $r = $_[0];
    # Anmeldehandling und Anmeldeprüfung
    $r->post('/login')->to('auth#login')->name('login');
    $r->get('/logout')->to('auth#logout')->name('logout');
    return $r->bridge('/')
              ->via('get')
              ->to('auth#check_login')
              ->name('login_check');
}

sub _install_routes_options {
    my $o = $_[0]->get('/options')->name('options_bridge');

    # Einfache Benutzeroptionen (Schalter)
    $o->get('/form')
      ->to('options#options_form')
      ->name('options_form');
    $o->get('/switchtheme')
      ->to('options#switch_theme')
      ->name('switch_theme');
    $o->get('/fontsize/:fontsize', [fontsize => qr(-?\d+)])
      ->to('options#font_size')
      ->name('font_size');
    my $b = $o->get('/bgcolor')->name('bgcolor_bridge');
    $b->get('/none')
      ->to('options#no_bg_color')
      ->name('no_bg_color');
    $b->get('/color/:bgcolor', [bgcolor => qr(\#?\w+)])
      ->to('options#bg_color')
      ->name('bg_color');
    $o->get('/toggle/cat/:cat', [cat => qr(\w+)])
      ->to('options#toggle_cat')
      ->name('toggle_cat');
    $o->get('/toggle/show_images')
      ->to('options#toggle_show_images')
      ->name('toggle_show_images');

    # Benutzeroptionen mit Fomularen
    $o->post("/$_")
      ->to("options#set_$_")
      ->name("set_$_")
        for qw(email password avatar);

    # Benutzeradministration
    $o->post('/useradmin')
      ->to('options#useradmin')
      ->name('useradmin');
}

1;
