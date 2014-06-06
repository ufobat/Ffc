package Ffc;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious';
use File::Spec::Functions qw(catdir);

our $Digqr = qr/\d+/xmso;
our $Usrqr = qr(\w{2,32})xmso;
our $Catqr = qr(.{1,64})xmso;
our $Fszqr = qr(-?\d{1,3})xmso;

our $Optky 
    = qr(title|postlimit|sessiontimeout|commoncattitle|urlshorten|backgroundcolor|fixbackgroundcolor|favicon|topiclimit)xmso;

# This method will run once at server start
sub startup {
    my $app = shift;
    $app->plugin('Ffc::Plugin::Config');
    $app->plugin('Ffc::Plugin::Formats');
    $app->plugin('Ffc::Plugin::Posts');
    $app->helper(login_ok => sub { $_[0]->session->{user} ? 1 : 0 });
    _install_routes($app->routes);
}

sub _install_routes {
    my $l = Ffc::Auth::install_routes($_[0]);
    use Ffc::Options;
    use Ffc::Auth;
    use Ffc::Avatars;
    use Ffc::Forum;
    use Ffc::Pmsgs;
    use Ffc::Notes;
    Ffc::Avatars::install_routes($l);
    Ffc::Options::install_routes($l);
    Ffc::Forum::install_routes($l);
    Ffc::Pmsgs::install_routes($l);
    Ffc::Notes::install_routes($l);
    _install_routes_helper($l);
}

sub _install_routes_helper {
    my $l = $_[0];
    # Standardseitenauslieferungen
    $l->any('/')->to('forum#show')->name('show');
    $l->any('/help' => sub { $_[0]->render(template => 'help') } )
      ->name('help');
    $l->get('/session' => sub { $_[0]->render( json => $_[0]->session() ) } )
      ->name('sessiondata');
    $l->get('/config' => sub { $_[0]->render( json => $_[0]->configdata() ) } )
      ->name('configdata');
}

1;
