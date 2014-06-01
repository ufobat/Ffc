package Ffc::Routes::Notes;
use strict; use warnings; use utf8;

sub install_routes_notes {
    my $l = shift;

    $l->route('/notes')
      ->via('get')
      ->to('notes#show')
      ->name('show_notes');
    $l->route('/notes/:page', page => $Ffc::Digqr)
      ->via('get')
      ->to('notes#show')
      ->name('show_notes_page');

    $l->route('/notes/new')
      ->via('post')
      ->to('notes#add')
      ->name('add_note');

    $l->route('/notes/edit')
      ->via('post')
      ->to('notes#edit_do')
      ->name('edit_note_do');
    $l->route('/notes/edit/:postid', postid => $Ffc::Digqr)
      ->via('get')
      ->to('notes#edit_form')
      ->name('edit_note_form');

    $l->route('/notes/delete/:postid')
      ->via('post')
      ->to('notes#delete_do')
      ->name('delete_note_do');
    $l->route('/notes/delete/:postid', postid => $Ffc::Digqr)
      ->via('get')
      ->to('notes#delete_check')
      ->name('delete_note_check');
}

1;

