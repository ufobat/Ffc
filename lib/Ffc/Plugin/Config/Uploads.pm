package Ffc::Plugin::Config;
use 5.010;
use strict; use warnings; use utf8;
use File::Spec::Functions qw(catfile);

sub _image_upload {
    my ( $c, $param, $name, $min_s, $max_s, $min_l, $max_l, $filenamesub ) = @_;

    my $file = $c->param($param);

    unless ( $file ) {
        $c->set_error_f("Kein $name angegeben.");
        return;
    }
    unless ( $file->isa('Mojo::Upload') ) {
        $c->set_error_f("Keine Datei als $name angegeben.");
        return;
    }
    if ( $file->size < $min_s ) {
        $c->set_error_f("Datei ist zu klein, sollte mindestens ${min_s}B groß sein.");
        return;
    }
    if ( $file->size > $max_s ) {
        $c->set_error_f("Datei ist zu groß, darf maximal ${max_s}B groß sein.");
        return;
    }

    my $filename = $file->filename;

    unless ( $filename and $filename ne $param ) {
        $c->set_error_f('Dateiname fehlt.');
        return;
    }
    if ( $min_l > length $filename ) {
        $c->set_error_f("Dateiname ist zu kurz, muss mindestens $min_l Zeichen inklusive Dateiendung enthalten.");
        return;
    }
    if ( $max_l < length $filename ) {
        $c->set_error_f("Dateiname ist zu lang, darf maximal $max_l Zeichen lang sein.");
        return;
    }

    if ( $filename =~ m/\A\./xms ) {
        $c->set_error_f('Dateiname darf nicht mit einem "." beginnen.');
        return;
    }
    if ( $filename !~ m/\.(png|jpe?g|bmp|gif)\z/ximso ) {
        $c->set_error_f('Datei ist keine Bilddatei, muss PNG, JPG, BMP oder GIF sein.');
        return;
    }
    my $filetype = $1;
    if ( $filename =~ m/(?:\.\.|\/)/xmso ) {
        $c->set_error_f('Dateiname darf weder ".." noch "/" enthalten.');
        return;
    }

    my $path = $filenamesub->($filename, $filetype);

    unless ( $file->move_to(catfile(@{$c->datapath}, @$path)) ) {
        $c->set_error_f("Dateiupload für das $name fehlgeschlagen.");
        return;
    }

    return $path->[-1], $filetype;
}

1;

