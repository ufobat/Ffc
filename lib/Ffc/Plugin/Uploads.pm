package Ffc::Plugin::Uploads;
use 5.18.0;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Plugin';
use Mojolicious::Types;
use File::Spec::Functions 'catfile';

###############################################################################
# Helper-Registration für das Plugin
sub register {
    my ( $self, $app ) = @_;
    $app->helper( file_upload   => \&_file_upload   );
    $app->helper( is_image      => \&_is_image      );
    $app->helper( is_image_link => \&_is_image_link );
    $app->helper( is_inline     => \&_is_inline     );
    return $self;
}

###############################################################################
# Bestimmte Dateiendungen können als Inline dargestellt werden im HTML (Bilder und Multimedia zum Beispiel)
sub _is_inline {
    $_[1] =~ m~\A(?:image|video|audio)|\*/(?:jpe?g|bmp|gif|png|mkv|avi|divx|ogg|ogv|mp3|flac|wav)\z~xmsio;
}

###############################################################################
# Bestimmte Dateiendungen zählen als Bilder
sub _is_image {
    $_[1] =~ m~\Aimage|\*/(?:jp[eg]|bmp|gif|png)\z~xmsio;
}

###############################################################################
# Den gesammelten File-Upload durchführen
sub _file_upload {
    # $c, $param, $fnum, $name, $min_s, $max_s, $min_l, $max_l, $filenamesub, $allownofiles
    my @p = (@_);
    # Eine Liste der Upload-Parameter erzeugen (benötigt für mehrere Downloads in einem Rutsch)
    my $files = $p[0]->every_param($p[1]);
    unless ( @$files ) {
        $p[0]->set_error_f("Kein $p[3] angegeben.") unless $p[9];
        return;
    }
    my $i = 0;
    my @rets;
    # Jeweils eine Datei hochladen
    for my $file ( @$files ) {
        next unless $file;
        my @ret = _single_file_upload($file, @p);
        @ret or next;
        push @rets, \@ret;
        $p[9] = ++$i;
        $p[2] and $i >= $p[2] and last;
    }
    # Es haben keine Uploads stattgefunden
    if ( not @rets ) { return }
    # Es hat genau ein Upload stattgefunden
    if ( $p[2] and $p[2] == 1 ) { return @{$rets[0]} }
    # Alle stattgefundenen Uploads für diesen Fall
    return @rets;
}

###############################################################################
# Eine einzelne Datei hochladen über die Mojolicious-Mechanismen
sub _single_file_upload {
    my ( $file, $c, $param, $fnum, $name, $min_s, $max_s, $min_l, $max_l, $filenamesub, $allownofiles ) = @_;

    # Prüfen der Dateiparameter
    unless ( $file ) {
        $c->set_error_f("Kein $name angegeben.") unless $allownofiles;
        return;
    }
    unless ( $file->isa('Mojo::Upload') ) {
        $c->set_error_f("Keine Datei als $name angegeben.");
        return;
    }
    my $filename = $file->filename;
    if ( ( !$fnum or $fnum > 1 ) and not $filename ) {
        $c->set_error_f("Kein Name für $name übergeben.") unless $allownofiles;
        return;
    }
    if ( $file->size < $min_s ) {
        $c->set_error_f("Datei ist zu klein, sollte mindestens ${min_s}B groß sein.");
        return;
    }
    if ( $file->size > $max_s * 1024 * 1024 ) {
        $c->set_error_f("Datei ist zu groß, darf maximal ${max_s}MB groß sein.");
        return;
    }
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
    if ( $filename =~ m/(?:\.\.|\/)/xmso ) {
        $c->set_error_f('Dateiname darf weder ".." noch "/" enthalten.');
        return;
    }
    my $filetype = $filename =~ m/\.(\w+)\z/ximso ? $1 : '';

    # Content-Type-Angabe aus der Types-Liste von Mojolicious, falls vorhanden, hernehmen,
    # oder eben einen Fallback auswählen
    my $Types = Mojolicious::Types->new()->mapping;
    my $content_type = $filetype 
        ? ( exists $Types->{$filetype} ? $Types->{$filetype}->[0] : "*/$filetype" )
        : '*/*';

    # Ablagepfad über eine übergebene Funktionsreferenz ermitteln
    my $path = $filenamesub->($c, $filename, $filetype, $content_type);
    $path or return;

    # Upload durchführen und Upload-Informationen zurück liefern
    unless ( $file->move_to(catfile(@{$c->datapath}, @$path)) ) {
        $c->set_error_f("Dateiupload für das $name fehlgeschlagen.");
        return;
    }
    return $path->[-1], $filetype, $content_type;
}

1;
