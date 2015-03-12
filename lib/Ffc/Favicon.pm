package Ffc::Favicon;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';
use File::Spec::Functions qw(catfile);
use Mojo::Util 'quote';
use Encode qw( encode decode_utf8 );

sub install_routes {
    # Obacht! Alle Routen hier drin funktionieren ohne Anmeldung, also keinen Scheiß hier bauen!
    $_[0]->route('/favicon/show')
      ->via('get')
      ->to('favicon#favicon_show')
      ->name('favicon_show');
}

sub favicon_show {
    my $c = shift;
    my $filetype = $c->dbh->selectall_arrayref(
        'SELECT "value" FROM "config" WHERE "key"=? or "key"=? ORDER BY "key" DESC',
        undef, 'favicontype', 'faviconcontenttype');
    my $contenttype = $filetype->[1]->[0];
    $filetype = $filetype->[0]->[0];
    my $file = catfile @{$c->datapath}, 'favicon';
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

    $c->dbh->do('UPDATE config SET value=? WHERE key=?', undef, $filetype, 'favicontype');
    $c->dbh->do('UPDATE config SET value=? WHERE key=?', undef, $contenttype, 'faviconcontenttype');
    $c->set_info_f('Favoriten-Icon aktualisiert.');
    $c->redirect_to('options_form');
}

1;

