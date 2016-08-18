package Ffc::Options; # Routes
use 5.18.0;
use strict; use warnings; use utf8;

###############################################################################
# Routen für die Benutzer-Einstellungen
sub install_routes {
   
    # Bridge in die Optionen-Routen hinein
    my $o = $_[0]->under('/options')->name('options_bridge');

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

1;
