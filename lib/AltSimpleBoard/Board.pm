package AltSimpleBoard::Board;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use AltSimpleBoard::Data::Board;
use AltSimpleBoard::Auth;

sub frontpage {
    my $c = shift;
    my $s = $c->session;
    my @params = ( $s->{userid}, $c->param('page'), $s->{lastseen}, $s->{query} );
    my $posts = [];
    given ( $c->param('act') ) {
        when ( 'forum' ) { $posts = AltSimpleBoard::Data::Board::get_forum(@params) }
        when ( 'notes' ) { $posts = AltSimpleBoard::Data::Board::get_notes(@params) }
        when ( 'msgs' )  { $posts = AltSimpleBoard::Data::Board::get_msgs( @params) }
    }
    $c->stash( posts => $posts);
}

sub search {
    my $c = shift;
    $c->session->{query} = $c->param('query') || '';
    $c->redirect_to( 'frontpage', page => 1 );
}

sub startpage {
    my $c = shift;
    if ( AltSimpleBoard::Auth::check_login_status($c) ) {
        $c->redirect_to('act', act => 'forum');
    }
    else {
        $c->render( 'auth/login_form', error => 'Bitte melden Sie sich an' );
    }
}

1;

