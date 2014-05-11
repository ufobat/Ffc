package Ffc::Routes::Acts;
use strict; use warnings; use utf8;

sub _install_routes_acts {
    _install_routes_forum($_[0]);
    _install_routes_pmsgs($_[0]);
    _install_routes_notes($_[0]);
}

sub _install_routes_forum {
    my $n = 'forum';
    my $r = _install_switch_bridge($_[0], $n);

    # category management
    my $c = $r->bridge('/cat/:catname', catname => $Ffc::Catqr)
              ->name($n.'_cat_bridge');
    $n = 'forum_cat';
    _install_routes($c, $n);
}

sub _install_routes_pmsgs {
    my $n = 'pmsgs';
    my $r = _install_switch_bridge($_[0], $n);

    # user conversation management
    my $u = $r->bridge('/user/:username', username => $Ffc::Usrqr)
              ->name($n.'_user_bridge');
    $n = 'pmsgs_user';
    _install_routes($u, $n);
}

sub _install_routes_notes {
    my $r = _install_switch_bridge($_[0], 'notes');
}

sub _install_switch_bridge {
    my $n = $_[1];
    my $r = $_[0]->bridge("/$n")
                 ->under(sub{$_[0]->stash(act => $n)})
                 ->name("switch_${n}_bridge");
    _install_routes($r, $n);
    return $r;
}

sub _install_routes {
    my ( $r, $n ) = @_;

    _install_display_fac($r, $n);

    _install_edit_fac($r, $n);

    _install_upload_fac($r, $n);

    _install_comment_fac($r, $n);

    return $r;
}

sub _install_display_fac {
    my ( $r, $n ) = @_;

    # simple display
    $r->get('/show')
         ->to('board#frontpage')
         ->name('show'.($n ? "_$n" : ''));

    # search in view
    $r->post('/search')
         ->to('board#frontpage')
         ->name('search'.($n ? "_$n" : ''));

    return $r;
}

sub _install_upload_fac {
    my $n = ($_[1] // '').'_upload';
    my $r = $_[0]->bridge('/upload/:postid', postid => $Ffc::Digqr)
                 ->name($n.'_fac_bridge');

    # upload a new file for an entry
    $r->get('/form')
      ->to('board#upload_form')
      ->name($n.'_form');
    $r->post('/do')
      ->to('board#upload')
      ->name($n.'_do');

    # handle single uploads
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
    my $n = $_[1] // '';
    my $r = $_[0]->bridge('/comment/:postid', postid => $Ffc::Digqr)
                 ->name($n.'_comment_fac_bridge');

    # add a new comment for an entry

    $n = $n . '_comment';

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
    my $e = $p->bridge('/edit')
              ->name($n.'_edit');
    $e->get('/form')
      ->to('board#edit_entry_form')
      ->name($n.'_form');
    $e->post('/save')
      ->to('board#edit_entry_save')
      ->name($n.'_save');

    # delete a single entry
    my $d = $p->bridge('/delete')
              ->name($n.'_delete');
    $d->get('/confirm')
      ->to('board#delete_entry_confirm')
      ->name($n.'_delete_confirm');
    $d->post('/do')
      ->to('board#delete_do')
      ->name($n.'_delete');

    return $r;
}

1;

