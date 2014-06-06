package Ffc::Plugin::Posts; # Routes
use 5.010;
use strict; use warnings; use utf8;

sub install_routes_posts {
    my ( $l, $cname, $start ) = @_;

    # Die erste Route zeigt die Liste der passenden Beiträge an.
    $l->route($start)->via('get')
      ->to(controller => $cname, action => 'show')->name("show_${cname}");
    # Diese Route führt zur Routine, welche das Filterfeld aus dem Menü
    # umsetzt.
    $l->route("$start/query")->via('post')
      ->to(controller => $cname, action => 'query')->name("query_${cname}");
    # Diese Route wird für die Seitenweiterschaltung verwendet.
    $l->route("$start/:page", page => $Ffc::Digqr)->via('get')
      ->to(controller => $cname, action => 'show')->name("show_${cname}_page");
    
    # Die folgende Route fügt einen neuen Beitrag hinzu.
    $l->route("$start/new")->via('post')
      ->to(controller => $cname, action => 'add')->name("add_${cname}");

    # Mit der folgenden Route wird der bearbeitete Beitrag mit
    # seinen Änderungen abgespeichert.
    $l->route("$start/edit")->via('post')
      ->to(controller => $cname, action => 'edit_do')->name("edit_${cname}_do");
    # Mit dieser Route wird ein Bearbeitungsformular für einen
    # Beitrag erstellt.
    $l->route("$start/edit/:postid", postid => $Ffc::Digqr)->via('get')
      ->to(controller => $cname, action => 'edit_form')->name("edit_${cname}_form");
    
    # Diese Route löscht einen Beitrag mit all seinen Anhängen und allem.
    $l->route("$start/delete")->via('post')
      ->to(controller => $cname, action => 'delete_do')->name("delete_${cname}_do");
    # Diese Route erzeugt ein Bestätigungsformular, was den Benutzer
    # fragt, ob er den gewünschten Beitrag tatsächlich und unwiderbringlich
    # löschen möchte.
    $l->route("$start/delete/:postid", postid => $Ffc::Digqr)->via('get')
      ->to(controller => $cname, action => 'delete_check')->name("delete_${cname}_check");

    # Folgende Route lädt Dateien zu einem Beitrag hoch.
    $l->route("$start/upload")->via('post')
      ->to(controller => $cname, action => 'upload_do')->name("upload_${cname}_do");
    # Diese Route dient dem Upload von Anhängen an einen Beitrag
    # und liefert dafür das entsprechende Upload-Formular.
    $l->route("$start/upload/:postid", postid => $Ffc::Digqr)->via('get')
      ->to(controller => $cname, action => 'upload_form')->name("upload_${cname}_form");

    # Die folgende Route erlaubt den Download von Dateien, die
    # an einen Beitrag angehängt wurden.
    $l->route("$start/download/:fileid", fileid => $Ffc::Digqr)->via('get')
      ->to(controller => $cname, action => 'download')->name("download_att_${cname}");

    # Die Route löscht einen Anhang, der an einem Beitrag hängt.
    $l->route("$start/upload/delete")->via('post')
      ->to(controller => $cname, action => 'delete_upload_do')->name("delete_upload_${cname}_do");
    # Diese Route erzeugt ein Bestätigungsformular, wenn der Benutzer
    # einen Dateianhang löschen möchte, in dem er nochmal gefragt wird, 
    # ob er das auch tatsächlich machen will.
    $l->route("$start/upload/delete/:postid/:fileid", postid => $Ffc::Digqr, fileid => $Ffc::Digqr)->via('get')
      ->to(controller => $cname, action => 'delete_upload_check')->name("delete_upload_${cname}_check");
}

1;

