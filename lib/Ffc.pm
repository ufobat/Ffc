package Ffc;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious';
use File::Spec::Functions qw(catdir);

our $Digqr = qr/\d+/xmso;
our $Usrqr = qr(\w{2,32})xmso;
our $Catqr = qr(\w{1,64})xmso;
our $Bgcqr = qr(\w{3,32})xmso;
our $Fszqr = qr(-?\d{1,3})xmso;

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
    $l->any('/')->to('board#frontpage')->name('show');
    $l->get('/session')
      ->to( sub { $_[0]->render( json => $_[0]->session() ) } )
      ->name('sessiondata');

    # Optionen-Routen
    _install_routes_avatars($l);
    _install_routes_options($l);
    _install_routes_forum($l);
    _install_routes_pmsgs($l);
    _install_routes_notes($l);
}

sub _install_show_route {
    $_[0]->get('/show')->to('board#frontpage')->name('show'.($_[1] ? "_$_[1]" : ''));
    $_[0]->post('/search')->to('board#frontpage')->name('search'.($_[1] ? "_$_[1]" : ''));
}
sub _install_basic_post_routes {
    my ( $r, $n ) = @_;
    $r->post('/new')
      ->to('board#new_post')
      ->name("new_post$n");
    $r->get('/showpost/:postid', [postid => $Digqr])
      ->to('board#show_post')
      ->name("show_post$n");
}
sub _install_edit_routes {
    my $r = $_[0];
    my $n = $_[1] ? "_$_[1]" : '';

    # Post-Handling
    _install_basic_post_routes($r, $n);
    $r->get('/edit/:postid', [postid => $Digqr])
      ->to('board#edit_post_form')
      ->name("edit_post_form$n");
    $r->post('/edit/:postid', [postid => $Digqr])
      ->to('board#edit_post_do')
      ->name("edit_post_do$n");
    $r->get('/delete/:postid', [postid => $Digqr])
      ->to('board#delete_post_confirm')
      ->name("delete_post$n");
    $r->post('/delete/:postid', [postid => $Digqr])
      ->to('board#delete_post_do')
      ->name("delete_post$n");
    
    # Upload-Handling
    $r->get('/upload/:postid', [postid => $Digqr])
      ->to('board#upload_form')
      ->name("upload_form$n");
    $r->post('/upload/:postid', [postid => $Digqr])
      ->to('board#upload')
      ->name("upload$n");
    $r->get('/upload/delete/:uploadid', [uploadid => $Digqr])
      ->to('board#deleteupload_confirm')
      ->name("delete_upload_confirm$n");
    $r->post('/upload/delete/:uploadid', [uploadid => $Digqr])
      ->to('board#delete_upload_do')
      ->name("delete_upload_do$n");
}
sub _install_switch_bridge {
    my $n = $_[1];
    my $r = $_[0]->bridge("/$n")->under(sub{$_[0]->stash(act => $n)})->name("switch_${n}_bridge");
    _install_show_route($r, $_[1]);
    return $r;
}
sub _install_routes_forum {
    my $n = 'forum';
    my $r = _install_switch_bridge($_[0], $n);
    _install_edit_routes($r, $n);
    my $c = $r->bridge('/cat/:catname', [catname => $Catqr])->name('forum_cat_bridge');
    _install_show_route($c, 'forum_cat');
    _install_edit_routes($c, 'forum_cat');
    for ( [$r,$n], [$c,"${n}_cat"] ) {
        my ( $r, $n ) = @$_;
        my $k = $r->bridge('/comment')->name("${n}_comment_bridge");
        _install_edit_routes($k, "${n}_comment");
    }
}
sub _install_routes_pmsgs {
    my $n = 'pmsgs';
    my $r = _install_switch_bridge($_[0], $n)
                ->bridge('/user/:username', [username => $Usrqr])
                ->name("${n}_user_bridge");
    _install_basic_post_routes($r, "_$n");
}
sub _install_routes_notes {
    my $n = 'notes';
    my $r = _install_switch_bridge($_[0], $n);
    _install_edit_routes($r, $n);
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
    my $p = $_[0]->bridge('/avatar')->name('avatars_bridge');
    $p->get('/:username', [username => $Usrqr])
      ->to('avatars#avatar_show')
      ->name('avatar_show');
    $p->post('/upload')
      ->to('avatars#avatar_upload')
      ->name('avatar_upload');
}

sub _install_routes_options {
    my $o = $_[0]->bridge('/options')->name('options_bridge');

    # Optionsformular
    $o->get('/form')
      ->to('options#options_form')
      ->name('options_form');
    
    # Einfache Benutzeroptionen (Schalter)
    $o->get('/switchtheme')
      ->to('options#switch_theme')
      ->name('switch_theme');
    $o->get('/fontsize/:fontsize', [fontsize => $Fszqr])
      ->to('options#font_size')
      ->name('font_size');
    my $b = $o->bridge('/bgcolor')->name('bgcolor_bridge');
    $b->get('/none')
      ->to('options#no_bg_color')
      ->name('no_bg_color');
    $b->get('/color/:bgcolor', [bgcolor => $Bgcqr])
      ->to('options#bg_color')
      ->name('bg_color');
    $o->get('/toggle/cat/:cat', [cat => $Catqr])
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
