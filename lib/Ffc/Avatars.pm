package Ffc::Avatars;
use 5.18.0;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';
use File::Spec::Functions 'catfile';
use Mojo::Util 'quote';
use Encode 'encode';

my $DefaultAvatar;

###############################################################################
# Routen für das Avatar-Management einrichten
sub install_routes {
    my $p = $_[0]->under('/avatar')->name('avatars_bridge');
    # Avatar anzeigen
    $p->route('/:userid', userid => $Ffc::Digqr)
      ->via('get')
      ->to('avatars#avatar_show')
      ->name('avatar_show');
    # Avatar hochladen
    $p->route('/upload')
      ->via('post')
      ->to('avatars#avatar_upload')
      ->name('avatar_upload');
}

###############################################################################
# Einen Benutzeravatar anzeigen (inkl. Fallback)
sub avatar_show {
    my $c = $_[0];
    my ( $filename, $filetype );
    # Avatar-Bild für den gewünschten Benutzer aus der Datenbank auslesen
    my $file = $c->dbh_selectall_arrayref(
        'SELECT avatar, avatartype FROM users WHERE id=?'
        , $c->param('userid'));
    # Falls ein Avatarbild angegeben ist, die entsprechende Datei aus dem Dateisystem ermitteln
    if ( @$file and ($filename = $file->[0]->[0]) ) {
        $filetype = $file->[0]->[1] || ( $filename =~ qr~\.(png|jpe?g|bmp|gif)\z~xmiso ? lc($1) : '*' );
        $file = catfile @{$c->datapath}, 'avatars', $filename; # Realer Dateipfad im Dateisystem
        # Zusatzinformationen zum Avatarbild
        $filename = quote encode 'UTF-8', $filename;
    }
    #
    # Gibt es die reale Datei nicht, wird ebenfalls auf den Default-Avatar gewechselt
    return $c->reply->static(
        $DefaultAvatar || ( $DefaultAvatar = catfile 'theme', 'img', 'avatar.png' ) ) 
            unless $filename and -e $file;

    # Dateiauslieferung über Mojolicious-Mechanismen
    $file = Mojo::Asset::File->new(path => $file);
    my $headers = Mojo::Headers->new();
    $headers->add( 'Content-Type', 'image/'.$filetype );
    $headers->add( 'Content-Disposition', qq~inline;filename=$filename~ );
    $headers->add( 'Content-Length' => $file->size );
    $c->res->content->headers($headers);
    $c->res->content->asset($file);
    $c->rendered(200);
}

###############################################################################
# Der Benutzer lädt für sich ein Avatarbild hoch
sub avatar_upload {
    my $c = $_[0];
    my $u = $c->session->{user};
    
    # Datei-Upload-Helper
    my ( $filename, $filetype ) = $c->file_upload(
        'avatarfile', 1, 'Avatarbild', 100, 1, 8, 80, 
        sub { 
            # Optionaler Spezial-Check für den Upload
            unless ( $_[0]->is_image($_[3]) ) {
                $_[0]->set_error_f('Datei ist keine Bilddatei, muss PNG, JPG, BMP, ICO oder GIF sein.');
                return;
            }
            return [ 'avatars', $u . '_' . $_[1] ];
        },
    );

    # Der Upload hat nicht funktioniert
    return $c->redirect_to('options_form')
        unless $filename;

    # Ein eventuell altes Avatarbild aus dem Dateisystem entfernen
    my $old = $c->dbh_selectall_arrayref(
        'SELECT avatar FROM users WHERE UPPER(name)=UPPER(?)', $u);
    if ( @$old and $old->[0]->[0] ne $filename ) {
        $old = catfile(@{$c->datapath}, 'avatars', $old->[0]->[0] );
        unlink $old if -e $old;
    }

    # Neues Avatarbild in die Datenbank eintragen
    $c->dbh_do('UPDATE users SET avatar=?, avatartype=? WHERE UPPER(name)=UPPER(?)'
        , $filename, $filetype, $u);

    # Avatarbild-Update erledigt
    $c->set_info_f('Avatarbild aktualisiert.');
    $c->redirect_to('options_form');
}

1;
