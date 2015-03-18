package Ffc::Customstyle;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';
use File::Spec::Functions qw(catfile);
use Mojo::Util 'quote';
use Encode qw( encode decode_utf8 );

sub install_routes {
    # Obacht! Alle Routen hier drin funktionieren ohne Anmeldung, also keinen Scheiß hier bauen!
    $_[0]->route("/favicon/show")
      ->via('get')
      ->to(controller => 'customstyle', action => 'favicon_show')
      ->name("favicon_show")
}

sub favicon_show {
    my $c = shift;
    my $config = $c->configdata;
    my $contenttype = $config->{faviconcontenttype};
    my $filetype = $config->{favicontype};
    my $file = $config->{favicon};
    unless ( $file ) {
        $file = $config->{favicon} = catfile @{$c->datapath}, 'favicon';
    }
    $file = Mojo::Asset::File->new(path => $file);
    my $headers = Mojo::Headers->new();
    $headers->add( 'Content-Type', $contenttype );
    $headers->add( 'Content-Disposition', qq~inline;filename=favicon.$filetype~ );
    $headers->add( 'Content-Length' => $file->size );
    $c->res->content->headers($headers);
    $c->res->content->asset($file);
    $c->rendered(200);
}

sub favicon_upload {
    my $c = shift;
    my ( $filename, $filetype, $contenttype ) 
        = $c->file_upload(
            'faviconfile', 'Favoriten-Icon', 100, 50000, 8, 80, 
            sub { 
                unless ( $_[0]->is_image($_[3]) ) {
                    $_[0]->set_error_f('Datei ist keine Bilddatei, muss PNG, JPG, BMP, ICO oder GIF sein.');
                    return;
                }
                return [ 'favicon' ];
            }
        );
    return $c->redirect_to('options_form')
        unless $filename;


    my $favicon = catfile @{$c->datapath}, 'favicon';
    $c->dbh_do('UPDATE config SET value=? WHERE key=?', $filetype, 'favicontype');
    $c->dbh_do('UPDATE config SET value=? WHERE key=?', $contenttype, 'faviconcontenttype');
    $c->dbh_do('UPDATE config SET value=? WHERE key=?', $favicon, 'favicon');
    my $config = $c->configdata;
    $config->{favicontype} = $filetype;
    $config->{faviconcontenttype} = $contenttype;
    $config->{favicon} = $favicon;
    $c->set_info_f('Favoriten-Icon aktualisiert.');
    $c->redirect_to('options_form');
}

1;

