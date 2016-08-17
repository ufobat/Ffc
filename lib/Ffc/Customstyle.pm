package Ffc::Customstyle;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';
use File::Spec::Functions qw(catfile);
use Mojo::Util 'quote';
use Encode qw( encode decode_utf8 );

###############################################################################
# Routen für das Favoriten-Icon-Handling
# (auch das wird nur nach der Anmeldung frei geschalten)
sub install_routes {
    # Route zum Anzeigen des Favoriten-Icons 
    $_[0]->route("/favicon/show")
      ->via('get')
      ->to(controller => 'customstyle', action => 'favicon_show')
      ->name("favicon_show")
    # Die Route für das Hochladen eines Icons ist in die Admin-Optionen integriert
}

###############################################################################
sub favicon_show {
    my $c = $_[0];
    # Globale Konfiguration für das Favicon ermitteln
    my $config = $c->configdata;
    my $file = $config->{favicon};
    unless ( $file ) {
        # Fallback auf das Standard-Icon
        $file = $config->{favicon} = catfile @{$c->datapath}, 'favicon';
    }

    # Dateiauslieferung über Mojolicious-Mechanismen
    $file = Mojo::Asset::File->new(path => $file);
    my $headers = Mojo::Headers->new();
    $headers->add( 'Content-Type', $config->{faviconcontenttype} );
    $headers->add( 'Content-Disposition', qq~inline;filename=favicon.~ . $config->{favicontype});
    $headers->add( 'Content-Length' => $file->size );
    $c->res->content->headers($headers);
    $c->res->content->asset($file);
    $c->rendered(200);
}

###############################################################################
# Ein neues Favoriten-Icon für das Forum einrichten
sub favicon_upload {
    my $c = $_[0];

    # Dateiupload-Helper
    my ( $filename, $filetype, $contenttype ) = $c->file_upload(
        'faviconfile', 1, 'Favoriten-Icon', 100, 0.25, 8, 80, 
        sub { 
            unless ( $_[0]->is_image($_[3]) ) {
                $_[0]->set_error_f('Datei ist keine Bilddatei, muss PNG, JPG, BMP, ICO oder GIF sein.');
                return;
            }
            return [ 'favicon' ];
        },
    );
    # Der Upload hat nicht funktioniert
    return $c->redirect_to('admin_options_form')
        unless $filename;


    # Aktualisierung der globalen Foreneinstellung mit dem neuen Favicon in der Datenbank
    my $favicon = catfile @{$c->datapath}, 'favicon';
    $c->dbh_do('UPDATE config SET value=? WHERE key=?', $filetype, 'favicontype');
    $c->dbh_do('UPDATE config SET value=? WHERE key=?', $contenttype, 'faviconcontenttype');
    $c->dbh_do('UPDATE config SET value=? WHERE key=?', $favicon, 'favicon');

    # Konfiguration der aktuell laufenden Foreninstanz mit dem neuen Favicon aktualisieren
    @{$c->configdata}{qw(favicontype faviconcontenttype favicon)} 
        = ($filetype, $contenttype, $favicon);

    # Favicon fertig
    $c->set_info_f('Favoriten-Icon aktualisiert.');
    $c->redirect_to('admin_options_form');
}

1;
