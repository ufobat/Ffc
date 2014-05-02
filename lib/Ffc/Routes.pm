package Ffc::Routes;
use strict; use warnings; use utf8;

sub install_routes {
    my $l = _install_routes_auth($_[0]);
    _install_routes_std($l);
    _install_routes_avatars($l);
    _install_routes_options($l);
    _install_routes_forum($l);
    _install_routes_pmsgs($l);
    _install_routes_notes($l);
}

sub _install_routes_std {
    my $l = $_[0];
    # Standardseitenauslieferungen
    $l->any('/')->to('board#frontpage')->name('show');
    $l->get('/session' => sub { $_[0]->render( json => $_[0]->session() ) } )
      ->name('sessiondata');
    $l->get('/config' => sub { $_[0]->render( json => $_[0]->configdata() ) } )
      ->name('configdata');
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

sub _install_routes_forum {
    my $n = 'forum';
    my $r = _install_switch_bridge($_[0], $n);
    _install_edit_routes($r, $n);
    my $c = $r->bridge('/cat/:catname', [catname => $Ffc::Catqr])
              ->name('forum_cat_bridge');
    _install_show_route($c, 'forum_cat');
    _install_edit_routes($c, 'forum_cat');
    for ( [$r,$n], [$c,"${n}_cat"] ) {
        my ( $r, $n ) = @$_;
        my $k = $r->bridge('/comment')
                  ->name("${n}_comment_bridge");
        _install_edit_routes($k, "${n}_comment");
    }
}

sub _install_routes_pmsgs {
    my $n = 'pmsgs';
    my $r = _install_switch_bridge($_[0], $n)
                ->bridge('/user/:username', [username => $Ffc::Usrqr])
                ->name("${n}_user_bridge");
    _install_basic_post_routes($r, "_$n");
}

sub _install_routes_notes {
    my $n = 'notes';
    my $r = _install_switch_bridge($_[0], $n);
    _install_edit_routes($r, $n);
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
    $o->get('/fontsize/:fontsize', [fontsize => $Ffc::Fszqr])
      ->to('options#font_size')
      ->name('font_size');
    my $b = $o->bridge('/bgcolor')->name('bgcolor_bridge');
    $b->get('/none')
      ->to('options#no_bg_color')
      ->name('no_bg_color');
    $b->post('/color')
      ->to('options#bg_color')
      ->name('bg_color_form');
    $o->get('/toggle/cat/:cat', [cat => $Ffc::Catqr])
      ->to('options#toggle_cat')
      ->name('toggle_cat');

    # Benutzeroptionen mit Fomularen
    $o->post("/$_")
      ->to("options#set_$_")
      ->name("set_$_")
        for qw(email password);

    # Administratorenoptionen
    my $oa = $o->bridge('/admin')
               ->to('options#check_admin')
               ->name('adminoptions');

    # Benutzeradministration
    $oa->post('/useradd')
      ->to('options#useradmin')
      ->name('adminuseradd');
    $oa->post('/usermod/:username', [username => $Ffc::Usrqr])
      ->to('options#useradmin')
      ->name('adminusermod');

    # Kategorienadministration
    $oa->post('/catadd')
      ->to('options#categoryadmin')
      ->name('admincatadd');
    $oa->post('/catmod/:catid', [catid => $Ffc::Digqr])
      ->to('options#categoryadmin')
      ->name('admincatmod');

    # Boardeinstellungen
    $oa->post('/boardsettings/:optionkey', [optionkey => $Ffc::Optky])
      ->to('options#boardsettingsadmin')
      ->name('boardsetting');
}

sub _install_routes_avatars {
    my $p = $_[0]->bridge('/avatar')->name('avatars_bridge');
    $p->get('/:username', [username => $Ffc::Usrqr])
      ->to('avatars#avatar_show')
      ->name('avatar_show');
    $p->post('/upload')
      ->to('avatars#avatar_upload')
      ->name('avatar_upload');
}

sub _install_switch_bridge {
    my $n = $_[1];
    my $r = $_[0]->bridge("/$n")
                 ->under(sub{$_[0]->stash(act => $n)})
                 ->name("switch_${n}_bridge");
    _install_show_route($r, $_[1]);
    return $r;
}

sub _install_show_route {
    $_[0]->get('/show')
         ->to('board#frontpage')
         ->name('show'.($_[1] ? "_$_[1]" : ''));
    $_[0]->post('/search')
         ->to('board#frontpage')
         ->name('search'.($_[1] ? "_$_[1]" : ''));
}

sub _install_basic_post_routes {
    my ( $r, $n ) = @_;
    $r->post('/new')
      ->to('board#new_post')
      ->name("new_post$n");
    $r->get('/showpost/:postid', [postid => $Ffc::Digqr])
      ->to('board#show_post')
      ->name("show_post$n");
}
sub _install_edit_routes {
    my $r = $_[0];
    my $n = $_[1] ? "_$_[1]" : '';

    # post show and editing
    _install_basic_post_routes($r, $n);
    $r->get('/edit/:postid', [postid => $Ffc::Digqr])
      ->to('board#edit_post_form')
      ->name("edit_post_form$n");
    $r->post('/edit/:postid', [postid => $Ffc::Digqr])
      ->to('board#edit_post_do')
      ->name("edit_post_do$n");
    $r->get('/delete/:postid', [postid => $Ffc::Digqr])
      ->to('board#delete_post_confirm')
      ->name("delete_post$n");
    $r->post('/delete/:postid', [postid => $Ffc::Digqr])
      ->to('board#delete_post_do')
      ->name("delete_post$n");

    _install_upload_routes($r, $r);
}

sub _install_upload_routes {
    my ( $r, $n ) = @_;
    
    $r->get('/upload/:postid', [postid => $Ffc::Digqr])
      ->to('board#upload_form')
      ->name("upload_form$n");
    $r->post('/upload/:postid', [postid => $Ffc::Digqr])
      ->to('board#upload')
      ->name("upload$n");
    $r->get('/upload/delete/:uploadid', [uploadid => $Ffc::Digqr])
      ->to('board#deleteupload_confirm')
      ->name("delete_upload_confirm$n");
    $r->post('/upload/delete/:uploadid', [uploadid => $Ffc::Digqr])
      ->to('board#delete_upload_do')
      ->name("delete_upload_do$n");
}

1;

