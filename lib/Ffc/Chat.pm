package Ffc::Chat;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util 'quote';
use Encode qw( encode decode_utf8 );

sub install_routes {
    # die route erzeugt lediglich das chatfenster
    $_[0]->route('/chat')->via('get')
         ->to(controller => 'chat', action => 'chat_window')
         ->name('chat_window');

    # die route ist für nachrichten genauso wie für statusabfragen zuständig
    $_[0]->route('/chat/recieve')->via('any')
         ->to(controller => 'chat', action => 'recieve')
         ->name('chat_recieve');
}

sub chat_window { $_[0]->render( template => 'chat' ) }

sub recieve {
    my $c = $_[0];
    my $msg = $c->param('msg');
    if ( $msg ) { # neue nachricht erhalten
        warn 'nachricht erhalten';
    } # ende neue nachricht erhalten

    # rückgabe erzeugen
    my $ret = [];
    $c->render( json => $ret );
}

1;

