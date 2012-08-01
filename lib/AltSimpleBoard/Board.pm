package AltSimpleBoard::Board;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use AltSimpleBoard::Data::Board;

sub frontpage {
    my $c = shift;
    $c->stash( posts => AltSimpleBoard::Data::Board::get_posts() );
}

sub avatar {
    my $self = shift;
    my $img = $self->param('src');
    if ( $img =~ m[(\d+)_\w+\.(jpg|jpeg|png|bmp|gif)]xmsi ) {
        $img = "$1.$2";
    }
    $img = "${AltSimpleBoard::Data::PhpBBPath}images/avatars/upload/${AltSimpleBoard::Data::AvatarSalt}_$img";
    $self->render_static($img);
}

1;

