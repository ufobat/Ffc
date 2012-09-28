package AltSimpleBoard::Board;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use AltSimpleBoard::Data::Board;
use AltSimpleBoard::Auth;

sub frontpage {
    my $c = shift;
    my $s = $c->session;
    my $page = $c->param('page') // 1;
    $c->stash(page => $page);
    my $id   = $c->param('id') // 1;
    my @params = ( $s->{userid}, $page, $s->{lastseen}, $s->{query}, $id );
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
    $c->redirect_to( 'frontpage', act => $c->param('act') );
}

sub startpage {
    my $c = shift;
    if ( AltSimpleBoard::Auth::check_login_status($c) ) {
        $c->redirect_to('frontpage', act => 'forum');
    }
    else {
        $c->stash( act => 'auth' );
        $c->render( 'auth/login_form', error => 'Bitte melden Sie sich an' );
    }
}

sub init {
# prepare the user action
    return 1;
}

1;

