package Ffc::Forum;
use 5.18.0;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

###############################################################################
# Routen für das Themenlisten-Handling einrichten
sub install_topics_routes {
    my $l = $_[0];
    
    # Anzeige der Themenliste
    $l->route('/forum')->via('get')
      ->to(controller => 'forum', action => 'show_topiclist')
      ->name('show_forum_topiclist');

    # Neue Themen erstellen
    $l->route('/topic/new')->via('get')
      ->to(controller => 'forum', action => 'add_topic_form')
      ->name('add_forum_topic_form');
    $l->route('/topic/new')->via('post')
      ->to(controller => 'forum', action => 'add_topic_do')
      ->name('add_forum_topic_do');

    # Ignorieren von Überschriften
    $l->route('/topic/:topicid/ignore', topicid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'ignore_topic_do')
      ->name('ignore_forum_topic_do');
    $l->route('/topic/:topicid/unignore', topicid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'unignore_topic_do')
      ->name('unignore_forum_topic_do');

    # Pinnen (anheften oder favorisieren) von Überschriften
    $l->route('/topic/:topicid/pin', topicid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'pin_topic_do')
      ->name('pin_forum_topic_do');
    $l->route('/topic/:topicid/unpin', topicid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'unpin_topic_do')
      ->name('unpin_forum_topic_do');

    # Themenlistensortierung anpassen
    $l->route('/topic/sort/chronological')
      ->to(controller => 'forum', action => 'sort_order_chronological')
      ->name('topic_sort_chronological');
    $l->route('/topic/sort/alphabetical')
      ->to(controller => 'forum', action => 'sort_order_alphabetical')
      ->name('topic_sort_alphabetical');

    # Anzahl angezeigter Überschriften anpassen
    $l->route('/topic/limit/:topiclimit', topiclimit => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'set_topiclimit')
      ->name('topic_set_topiclimit');

    # Überschrift als gelesen (eigentlich gesehen) markieren
    $l->route('/topic/:topicid/seen', topicid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'mark_seen')
      ->name('topic_mark_seen');

    # Überschriften ändern
    $l->route('/topic/:topicid/edit', topicid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'edit_topic_form')
      ->name('edit_forum_topic_form');
    $l->route('/topic/:topicid/moveto/:topicidto', topicid => $Ffc::Digqr, topicidto => $Ffc::Digqr)
      ->via('get')
      ->to(controller => 'forum', action => 'move_topic_do')
      ->name('move_forum_topic_do');
    $l->route('/topic/:topicid/edit', topicid => $Ffc::Digqr)->via('post')
      ->to(controller => 'forum', action => 'edit_topic_do')
      ->name('edit_forum_topic_do');

    # Seitenweiterschaltung
    $l->route('/forum/:page', page => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'show_topiclist')
      ->name('show_forum_topiclist_page');

    # Diese Route ist der Startpunkt, um im Forum Beiträge in andere Themen zu verschieben
    # Diese Route liefert eine Liste von Themen, in die ein Beitrag verschoben werden kann
    $l->route('/topic/:topicid/move/:postid', topicid => $Ffc::Digqr, postid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'moveto_topiclist_select')->name('move_forum_topiclist');
    # Diese Route verschiebt einen Beitrag in ein anderes Thema
    $l->route('/topic/:topicid/move/:postid', topicid => $Ffc::Digqr, postid => $Ffc::Digqr)->via('post')
      ->to(controller => 'forum', action => 'moveto_topiclist_do')->name('move_forum_topiclist_do');

    # Alle Beiträge in einem Thema in einem Rutsch als gelesen markieren
    $l->route('/topic/mark_all_read')->via('get')
      ->to(controller => 'forum', action => 'mark_all_seen')
      ->name('mark_forum_topic_all_seen');
    
}

1;
