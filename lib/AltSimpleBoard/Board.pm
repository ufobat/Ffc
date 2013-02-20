package AltSimpleBoard::Board;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use AltSimpleBoard::Data::Board;
use AltSimpleBoard::Data::Auth;
use AltSimpleBoard::Auth;
use AltSimpleBoard::Errors;

sub error_prepare  { &AltSimpleBoard::Errors::prepare     }
sub error_handling { &AltSimpleBoard::Errors::handling    }
sub or_nostring    { &AltSimpleBoard::Errors::or_nostring }
sub or_empty       { &AltSimpleBoard::Errors::or_empty    }
sub or_zero        { &AltSimpleBoard::Errors::or_zero     }

sub options_form {
    my $c = shift;
    my $s = $c->session;
    $c->error_prepare;
    my $email;
    $c->error_handling( sub { $email = AltSimpleBoard::Data::Board::get_useremail($s->{userid}) } );
    my $userlist;
    $c->error_handling( sub { $userlist = AltSimpleBoard::Data::Board::get_userlist() });
    $c->stash(email    => $email // '');
    $c->stash(userlist => $userlist // '' );
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
    $c->error_handling( sub { AltSimpleBoard::Data::Board::update_email($s->{userid}, $email) } ) 
        if $email;
    $c->error_handling( sub { AltSimpleBoard::Data::Board::update_password($s->{userid}, $oldpw, $newpw1, $newpw2) } ) 
        if $oldpw and $newpw1 and $newpw2;
    $c->error_handling( sub { AltSimpleBoard::Data::Board::update_theme($s, $theme) } ) 
        if $theme;
    $c->error_handling( sub { AltSimpleBoard::Data::Board::update_show_images($s, $show_images) } );
    $c->options_form();
}

sub useradmin_save {
    my $c = shift;
    my $s = $c->session;
    $c->error_handling( {
        code => sub { die unless AltSimpleBoard::Data::Auth::is_user_admin($s->{userid}) },
        msg => q{Angemeldeter Benutzer ist kein Admin und darf das hier garnicht},
    } );
    $c->render('options_form');
}

sub _switch_category {
    my ( $c, $cat ) = @_;
    $cat = $cat =~ m/\A(\w+)\z/xmsi ? $1 : undef;
    $c->session->{category} = $c->or_nostring( sub{AltSimpleBoard::Data::Board::get_category_id($cat) } );
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
    $s->{msgs_username} = $c->or_nostring( sub{AltSimpleBoard::Data::Board::get_username($s->{msgs_userid}) } );
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
    $c->error_prepare;
    my $id   = $c->param('postid');
    my $s    = $c->session;
    my $post = $c->or_nostring( sub { AltSimpleBoard::Data::Board::get_post($id, $c->get_params($s) ) } );
    $c->stash( post => $post ); $s->{category} = $post->{category} ? $post->{category}->{short} : '' if $post;
    $c->frontpage();
}

sub delete_check {
    my $c = shift;
    $c->error_prepare;
    my $s = $c->session;
    my $id = $c->param('postid');
    $c->error_handling( { plain => "Privatnachrichten dürfen nicht gelöscht werden" } ) if $s->{act} eq 'msgs';
    $c->get_counts();
    my $post;
    $c->error_handling( {
        code => sub { $post = AltSimpleBoard::Data::Board::get_post($id, $c->get_params($s)) },
        msg  => 'Beitrag zum Löschen konnte nicht ermittelt werden',
        after_error => sub { $c->frontpage() },
        after_ok    => sub { $c->stash( post => $post ); $c->render('board/deletecheck') },
    } );
}
sub delete_post {
    my $c = shift;
    my $s = $c->session;
    $c->error_handling( { plain => "Privatnachrichten dürfen nicht gelöscht werden" } ) if $s->{act} eq 'msgs';
    $c->error_handling( { code => sub { AltSimpleBoard::Data::Board::delete_post($s->{userid}, $c->param('postid')) }, msg  => 'Beitrag konnte nicht gelöscht werden',
    } );
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
    $c->error_handling( {
        code        => sub { AltSimpleBoard::Data::Board::insert_post(@params) }, 
        msg         => 'Beitrag ungültig, bitte erneut eingeben', 
        after_ok    => sub { $c->frontpage() },
        after_error => sub { $c->edit_form() },
    } );
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
        when ( 'msgs'  ) { $c->error_handling( { plain => 'Privatnachrichten dürfen nicht geändert werden' } ) }
    }
    $c->error_handling( {
        code        => sub { AltSimpleBoard::Data::Board::update_post(@params) },
        msgs        => 'Beitrag ungültig, bitte erneut eingeben',
        after_ok    => sub { $c->redirect_to('show') },
        after_error => sub { $c->edit_form() },
    } );
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
    $c->error_prepare;

    unless ( AltSimpleBoard::Auth::check_login($c) ) {
        return AltSimpleBoard::Auth::login_form($c, 'Bitte melden Sie sich an');
    }

    my $page   = $c->param('page')     // 1;
    my $postid = $c->param( 'postid' ) // '';
    my $userid = $s->{userid};
    $page   = 1  unless $page   =~ m/\A\d+\z/xms;
    $postid = '' unless $postid =~ m/\A\d+\z/xms;
    $c->stash(page   => $page);
    $c->stash(postid => $postid);
    
    for my $k ( qw(error msgs_userid post msgs_username) ) {
        my $d = $c->stash($k);
        $c->stash($k => '') unless $d;
    }
    my @params = $c->get_params($s, $page);
    my $posts  = [];
    my $act = $s->{act};
    my $cat = $s->{category};
    given ( $act ) {
        when('forum'  ){$posts=$c->or_empty(sub{AltSimpleBoard::Data::Board::get_forum(@params)})}
        when('notes'  ){$posts=$c->or_empty(sub{AltSimpleBoard::Data::Board::get_notes(@params)})}
        when('msgs'   ){$posts=$c->or_empty(sub{AltSimpleBoard::Data::Board::get_msgs(@params,$s->{msgs_userid})})}
        when('options'){}
        default        {$c->error_handling({plain=>qq("$act" unbekannt)})}
    }
    if ( $postid and $postid ne '' ) {
        my @post = grep { $_->{id} eq $postid } @$posts;
        if ( @post ) {
            $c->stash( post => $post[0] );
            $post[0]->{active} = 1;
        }
    }
    $c->stash( posts => $posts);
    $c->get_counts;
    $c->stash( categories => ($act eq 'forum') 
            ? $c->or_empty( sub { AltSimpleBoard::Data::Board::get_categories() } ) 
            : [] );
    $c->error_handling({
        code        => sub { AltSimpleBoard::Data::Board::update_user_stats($userid, $act, $cat) },
        msg         => 'Etwas ist intern schief gegangen, bitte versuchen Sie es später noch einmal.',
        after_error => sub { 
            AltSimpleBoard::Auth::login_form($c, 'Etwas ist intern schief gegangen, bitte melden Sie sich an') },
    });
    $c->render('board/frontpage');
}

sub get_counts {
    my $c = shift;
    my $userid = $c->session()->{userid};
    $c->stash(notecount    => $c->or_zero(sub{AltSimpleBoard::Data::Board::count_notes(  $userid)}));
    $c->stash(newmsgscount => $c->or_zero(sub{AltSimpleBoard::Data::Board::count_newmsgs($userid)}));
    $c->stash(newpostcount => $c->or_zero(sub{AltSimpleBoard::Data::Board::count_newpost($userid)}));
}
sub search {
    my $c = shift;
    $c->session->{query} = $c->param('query') || '';
    $c->frontpage();
}

1;

