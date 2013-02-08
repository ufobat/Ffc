package AltSimpleBoard::Board;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use AltSimpleBoard::Data::Board;
use AltSimpleBoard::Data::Auth;
use AltSimpleBoard::Auth;

sub options_form {
    my $c = shift;
    my $s = $c->session;
    $c->stash(email => AltSimpleBoard::Data::Board::get_useremail($s->{userid}));
    $c->stash(userlist => AltSimpleBoard::Data::Board::get_userlist());
    $c->stash(themes => \@AltSimpleBoard::Data::Themes);
    delete $s->{msgs_userid}; delete $s->{msgs_username};
    $c->get_counts();
    $c->app->switch_act( $c, 'options' );
    $c->render('board/optionsform');
}

sub options_save {
    my $c = shift;
    my $s = $c->session;
    my $email       = $c->param('email');
    my $oldpw       = $c->param('oldpw');
    my $newpw1      = $c->param('newpw1');
    my $newpw2      = $c->param('newpw2');
    my $show_images = $c->param('show_images') || 0;
    my $theme       = $c->param('theme');
    AltSimpleBoard::Data::Board::update_email($s->{userid}, $email) if $email;
    AltSimpleBoard::Data::Board::update_password($s->{userid}, $oldpw, $newpw1, $newpw2) if $oldpw and $newpw1 and $newpw2;
    AltSimpleBoard::Data::Board::update_theme($s, $theme) if $theme;
    AltSimpleBoard::Data::Board::update_show_images($s, $show_images);
    $c->redirect_to('options_form');
}

sub useradmin_save {
    my $c = shift;
    my $s = $c->session;
    die q{Angemeldeter Benutzer ist kein Admin und darf das hier garnicht} 
        unless AltSimpleBoard::Data::Auth::is_user_admin($s->{userid});
    $c->redirect_to('options_form');
}

sub _switch_category {
    my ( $c, $cat ) = @_;
    $cat = $cat =~ m/\A(\w+)\z/xmsi ? $1 : undef;
    $c->session->{category} = eval { AltSimpleBoard::Data::Board::get_category_id($cat) } ? $cat : '';
}

sub switch_category {
    my $c = shift;
    $c->app->switch_act($c, 'forum');
    _switch_category($c,$c->param('category'));
    $c->frontpage();
}

sub msgs_user {
    my $c = shift;
    my $s = $c->session;
    $c->app->switch_act($c, 'msgs');
    $s->{msgs_userid} = $c->param('msgs_userid');
    $s->{msgs_username} = eval { AltSimpleBoard::Data::Board::get_username($s->{msgs_userid}) };
    delete($s->{msgs_userid}), delete($s->{msgs_username}) unless $s->{msgs_username};
    $c->frontpage();
}

sub switch_act {
    my $c = shift;
    $c->app->switch_act($c, $c->param('act'));
    $c->frontpage();
}

sub edit_form {
    my $c = shift;
    my $id = $c->param('postid');
    my $s = $c->session;
    my $post = AltSimpleBoard::Data::Board::get_post($id, $c->get_params($s) );
    $c->stash( post => $post );
    $s->{category} = $post->{category} ? $post->{category}->{short} : '';
    $c->frontpage();
}

sub delete_check {
    my $c = shift;
    my $s = $c->session;
    my $id = $c->param('postid');
    die "Privatnachrichten dürfen nicht gelöscht werden" if $s->{act} eq 'msgs';
    $c->get_counts();
    $c->stash( post => AltSimpleBoard::Data::Board::get_post($id, $c->get_params($s)) );
    $c->render('board/deletecheck');
}
sub delete_post {
    my $c = shift;
    my $s = $c->session;
    die "Privatnachrichten dürfen nicht gelöscht werden" if $s->{act} eq 'msgs';
    AltSimpleBoard::Data::Board::delete_post($s->{userid}, $c->param('postid'));
    $c->redirect_to('show');
}

sub insert_post {
    my $c = shift;
    my $s = $c->session;
    my $text = $c->param('post')     =~ m/\A\s*(.+)\s*\z/xmsi ? $1 : '';
    my $fromid = $s->{userid};
    my @params = ( $fromid, $text, $s->{category} );
    given ( $s->{act} ) {
        when ( 'notes' ) { push @params, $fromid }
        when ( 'msgs'  ) { push @params, $s->{msgs_userid} }
    }
    # from, text, to
    AltSimpleBoard::Data::Board::insert_post(@params) if $text;
    $c->redirect_to('show');
}

sub update_post {
    my $c = shift;
    my $s = $c->session;
    my $text = $c->param('post')     =~ m/\A\s*(.+)\s*\z/xmsi ? $1 : '';
    my $postid = $c->param('postid');
    my $fromid = $s->{userid};
    my @params = ( $fromid, $text, $postid );
    given ( $s->{act} ) {
        when ( 'notes' ) { push @params, $fromid }
        when ( 'msgs'  ) { die 'Privatnachrichten dürfen nicht geändert werden' }
    }
    # from, text, id, to
    AltSimpleBoard::Data::Board::update_post(@params) if $text;
    $c->redirect_to('show');
}

sub get_params {
    my ( $self, $session, $page ) = @_;
    $page = 1 unless $page and $page =~ m/\A\d+\z/xms;
    return 
        $session->{userid}, 
        $page, 
        $session->{lastseen},
        $session->{query},
        $session->{category},
        $session->{act},
        $self;
}

sub frontpage {
    my $c = shift;
    my $s = $c->session;

    unless ( AltSimpleBoard::Auth::check_login($c) ) {
        return AltSimpleBoard::Auth::login_form($c, 'Bitte melden Sie sich an');
    }

    my $page = $c->param('page') // 1;
    my $postid = $c->param( 'postid' ) // '';
    my $userid = $s->{userid};
    $page = 1 unless $page =~ m/\A\d+\z/xms;
    $postid = '' unless $postid =~ m/\A\d+\z/xms;
    $c->stash(page   => $page);
    $c->stash(postid => $postid);
    
    for my $k ( qw(error msgs_userid post msgs_username) ) {
        my $d = $c->stash($k);
        $c->stash($k => '') unless $d;
    }
    my @params = $c->get_params($s, $page);
    my $posts  = [];
    given ( $s->{act} ) {
        when ( 'forum' )   { $posts = AltSimpleBoard::Data::Board::get_forum(@params) }
        when ( 'notes' )   { $posts = AltSimpleBoard::Data::Board::get_notes(@params) }
        when ( 'msgs' )    { $posts = AltSimpleBoard::Data::Board::get_msgs( @params, $s->{msgs_userid}) }
        when ( 'options' ) {}
        default { die qq("$s->{act}" undefined) }
    }
    if ( $postid and $postid ne '' ) {
        my @post = grep { $_->{id} eq $postid } @$posts;
        if ( @post ) {
            $c->stash( post => $post[0] );
            $post[0]->{active} = 1;
        }
    }
    $c->stash( posts => $posts);
    AltSimpleBoard::Data::Board::update_user_stats($userid);
    $c->get_counts;
    $c->stash(categories    => ($s->{act} eq 'forum') ? AltSimpleBoard::Data::Board::get_categories() : []);

    $c->render('board/frontpage');
}

sub get_counts {
    my $c = shift;
    my $userid = $c->session()->{userid};
    $c->stash(notecount     => AltSimpleBoard::Data::Board::count_notes($userid));
    $c->stash(newmsgscount  => AltSimpleBoard::Data::Board::count_newmsgs($userid));
    $c->stash(newpostcount  => AltSimpleBoard::Data::Board::count_newpost($userid));
}
sub search {
    my $c = shift;
    $c->session->{query} = $c->param('query') || '';
    $c->frontpage();
}

1;

