package Ffc::Plugin::Uploads;
use 5.010;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Plugin';
use Mojolicious::Types;
use File::Spec::Functions qw(catfile);

our $Types = Mojolicious::Types->new()->types;

sub register {
    my ( $self, $app ) = @_;
    $app->helper( file_upload => \&_file_upload );
    $app->helper( is_image    => \&_is_image    );
    $app->helper( is_inline   => \&_is_inline   );
    return $self;
}

sub _is_inline {
    return 1 if $_[1] =~ m/\A(?:image|video|audio)/xmsio;
    return;
}

sub _is_image {
    return 1 if $_[1] =~ m/\Aimage/xmsio;
    return;
}

sub _file_upload {
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
    if ( $filename =~ m/(?:\.\.|\/)/xmso ) {
        $c->set_error_f('Dateiname darf weder ".." noch "/" enthalten.');
        return;
    }

    my $filetype = $filename =~ m/\.(\w+)\z/ximso ? $1 : '';
    my $content_type = $filetype 
        ? ( exists $Types->{$filetype} ? $Types->{$filetype}->[0] : "*/$filetype" )
        : '*/*';

    my $path = $filenamesub->($c, $filename, $filetype, $content_type);
    return unless $path;

    unless ( $file->move_to(catfile(@{$c->datapath}, @$path)) ) {
        $c->set_error_f("Dateiupload für das $name fehlgeschlagen.");
        return;
    }

    return $path->[-1], $filetype, $content_type;
}

1;
