package Ffc::Routes::Avatars;
use strict; use warnings; use utf8;

sub install_routes_avatars {
    my $p = $_[0]->bridge('/avatar')->name('avatars_bridge');
    $p->route('/:userid', userid => $Ffc::Digqr)
      ->via('get')
      ->to('avatars#avatar_show')
      ->name('avatar_show');
    $p->route('/upload')
      ->via('post')
      ->to('avatars#avatar_upload')
      ->name('avatar_upload');
}

1;

