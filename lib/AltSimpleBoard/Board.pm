package AltSimpleBoard::Board;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use AltSimpleBoard::Data::Board;
use AltSimpleBoard::Auth;

sub frontpage {
    my $c = shift;
    $c->stash( posts => AltSimpleBoard::Data::Board::get_posts($c->session->{userid}, $c->param('page')) );
}

sub startpage {
    my $c = shift;
    if ( AltSimpleBoard::Auth::check_login_status($c) ) {
        $c->redirect_to('frontpage');
    }
    else {
        $c->render( 'auth/login_form', error => 'Bitte melden Sie sich an' );
    }
}

1;

