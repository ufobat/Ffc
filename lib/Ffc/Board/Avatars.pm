package Ffc::Board; # Avatars
use strict; use warnings; use utf8;

sub avatar_show {
    my $c = shift;
    my $u = $c->param('user');
}

sub avatar_upload {
    my $c = shift;
    my $u = $c->session->{user};
}

1;

