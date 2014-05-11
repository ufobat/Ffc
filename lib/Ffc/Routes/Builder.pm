package Ffc::Routes::Builder;
use strict; use warnings; use utf8;

our @Keys = qw(act page category msgs_username postid number);

sub install_routebuilder {
    my $app = shift;
    $app->helper( url_for_me => sub {
        my $c = shift;
        my $path = shift;
        my %params = @_;
        %params = map { $_ => exists($params{$_}) ? $params{$_} // $c->stash($_) : $c->stash($_) } @Keys;
        $params{act} = 'forum' unless $params{act};
        $c->url_for( $path );
    });
}

1;

