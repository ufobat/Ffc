package Ffc::Avatars;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';
use File::Spec::Functions qw(catfile);
use Mojo::Util 'quote';
use Encode qw( encode decode_utf8 );

our $DefaultAvatar = catfile 'theme', 'img', 'avatar.png';

sub install_routes {
    my $p = $_[0]->under('/avatar')->name('avatars_bridge');
    $p->route('/:userid', userid => $Ffc::Digqr)
      ->via('get')
      ->to('avatars#avatar_show')
      ->name('avatar_show');
    $p->route('/upload')
      ->via('post')
      ->to('avatars#avatar_upload')
      ->name('avatar_upload');
}

sub avatar_show {
    my $c = shift;
    my $u = $c->param('userid');
    my ( $filename, $filetype );
    my $file = $c->dbh_selectall_arrayref(
        'SELECT avatar, avatartype FROM users WHERE id=?'
        , $u);
    if ( @$file and ($filename = $file->[0]->[0]) ) {
        $filetype = $file->[0]->[1] || ( $filename =~ m/\.(png|jpe?g|bmp|gif)\z/xmiso ? lc($1) : '*' );
        $file = catfile @{$c->datapath}, 'avatars', $filename;
        $filename = quote encode 'UTF-8', $filename;
    }
    else {
        $file = '';
    }
    return $c->reply->static($DefaultAvatar)
        unless $file and -e $file;

    $file = Mojo::Asset::File->new(path => $file);
    my $headers = Mojo::Headers->new();
    $headers->add( 'Content-Type', 'image/'.$filetype );
    $headers->add( 'Content-Disposition', qq~inline;filename=$filename~ );
    $headers->add( 'Content-Length' => $file->size );
    $c->res->content->headers($headers);
    $c->res->content->asset($file);
    $c->rendered(200);
}

sub avatar_upload {
    my $c = shift;
    my $u = $c->session->{user};
    
    my ( $filename, $filetype ) 
        = $c->file_upload(
            'avatarfile', 1, 'Avatarbild', 100, 1, 8, 80, 
            sub { 
                unless ( $_[0]->is_image($_[3]) ) {
                    $_[0]->set_error_f('Datei ist keine Bilddatei, muss PNG, JPG, BMP, ICO oder GIF sein.');
                    return;
                }
                return [ 'avatars', $u . '_' . $_[1] ];
            }
        );
    return $c->redirect_to('options_form')
        unless $filename;

    my $old = $c->dbh_selectall_arrayref(
        'SELECT avatar FROM users WHERE UPPER(name)=UPPER(?)'
        , $u);
    if ( $old and 'ARRAY' eq ref($old) and $old->[0]->[0] and $old->[0]->[0] ne $filename ) {
        $old = catfile(@{$c->datapath}, 'avatars', $old->[0]->[0] );
        unlink $old if -e $old;
    }
    $c->dbh_do('UPDATE users SET avatar=?, avatartype=? WHERE UPPER(name)=UPPER(?)'
        , $filename, $filetype, $u);
    $c->set_info_f('Avatarbild aktualisiert.');
    $c->redirect_to('options_form');
}

1;

