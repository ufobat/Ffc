package Ffc::Routes::Acts;
use strict; use warnings; use utf8;

sub _install_routes_acts {
    my $n = 'act';

    my $r = $_[0]->bridge('/:act', act => [qw(forum pmsgs notes)])
                 ->name($n.'_bridge');

    # add default level routes
    _install_routes($r, $n);

    # category management
    my $cn = $n.'_cat';
    my $c = $r->bridge('/cat/:catid', catid => $Ffc::Digqr)
              ->name($n.'_bridge');
    _install_routes($c, $cn);

    # user conversation management
    my $un = $n.'_user';
    my $u = $r->bridge('/user/:userid', userid => $Ffc::Digqr)
              ->name($n.'_bridge');
    _install_routes($u, $un);
}

sub _install_routes {
    my ( $r, $n ) = @_;

    my ( $pr, $pn ) = _install_display_fac($r, $n);

    _install_edit_fac( $r,  $n  );
    _install_edit_fac( $pr, $pn );

    _install_upload_fac( $r,  $n  );
    _install_upload_fac( $pr, $pn );

    _install_comment_fac( $r,  $n  );
    _install_comment_fac( $pr, $pn );

    return $r;
}

sub _install_display_fac {
    my ( $r, $n ) = @_;

    # simple display
    $r->get('/show')
         ->to('board#frontpage')
         ->name($n.'_show');

    # search in view
    $r->post('/search')
         ->to('board#frontpage')
         ->name($n.'_search');

    # pagination
    return $r->bridge('/page/:pageid', pageid => $Ffc::Digqr)
             ->name($n.'_page_bridge'), $n . '_page';
}

sub _install_upload_fac {
    my $n = $_[1].'_upload';
    my $r = $_[0]->bridge('/upload/:postid', postid => $Ffc::Digqr)
                 ->name($n.'_bridge');

    # upload a new file for an entry
    $r->get('/form')
      ->to('board#upload_form')
      ->name($n.'_form');
    $r->post('/do')
      ->to('board#upload')
      ->name($n.'_do');

    # handle single uploads
    $n = $n . '_file';
    my $u = $r->bridge('/file/:uploadid', uploadid => $Ffc::Digqr)
              ->name($n.'_bridge');

    # show the upload file
    $u->get('/download')
      ->to('board#download')
      ->name($n.'_download');

    # delete an uploaded file from an entry
    $n = $n . '_delete';
    my $d = $u->bridge('/delete')
              ->name($n.'_bridge');
    $d->get('/confirm')
      ->to('board#delete_upload_confirm')
      ->name($n.'_confirm');
    $d->post('/do')
      ->to('board#delete_upload_do')
      ->name($n.'_do');

    return $r;
}

sub _install_comment_fac {
    my $n = $_[1] . '_comment';

    my $r = $_[0]->bridge('/comment/:postid', postid => $Ffc::Digqr)
                 ->name($n.'_bridge');

    _install_edit_fac($r, $n);

    return $r;
}

sub _install_edit_fac {
    my ( $r, $n ) = @_;

    # add a new entry
    $r->post('/new')
      ->to('board#new_entry')
      ->name($n.'_new');

    # handle single entries
    $n = $n . '_entry';
    my $p = $r->bridge('/entry/:entryid', entryid => $Ffc::Digqr)
              ->name($n.'_bridge');

    # display an entry
    $p->get('/show')
      ->to('board#show_entry')
      ->name($n.'_show');

    # edit a single entry
    my $en = $n . '_edit';
    my $e = $p->bridge('/edit')
              ->name($en . '_bridge');
    $e->get('/form')
      ->to('board#edit_entry_form')
      ->name($en.'_form');
    $e->post('/save')
      ->to('board#edit_entry_save')
      ->name($en.'_save');

    # delete a single entry
    my $dn = $n . '_delete';
    my $d = $p->bridge('/delete')
              ->name($dn . '_bridge');
    $d->get('/confirm')
      ->to('board#delete_entry_confirm')
      ->name($dn.'_confirm');
    $d->post('/do')
      ->to('board#delete_do')
      ->name($dn.'_do');

    return $r;
}

1;

