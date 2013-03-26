package Mock::Controller;
use strict;
use warnings;
use utf8;
use 5.010;
use Mock::Controller::App;
use Mojo::Base 'Mojolicious::Controller';

sub new {
    bless { url => '', session => {}, stash => {}, app => Mock::Controller::App->new() },
      shift;
}
sub url_for { shift->{url} . shift }
sub session { shift->{session} }
sub app     { shift->{app} }

sub stash {
    my $stash = shift->{stash};
    my $key   = shift;
    my $value = shift;
    if ( $key and not defined $value ) {
        $stash->{$key} = undef unless exists $stash->{$key};
        return $stash->{$key};

    }
    return $stash->{$key} = $value if $key and $value;
    return;
}

1;

