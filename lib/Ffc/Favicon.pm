package Ffc::Favicon;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';
use File::Spec::Functions qw(catfile);
use Mojo::Util 'quote';
use Encode qw( encode decode_utf8 );

sub install_routes {
    my $p = $_[0]->bridge('/favicon')->name('favicons_bridge');
    $p->route('/show')
      ->via('get')
      ->to('favicon#favicon_show')
      ->name('favicon_show');
    $p->route('/upload')
      ->via('post')
      ->to('favicon#favicon_upload')
      ->name('favicon_upload');
}

sub favicon_show {
    my $c = shift;
    my $filetype = $c->dbh->selectall_arrayref(
        'SELECT "value" FROM "config" WHERE "key"=?', undef, 'favicontype')->[0]->[0];
    my $file = catfile @{$c->datapath}, 'favicon';
    $file = Mojo::Asset::File->new(path => $file);
    my $headers = Mojo::Headers->new();
    $headers->add( 'Content-Type', 'image/'.$filetype );
    $headers->add( 'Content-Disposition', qq~inline;filename=favicon.$filetype~ );
    $headers->add( 'Content-Length' => $file->size );
    $c->res->content->headers($headers);
    $c->res->content->asset($file);
    $c->rendered(200);
}

1;

