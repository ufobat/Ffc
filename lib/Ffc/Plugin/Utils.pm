package Ffc::Plugin::Utils;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Plugin';

use strict;
use warnings;
use 5.010;

sub register {
    my ( $self, $app ) = @_;
    $app->helper(pagination => sub { &_pagination });
    return $self;
}

sub _pagination {
    my $c = shift;
    my $page = $c->param('page') // 1;
    my $postlimit = $c->configdata->{postlimit};
    $c->stash(page => $page);
    return $postlimit, ( $page - 1 ) * $postlimit;
}

1;

