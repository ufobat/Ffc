package Ffc::Routes::Uploads;
use strict; use warnings; use utf8;

sub install_routes_uploads {
    my $l = shift;
    my $r = $l->bridge('/upload/:postid', postid => $Ffc::Digqr)
                 ->name('upload_bridge');

    # upload a new file for an entry
    $r->get('/form')
      ->to('board#upload_form')
      ->name('upload_form');
    $r->post('/do')
      ->to('board#upload')
      ->name('upload_do');

    # handle single uploads
    my $u = $r->bridge('/file/:uploadid', uploadid => $Ffc::Digqr)
              ->name('file_bridge');

    # show the upload file
    $u->get('/download')
      ->to('board#download')
      ->name('download');

    # delete an uploaded file from an entry
    my $d = $u->bridge('/delete')
              ->name('upload_delete_bridge');
    $d->get('/confirm')
      ->to('board#delete_upload_confirm')
      ->name('upload_delete_confirm');
    $d->post('/do')
      ->to('board#delete_upload_do')
      ->name('upload_delete_do');

    return $r;
}

1;

