package Ffc;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious';
use File::Spec::Functions qw(catdir);
use Ffc::Routes;

our $Digqr = qr/\d+/xmso;
our $Usrqr = qr(\w{2,32})xmso;
our $Catqr = qr(\w{1,64})xmso;
our $Bgcqr = qr(\w{3,32})xmso;
our $Fszqr = qr(-?\d{1,3})xmso;

# This method will run once at server start
sub startup {
    my $app = shift;
    $app->plugin('Ffc::Plugin::Config');
    $app->plugin('Ffc::Plugin::Formats');
    $app->helper(login_ok => sub { $_[0]->session->{user} ? 1 : 0 });
    Ffc::Routes::install_routes($app->routes);
}

1;
