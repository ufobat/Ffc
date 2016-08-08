package Ffc;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious';
use File::Spec::Functions qw(catdir);

use Ffc::Customstyle;
use Ffc::Options;
use Ffc::Auth;
use Ffc::Avatars;
use Ffc::Forum;
use Ffc::Pmsgs;
use Ffc::Notes;
use Ffc::Chat;
use Ffc::Quickview;

our $Digqr = qr/\d+/xmso;
our $Usrqr = qr(\w{2,32})xmso;
our $Dater = qr~\A\s*(?:
    (?<tag>\d\d?)\s*[-./]\s*(?<monat>\d\d?)\s*[-./]\s*(?<jahr>(?:\d\d)?\d\d)?
    |
    (?<jahr>(?:\d\d)?\d\d)\s*[-/]\s*(?<monat>\d\d?)\s*[-/]\s*(?<tag>\d\d?)
)\s*\z~xmso;
our $Optky;

# This method will run once at server start
sub startup {
    my $app = shift;
    $app->plugin('Ffc::Plugin::Config');
    $app->plugin('Ffc::Plugin::Formats');
    $app->plugin('Ffc::Plugin::Uploads');
    $app->plugin('Ffc::Plugin::Posts');
    $app->helper(login_ok => sub { $_[0]->session->{user} ? 1 : 0 });
    $app->hook('before_dispatch' => sub {
        my $self = shift;
        if ($self->req->headers->header('X-Forwarded-Host')) {
            my $path = shift @{$self->req->url->path->parts};
            push @{$self->req->url->base->path->parts}, $path;
        }
    });
    _install_routes($app);
}

sub _install_routes {
    my $l = Ffc::Auth::install_routes($_[0]->routes);
    Ffc::Customstyle::install_routes($l);
    Ffc::Avatars::install_routes($l);
    Ffc::Options::install_routes($l);
    Ffc::Forum::install_routes($l);
    Ffc::Pmsgs::install_routes($l);
    Ffc::Notes::install_routes($l);
    Ffc::Chat::install_routes($l);
    Ffc::Quickview::install_routes($l);
    _install_routes_helper($l);
}

sub _install_routes_helper {
    my $l = $_[0];
    # Standardseitenauslieferungen
    $l->any('/')->to(controller => 'forum', action => 'show_startuppage')
      ->name('show');
    $l->any('/help' => sub { $_[0]->stash( controller => 'help' )->render(template => 'help') } )
      ->name('help');
    $l->get('/session' => sub { $_[0]->render( json => $_[0]->session() ) } )
      ->name('sessiondata');
    $l->get('/config' => sub { $_[0]->render( json => $_[0]->configdata() ) } )
      ->name('configdata');
    $l->get('/counts' => sub { $_[0]->render( text => $_[0]->newpostcount() + $_[0]->newmsgscount() ) } )
      ->name('countings');
    $l->post('/textpreview' => sub { $_[0]->render( json => $_[0]->pre_format($_[0]->req->json || '') ) } )
      ->name('textpreview');
    $l->post('/menu' => sub { 
            my $j = $_[0]->req->json;
            $_[0]->counting
                 ->stash(pageurl    => $j ? $j->{pageurl}    : '')
                 ->stash(queryurl   => $j ? $j->{queryurl}   : '')
                 ->stash(controller => $j ? $j->{controller} : '')
                 ->render('layouts/parts/menu');
    } )->name('menu');
}

1;
