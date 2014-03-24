package Ffc;
use strict; use warnings; use utf8;
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
    _install_routes_avatars($l);
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

sub _install_routes_avatars {
    my $p = $_[0]->any('/avatar')->name('avatars_bridge');
    $p->get('/:username', [username => qr(\w{2,32})xmso])
      ->to('avatars#avatar_show')
      ->name('avatar_show');
    $p->post('/upload')
      ->to('avatars#avatar_upload')
      ->name('avatar_upload');
}

sub _install_routes_options {
    my $o = $_[0]->any('/options')->name('options_bridge');

    # Optionsformular
    $o->get('/form')
      ->to('options#options_form')
      ->name('options_form');
    
    # Einfache Benutzeroptionen (Schalter)
    $o->get('/switchtheme')
      ->to('options#switch_theme')
      ->name('switch_theme');
    $o->get('/fontsize/:fontsize', [fontsize => qr(-?\d{1,3})xmso])
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

    # Benutzeroptionen mit Fomularen
    $o->post("/$_")
      ->to("options#set_$_")
      ->name("set_$_")
        for qw(email password);

    # Benutzeradministration
    $o->post('/useradmin')
      ->to('options#useradmin')
      ->name('useradmin');
}

1;
