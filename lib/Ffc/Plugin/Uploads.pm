package Ffc::Plugin::Uploads;
use 5.010;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Plugin';
use Mojolicious::Types;
use File::Spec::Functions qw(catfile);

our $Types = Mojolicious::Types->new()->mapping;

sub register {
    my ( $self, $app ) = @_;
    $app->helper( file_upload => \&_file_upload );
    $app->helper( is_image    => \&_is_image    );
    $app->helper( is_inline   => \&_is_inline   );
    return $self;
}

sub _is_inline {
    $_[1] =~ m~\A(?:image|video|audio)|\*/(?:jpe?g|bmp|gif|png|mkv|avi|divx|ogg|ogv|mp3|flac|wav)\z~xmsio;
}

sub _is_image {
    $_[1] =~ m~\Aimage|\*/(?:jp[eg]|bmp|gif|png)\z~xmsio;
}

sub _file_upload {
    my @p = (@_);
    my $i = 0;
    my $files = $p[0]->every_param($p[1]);
    unless ( @$files ) {
        $p[0]->set_error_f("Kein $p[3] angegeben.");
        return;
    }
    my @rets;
    for my $file ( @$files ) {
        my @ret = _single_file_upload($file, @p);
        unless ( @ret ) {
            if ( $p[2] == 1 ) { last }
            else              { next }
        }
        push @rets, \@ret;
        $i++;
        last if $p[2] and $i >= $p[2];
    }
    if   ( not @rets            ) { return }
    if   ( $p[2] and $p[2] == 1 ) { return @{$rets[0]} }
    else                          { return @rets }
}

sub _single_file_upload {
    my ( $file, $c, $param, $fnum, $name, $min_s, $max_s, $min_l, $max_l, $filenamesub ) = @_;
    unless ( $file ) {
        $c->set_error_f("Kein $name angegeben.");
        return;
    }
    unless ( $file->isa('Mojo::Upload') ) {
        $c->set_error_f("Keine Datei als $name angegeben.");
        return;
    }
    my $filename = $file->filename;
    if ( ( !$fnum or $fnum > 1 ) and not $filename ) {
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

