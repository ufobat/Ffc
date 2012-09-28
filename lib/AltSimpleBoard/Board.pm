package AltSimpleBoard::Board;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use AltSimpleBoard::Data::Board;
use AltSimpleBoard::Auth;

sub msgsisafe {
    my $c = shift;
#FIXME save a private message
    $c->stash( act => 'msgs' );
    $c->frontpage( $c->param('userid') // '' );
}
sub msgs {
    my $c = shift;
    $c->stash( act => 'msgs' );
    $c->frontpage( $c->param('userid') // '' );
}

sub frontpage {
    my $c = shift;
    my $id = shift;
    my $s = $c->session;
    my $page = $c->param('page') // 1;
    $page = 1 unless $page =~ m/\A\d+\z/xmsi;
    $c->stash(page => $page);
    my @params = ( $s->{userid}, $page, $s->{lastseen}, $s->{query}, $id );
    my $posts = [];
    given ( $c->stash('act') ) {
        when ( 'forum' ) { $posts = AltSimpleBoard::Data::Board::get_forum(@params) }
        when ( 'notes' ) { $posts = AltSimpleBoard::Data::Board::get_notes(@params) }
        when ( 'msgs' )  { $posts = AltSimpleBoard::Data::Board::get_msgs( @params) }
    }
    $c->stash( posts => $posts);
    $c->render('board/frontpage');
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

