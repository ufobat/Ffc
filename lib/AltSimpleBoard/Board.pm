package AltSimpleBoard::Board;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use AltSimpleBoard::Data::Board;
use AltSimpleBoard::Auth;

sub frontpage {
    my $c = shift;
    my $s = $c->session;
    $c->stash( posts => AltSimpleBoard::Data::Board::get_posts($s->{userid}, $c->param('page'), $s->{lastseen}, $s->{query} ));
}

sub search {
    my $c = shift;
    $c->session->{query} = $c->param('query') || '';
    $c->redirect_to( 'frontpage', page => 1 );
}

sub startpage {
    my $c = shift;
    if ( AltSimpleBoard::Auth::check_login_status($c) ) {
        $c->redirect_to('frontpage', page => 1);
    }
    else {
        $c->render( 'auth/login_form', error => 'Bitte melden Sie sich an' );
    }
}

1;

