package Ffc::Routes::Avatars;
use strict; use warnings; use utf8;

sub _install_routes_avatars {
    my $p = $_[0]->bridge('/avatar')->name('avatars_bridge');
    $p->get('/:username', [username => $Ffc::Usrqr])
      ->to('avatars#avatar_show')
      ->name('avatar_show');
    $p->post('/upload')
      ->to('avatars#avatar_upload')
      ->name('avatar_upload');
}

1;

