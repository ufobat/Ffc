package Mock::Controller;
use strict;
use warnings;
use utf8;
use 5.010;
use Mock::Controller::App;
use Mojo::Base 'Mojolicious::Controller';

sub new {
    bless { url => '', session => {}, stash => {}, flash => {}, app => Mock::Controller::App->new() },
      shift;
}
sub url_for { shift->{url} . shift }
sub session { shift->{session} }
sub app     { shift->{app} }

sub stash { shift->_stash('stash', @_) }
sub flash { shift->_stash('flash', @_) }
sub _stash {
    my $c = shift;
    my $skey = shift;
    my $stash = $c->{$skey};
    my $key   = shift;
    my $value = shift;
    if ( $key and not defined $value ) {
        $stash->{$key} = undef unless exists $stash->{$key};
        return $stash->{$key};

    }
    return $stash->{$key} = $value if $key and defined $value;
    return;
}

1;

