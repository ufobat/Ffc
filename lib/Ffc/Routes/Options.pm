package Ffc::Routes::Options;
use strict; use warnings; use utf8;

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

1;
