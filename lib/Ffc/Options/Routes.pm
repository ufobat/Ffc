package Ffc::Options; # Routes
use strict; use warnings; use utf8;

sub install_routes {
    my $o = $_[0]->bridge('/options')->name('options_bridge');

    # Optionsformular
    $o->post('/query')
      ->to('options#query')
      ->name('query_options');
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

    # Boardeinstellungen
    $oa->post('/boardsettings/:optionkey', [optionkey => $Ffc::Optky])
       ->to('options#boardsettingsadmin')
       ->name('boardsetting');
}

1;

