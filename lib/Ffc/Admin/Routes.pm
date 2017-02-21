package Ffc::Admin; # Routes
use 5.18.0;
use strict; use warnings; use utf8;

###############################################################################
# Routen für die Administratoren-Einstellungen
sub install_routes {
    
    # Bridge in die Administratorenrouten (mit Admin-Prüfung)
    my $oa = $_[0]->under('/admin')
                  ->to('admin#check_admin')
                  ->name('adminoptions');

    $oa->get('/form')
      ->to('admin#admin_options_form')
      ->name('admin_options_form');

    # Benutzeradministration
    $oa->post('/useradd')
       ->to('admin#useradmin')
       ->name('adminuseradd');
    $oa->post('/usermod/:newusername', [newusername => $Ffc::Usrqr])
       ->to('admin#useradmin')
       ->name('adminusermod');

    # Boardeinstellungen
    $oa->post('/boardsettings/:optionkey', [optionkey => $Ffc::Admin::Optky])
       ->to('admin#boardsettingsadmin')
       ->name('boardsetting');

    # Startseite
    $oa->post('/set_starttopic')
       ->to('admin#set_starttopic')
       ->name('set_starttopic');

    # Favoritenicon
    $oa->post('/favicon')
       ->to('customstyle#favicon_upload')
       ->name('favicon_upload');
}

1;
