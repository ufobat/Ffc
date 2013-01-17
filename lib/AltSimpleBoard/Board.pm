package AltSimpleBoard::Board;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use AltSimpleBoard::Data::Board;
use AltSimpleBoard::Auth;

sub optionsform {
    my $c = shift;
    my $s = $c->session;
    $c->app->switch_act( $c, 'options' );
    $s->{msgs_userid} = '';
    $s->{msgs_username} = '';
}

sub optionssave {
    my $c = shift;
    my $s = $c->session;
}

sub usersave {
    my $c = shift;
    my $s = $c->session;
}

sub switch_category {
    my $c = shift;
    my $s = $c->session;
    $c->app->switch_act($c, 'forum');
    $s->{category} = $c->param('categoryid');
    $c->frontpage();
}

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
    my ( $text, $cat ) = AltSimpleBoard::Data::Board::post($id);
    $c->stash( post => $text );
    $c->session->{category} = $cat;
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
    my $text = $c->param('post')     =~ m/\A\s*(.+)\s*\z/xmsi ? $1 : '';
    my $cat  = $c->param('category') =~ m/\A(\d+)\z/xmsi      ? $1 : undef;
    my $fromid = $s->{userid};
    my @params = ( $fromid, $text, $cat );
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
    my $text = $c->param('post')     =~ m/\A\s*(.+)\s*\z/xmsi ? $1 : '';
    my $cat  = $c->param('category') =~ m/\A(\d+)\z/xmsi      ? $1 : undef;
    my $postid = $c->param('postid');
    my $fromid = $s->{userid};
    my @params = ( $fromid, $text, $cat, $postid );
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
    
    for my $k ( qw(post error msgs_userid msgs_username postid notecount newmsgscount) ) {
        my $d = $c->stash($k);
        $c->stash($k => '') unless $d;
    }
    my @params = ( $s->{userid}, $page, $s->{lastseen}, $s->{query}, $s->{category}, $s->{act} );
    my $posts = [];
    given ( $s->{act} ) {
        when ( 'forum' )   { $posts = AltSimpleBoard::Data::Board::get_forum(@params) }
        when ( 'notes' )   { $posts = AltSimpleBoard::Data::Board::get_notes(@params) }
        when ( 'msgs' )    { $posts = AltSimpleBoard::Data::Board::get_msgs( @params, $s->{msgs_userid}) }
        when ( 'options' ) {}
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
        $c->init();
        $c->show();
    }
    else {
        $c->app->switch_act( $c, 'auth' );
        AltSimpleBoard::Auth::form_prepare($c);
        $c->render( 'auth/loginform', error => 'Bitte melden Sie sich an' );
    }
}

sub init {
    my $c = shift;
    my $userid = $c->session->{userid};
# prepare the user action
    AltSimpleBoard::Data::Board::update_user_stats($userid);
    $c->stash(notecount     => AltSimpleBoard::Data::Board::notecount($userid));
    $c->stash(newmsgscount  => AltSimpleBoard::Data::Board::newmsgscount($userid));
    $c->stash(newmsgs       => AltSimpleBoard::Data::Board::newmsgs($userid));
    $c->stash(categories    => AltSimpleBoard::Data::Board::categories());
    $c->stash(allcategories => AltSimpleBoard::Data::Board::allcategories());
    return 1;
}

1;

