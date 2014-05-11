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
    my $c = $r->bridge('/cat/:catname', [catname => $Ffc::Catqr])
              ->name($n.'_cat_bridge');
    $n = 'forum_cat';
    _install_routes($c, $n);
}

sub _install_routes_pmsgs {
    my $n = 'pmsgs';
    my $r = _install_switch_bridge($_[0], $n);

    # user conversation management
    my $u = $r->bridge('/user/:username', [username => $Ffc::Usrqr])
              ->name($n.'_user_bridge');
    $n = 'pmsgs_user';
    _install_routes($u, $n);
}

sub _install_routes_notes {
    my $r = _install_switch_bridge($_[0], 'notes');
}

sub _install_switch_bridge {
    my $n = $_[1] // 'forum';
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
    my $n = $_[1] // '';
    my $r = $_[0]->bridge('/upload/:postid', [postid => $Ffc::Digqr])
                 ->name($n.'_upload_fac_bridge');

    # upload a new file for an entry
    $r->via('get')
      ->to('board#upload_form')
      ->name($n.'uploadform');
    $r->via('post')
      ->to('board#upload')
      ->name($n.'_upload');

    # delete an uploaded file from an entry
    my $u = $r->bridge('/upload/:uploadid', [uploadid => $Ffc::Digqr])
              ->name($n.'_upload_bridge');
    $u->via('get')
      ->to('board#deleteupload_confirm')
      ->name($n.'_deleteuploadconfirm');
    $u->via('post')
      ->to('board#delete_upload_do')
      ->name($n.'_deleteupload');

    return $r;
}

sub _install_comment_fac {
    my $n = $_[1] // '';
    my $r = $_[0]->bridge('/comment/:postid', [postid => $Ffc::Digqr])
                 ->name($n.'_comment_fac_bridge');

    # add a new comment for an entry

    _install_edit_fac($r, $n);

    return $r;
}

sub _install_edit_fac {
    my ( $r, $n ) = @_;

    # display an entry
    $r->get('/show/:entryid', [entryid => $Ffc::Digqr])
      ->to('board#show_entry')
      ->name($n.'_show');

    # add a new entry
    $r->post('/new')
      ->to('board#new_entry')
      ->name($n.'_new');

    # edit a single entry
    $r->get('/edit/:entryid', [entryid => $Ffc::Digqr])
      ->to('board#edit_entry_form')
      ->name($n.'_editform');
    $r->post('/edit/:entryid', [entryid => $Ffc::Digqr])
      ->to('board#edit_entry_do')
      ->name($n.'_editsave');

    # delete a single entry
    $r->get('/delete/:entryid', [entryid => $Ffc::Digqr])
      ->to('board#delete_entry_confirm')
      ->name($n.'_deleteconfirm');
    $r->post('/delete/:entryid', [entryid => $Ffc::Digqr])
      ->to('board#delete_entry_do')
      ->name($n.'_delete');

    return $r;
}

1;

