package Ffc::Plugin::Posts; # Routes
use 5.18.0;
use strict; use warnings; use utf8;

###############################################################################
# Routen jeweils für die einzelnen Beitrags-Module erzeugen
sub install_routes_posts {
    my ( $l, $cname, $start, @startps ) = @_;

    # Die erste Route zeigt die Liste der passenden Beiträge an.
    $l->route($start, @startps)->via('get')
      ->to(controller => $cname, action => 'show')->name("show_${cname}");
    # Mit dieser Route kann man direkt auf einen Beitrag verlinken, der
    # dann in einem extra Fenster angezeigt wird ohne Schnörkel und Menü
    # und so
    $l->route("$start/display/:postid", @startps, postid => $Ffc::Digqr)->via('get')
      ->to(controller => $cname, action => 'show')->name("display_${cname}");
    # Diese Route führt zur Routine, welche das Filterfeld aus dem Menü
    # umsetzt.
    $l->route("$start/query", @startps)->via('post')
      ->to(controller => $cname, action => 'query')->name("query_${cname}");
    # Diese Route wird für die Seitenweiterschaltung verwendet.
    $l->route("$start/:page", @startps, page => $Ffc::Digqr)->via('get')
      ->to(controller => $cname, action => 'show')->name("show_${cname}_page");

    # Diese Routen sorgen für die allgemeine Suche und deren Seitenweiterschaltung
    $l->route("/$cname/search")
      ->to(controller => $cname, action => 'search')
      ->name("search_${cname}_posts");
    $l->route("/$cname/search/:page", page => $Ffc::Digqr)
      ->to(controller => $cname, action => 'search')
      ->name("search_${cname}_posts_page");
    
    $l->route("/$start/limit/:postlimit", postlimit => $Ffc::Digqr)
      ->via('get')->to(controller => $cname, action => 'set_postlimit')
      ->name("set_${cname}_postlimit");

    # Die folgende Route fügt einen neuen Beitrag hinzu.
    $l->route("$start/new", @startps)->via('post')
      ->to(controller => $cname, action => 'add')->name("add_${cname}");

    if ( $cname ne 'pmsgs' ) {
        # Mit der folgenden Route wird der bearbeitete Beitrag mit
        # seinen Änderungen abgespeichert.
        $l->route("$start/edit/:postid", @startps)->via('post')
          ->to(controller => $cname, action => 'edit_do')->name("edit_${cname}_do");
        # Mit dieser Route wird ein Bearbeitungsformular für einen
        # Beitrag erstellt.
        $l->route("$start/edit/:postid", @startps, postid => $Ffc::Digqr)->via('get')
          ->to(controller => $cname, action => 'edit_form')->name("edit_${cname}_form");
        
        # Diese Route löscht einen Beitrag mit all seinen Anhängen und allem.
        $l->route("$start/delete/:postid", @startps)->via('post')
          ->to(controller => $cname, action => 'delete_do')->name("delete_${cname}_do");
        # Diese Route erzeugt ein Bestätigungsformular, was den Benutzer
        # fragt, ob er den gewünschten Beitrag tatsächlich und unwiderbringlich
        # löschen möchte.
        $l->route("$start/delete/:postid", @startps, postid => $Ffc::Digqr)->via('get')
          ->to(controller => $cname, action => 'delete_check')->name("delete_${cname}_check");
    }

    # Folgende Route lädt Dateien zu einem Beitrag hoch.
    $l->route("$start/upload/:postid", @startps)->via('post')
      ->to(controller => $cname, action => 'upload_do')->name("upload_${cname}_do");
    # Diese Route dient dem Upload von Anhängen an einen Beitrag
    # und liefert dafür das entsprechende Upload-Formular.
    $l->route("$start/upload/:postid", @startps, postid => $Ffc::Digqr)->via('get')
      ->to(controller => $cname, action => 'upload_form')->name("upload_${cname}_form");

    # Die folgende Route erlaubt den Download von Dateien, die
    # an einen Beitrag angehängt wurden.
    $l->route("$start/download/:fileid", @startps, fileid => $Ffc::Digqr)->via('get')
      ->to(controller => $cname, action => 'download')->name("download_att_${cname}");

    # Die Route löscht einen Anhang, der an einem Beitrag hängt.
    $l->route("$start/upload/delete/:postid/:fileid", @startps)->via('post')
      ->to(controller => $cname, action => 'delete_upload_do')->name("delete_upload_${cname}_do");
    # Diese Route erzeugt ein Bestätigungsformular, wenn der Benutzer
    # einen Dateianhang löschen möchte, in dem er nochmal gefragt wird, 
    # ob er das auch tatsächlich machen will.
    $l->route("$start/upload/delete/:postid/:fileid", @startps, postid => $Ffc::Digqr, fileid => $Ffc::Digqr)->via('get')
      ->to(controller => $cname, action => 'delete_upload_check')->name("delete_upload_${cname}_check");

    # Folgende Routen kümmern sich um die Beitragsbewertung
    $l->route("/$start/score/increase/:postid", @startps, postid => $Ffc::Digqr)->via('get')
      ->to(controller => $cname, action => 'inc_highscore')->name("inc_${cname}_highscore");
    $l->route("/$start/score/decrease/:postid", @startps, postid => $Ffc::Digqr)->via('get')
      ->to(controller => $cname, action => 'dec_highscore')->name("dec_${cname}_highscore");
}

1;
