package Ffc::Options; # Routes
use 5.18.0;
use strict; use warnings; use utf8;

###############################################################################
# Routeninstaller
sub install_routes {

    # Bridge in die Optionen-Routen hinein
    my $o = $_[0]->under('/options')->name('options_bridge');
    _install_useroptions_routes( $o );

    # Bridge in die Administratorenrouten (mit Admin-Prüfung)
    my $oa = $o->under('/admin')
               ->to('options#check_admin')
               ->name('adminoptions');
    _install_adminoptions_routes( $oa );

}

###############################################################################
# Routen für die Benutzer-Einstellungen
sub _install_useroptions_routes {
    my $o = $_[0];

    # Optionsformular
    $o->get('/form')
      ->to('options#options_form')
      ->name('options_form');

    # Benutzeroptionen mit Fomularen
    $o->post("/$_")
      ->to("options#set_$_")
      ->name("set_$_")
        for qw(email password autorefresh infos hidelastseen);
    
    # Hintergrund-Farbeinstellungen
    my $b = $o->under('/bgcolor')->name('bgcolor_bridge');
    $b->get('/none')
      ->to('options#no_bg_color')
      ->name('no_bg_color');
    $b->post('/color')
      ->to('options#bg_color')
      ->name('bg_color_form');

}

###############################################################################
# Routen für die Administratoren-Einstellungen
sub _install_adminoptions_routes {
    my $oa = $_[0];

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
