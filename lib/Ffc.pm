package Ffc;
use Mojo::Base 'Mojolicious';
use File::Spec::Functions qw(catdir);

# This method will run once at server start
sub startup {
    $_[0]->plugin('Ffc::Plugin::Config');
    $_[0]->plugin('Ffc::Plugin::Formats');
    $_[0]->helper(login_ok => sub { $_[0]->session->{user} ? 1 : 0 });
    _install_routes(@_);
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
             ->to('auth#check_login')
             ->name('login_check');
}

sub _install_routes_options {
    my $o = $_[0]->any('/options')->name('options_bridge');

    # Einfache Benutzeroptionen (Schalter)
    $o->get('/form')
      ->to('options#options_form')
      ->name('options_form');
    $o->get('/switchtheme')
      ->to('options#switch_theme')
      ->name('switch_theme');
    $o->get('/fontsize/:fontsize', [fontsize => qr(-?\d{1,3})])
      ->to('options#font_size')
      ->name('font_size');
    my $b = $o->get('/bgcolor')->name('bgcolor_bridge');
    $b->get('/none')
      ->to('options#no_bg_color')
      ->name('no_bg_color');
    $b->get('/color/:bgcolor', [bgcolor => qr(\w{3,32})])
      ->to('options#bg_color')
      ->name('bg_color');
    $o->get('/toggle/cat/:cat', [cat => qr(\w{1,64})])
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
