package Ffc::Options; # Routes
use strict; use warnings; use utf8;

sub install_routes {
    my $o = $_[0]->under('/options')->name('options_bridge');

    # Optionsformular
    $o->get('/form')
      ->to('options#options_form')
      ->name('options_form');
    
    my $b = $o->under('/bgcolor')->name('bgcolor_bridge');
    $b->get('/none')
      ->to('options#no_bg_color')
      ->name('no_bg_color');
    $b->post('/color')
      ->to('options#bg_color')
      ->name('bg_color_form');

    my $u = $o->under('/usercolor')->name('usercolor_bridge');
    $u->get('/none')
      ->to('options#no_usercolor')
      ->name('no_usercolor');
    $u->post('/color')
      ->to('options#usercolor')
      ->name('usercolor_form');

    # Benutzeroptionen mit Fomularen
    $o->post("/$_")
      ->to("options#set_$_")
      ->name("set_$_")
        for qw(email password autorefresh infos hidelastseen);

    # Administratorenoptionen
    my $oa = $o->under('/admin')
               ->to('options#check_admin')
               ->name('adminoptions');

    # Optionsformular
    $oa->get('/form')
      ->to('options#admin_options_form')
      ->name('admin_options_form');

    # Benutzeradministration
    $oa->post('/useradd')
       ->to('options#useradmin')
       ->name('adminuseradd');
    $oa->post('/usermod/:username', [username => $Ffc::Usrqr])
       ->to('options#useradmin')
       ->name('adminusermod');

    # Boardeinstellungen
    $oa->post('/boardsettings/:optionkey', [optionkey => $Ffc::Optky])
       ->to('options#boardsettingsadmin')
       ->name('boardsetting');

    # Startseite
    $oa->post('/set_starttopic')
       ->to('options#set_starttopic')
       ->name('set_starttopic');

    # Favoritenicon
    $oa->post('/favicon')
       ->to('customstyle#favicon_upload')
       ->name('favicon_upload');
}

1;

