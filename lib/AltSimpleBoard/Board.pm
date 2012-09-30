package AltSimpleBoard::Board;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use AltSimpleBoard::Data::Board;
use AltSimpleBoard::Auth;

sub msgs_user {
    my $c = shift;
    my $s = $c->session;
    $c->app->switch_act($c, 'msgs');
    $s->{msgs_userid} = $c->param('msgs_userid');
    $s->{msgs_username} = AltSimpleBoard::Data::Board::username($s->{msgs_userid});
    $c->frontpage();
}

sub show { 
    my $c = shift;
    $c->stash( page => $c->param('page') || 1 );
    $c->frontpage();
}

sub switch {
    my $c = shift;
    my $act = $c->param('act');
    my $s = $c->session;
    $s->{msgs_userid} = '';
    $s->{msgs_username} = '';
    $c->app->switch_act($c, $act);
    $c->frontpage();
}

sub editform {
    my $c = shift;
    my $id = $c->param('postid');
    $c->stash( post => AltSimpleBoard::Data::Board::post($id) );
    $c->frontpage();
}

sub delete {
    my $c = shift;
    my $s = $c->session;
    my $id = $c->param('postid');
    AltSimpleBoard::Data::Board::delete($s->{userid}, $id);
    die "Privatnachrichten dürfen nicht gelöscht werden" if $s->{act} eq 'msgs';
    $c->redirect_to('show');
}

sub insert {
    my $c = shift;
    my $s = $c->session;
    my $text = $c->param('post') =~ m/\A\s*(.+)\s*\z/xmsi ? $1 : '';
    my $fromid = $s->{userid};
    my @params = ( $fromid, $text );
    given ( $s->{act} ) {
        when ( 'notes' ) { push @params, $fromid }
        when ( 'msgs'  ) { push @params, $s->{msgs_userid} }
    }
    # from, text, to
    AltSimpleBoard::Data::Board::insert(@params) if $text;
    $c->redirect_to('show');
}

sub update {
    my $c = shift;
    my $s = $c->session;
    my $text = $c->param('post') =~ m/\A\s*(.+)\s*\z/xmsi ? $1 : '';
    my $postid = $c->param('postid');
    my $fromid = $s->{userid};
    my @params = ( $fromid, $text, $postid );
    given ( $s->{act} ) {
        when ( 'notes' ) { push @params, $fromid }
        when ( 'msgs'  ) { die 'Privatnachrichten dürfen nicht geändert werden' }
    }
    # from, text, id, to
    AltSimpleBoard::Data::Board::update(@params) if $text;
    $c->redirect_to('show');
}

sub frontpage {
    my $c = shift;
    my $s = $c->session;

    my $page = $c->param('page') // 1;
    $page = 1 unless $page =~ m/\A\d+\z/xmsi;
    $c->stash(page => $page);
    
    for my $k ( qw(post error msgs_userid msgs_username postid) ) {
        my $d = $c->stash($k);
        $c->stash($k => '') unless $d;
    }
    my @params = ( $s->{userid}, $page, $s->{lastseen}, $s->{query} );
    my $posts = [];
    given ( $s->{act} ) {
        when ( 'forum' ) { $posts = AltSimpleBoard::Data::Board::get_forum(@params) }
        when ( 'notes' ) { $posts = AltSimpleBoard::Data::Board::get_notes(@params) }
        when ( 'msgs' )  { $posts = AltSimpleBoard::Data::Board::get_msgs( @params, $s->{msgs_userid}) }
        default { die qq("$s->{act}" undefined) }
    }
    $c->stash( posts => $posts);
    $c->render('board/frontpage');
}

sub search {
    my $c = shift;
    $c->session->{query} = $c->param('query') || '';
    $c->frontpage();
}

sub startpage {
    my $c = shift;
    if ( AltSimpleBoard::Auth::check_login_status($c) ) {
        $c->show();
    }
    else {
        $c->app->switch_act( $c, 'auth' );
        $c->stash( $_ => '' ) for qw(notecount newmsgscount);
        $c->render( 'auth/login_form', error => 'Bitte melden Sie sich an' );
    }
}

sub init {
    my $c = shift;
    my $userid = $c->session->{userid};
# prepare the user action
    AltSimpleBoard::Data::Board::update_user_stats($userid);
    $c->stash(notecount => AltSimpleBoard::Data::Board::notecount($userid));
    $c->stash(newmsgscount => AltSimpleBoard::Data::Board::newmsgscount($userid));
    return 1;
}

1;

