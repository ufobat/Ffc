package Ffc::Avatars;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';
use File::Spec::Functions qw(catfile);
use Mojo::Util 'quote';
use Encode qw( encode decode_utf8 );
use Ffc::Options;

sub avatar_show {
    my $c = shift;
    my $u = $c->param('username');
    my ( $filename, $filetype );
    my $file = $c->dbh->selectall_arrayref(
        'SELECT avatar FROM users WHERE UPPER(name)=UPPER(?)'
        , undef, $u);
    if ( $file and 'ARRAY' eq ref($file) and $file = $file->[0]->[0] ) {
        $filename = quote encode 'UTF-8', $file;
        $filetype = $file =~ m/\.(png|jpe?g|bmp|gif)\z/xmiso ? lc($1) : '*';
        $file = catfile @{$c->datapath}, 'avatars', $file;
    }
    else {
        $file = '';
    }
    return $c->render_static(catfile('theme', 'img', 'smileys', 'smile.png'))
        unless $file and -e $file;

    $file = Mojo::Asset::File->new(path => $file);
    my $headers = Mojo::Headers->new();
    $headers->add( 'Content-Type', 'image/'.$filetype );
    $headers->add( 'Content-Disposition', 'inline;filename=' . $filename );
    $headers->add( 'Content-Length' => $file->size );
    $c->res->content->headers($headers);
    $c->res->content->asset($file);
    $c->rendered(200);
}

sub options_form { &Ffc::Options::options_form }

sub avatar_upload {
    my $c = shift;
    my $u = $c->session->{user};
    my $file = $c->param('avatarfile');
    
    unless ( $file ) {
        $c->set_error('Kein Avatarbild angegeben.');
        return $c->options_form;
    }
    unless ( $file->isa('Mojo::Upload') ) {
        $c->set_error('Keine Datei als Avatarbild angegeben.');
        return $c->options_form;
    }
    if ( $file->size < 1000 ) {
        $c->set_error('Datei ist zu klein, sollte mindestens 1Kb groß sein.');
        return $c->options_form;
    }
    if ( $file->size > 150000 ) {
        $c->set_error('Datei ist zu groß, darf maximal 150Kb groß sein.');
        return $c->options_form;
    }

    my $filename = $file->filename ne 'avatarfile' ? $u . '_' . $file->filename : '';

    unless ( $filename ) {
        $c->set_error('Dateiname fehlt.');
        return $c->options_form;
    }
    if ( (length($u) + 8) > length $filename ) {
        $c->set_error('Dateiname ist zu kurz, muss mindestens 6 Zeichen inklusive Dateiendung enthalten.');
        return $c->options_form;
    }
    if ( 80 < length $filename ) {
        $c->set_error('Dateiname ist zu lang, darf maximal 80 Zeichen lang sein.');
        return $c->options_form;
    }
    if ( $file->filename =~ m/\A\./xms ) {
        $c->set_error('Dateiname darf nicht mit einem "." beginnen.');
        return $c->options_form;
    }
    if ( $filename !~ m/\.(?:png|jpe?g|bmp|gif)\z/ximso ) {
        $c->set_error('Datei ist keine Bilddatei, muss PNG, JPG, BMP oder GIF sein.');
        return $c->options_form;
    }
    if ( $filename =~ m/(?:\.\.|\/)/xmso ) {
        $c->set_error('Dateiname darf weder ".." noch "/" enthalten.');
        return $c->options_form;
    }
    unless ( $file->move_to(catfile(@{$c->datapath}, 'avatars', $filename)) ) {
        $c->set_error('Dateiupload für das Avatarbild fehlgeschlagen.');
        return $c->options_form;
    }
    my $old = $c->dbh->selectall_arrayref(
        'SELECT avatar FROM users WHERE UPPER(name)=UPPER(?)'
        , undef, $u);
    if ( $old and 'ARRAY' eq ref($old) and $old->[0]->[0] ) {
        $old = catfile(@{$c->datapath}, 'avatars', $old->[0]->[0] );
        unlink $old if -e $old;
    }
    $c->dbh->do('UPDATE users SET avatar=? WHERE UPPER(name)=UPPER(?)'
        , undef, $filename, $u);
    $c->set_info('Avatarbild aktualisiert.');
    $c->options_form;
}

1;

