package AltSimpleBoard::Board::Views;

use 5.010;
use strict;
use warnings;
use utf8;

use Mojo::Base 'AltSimpleBoard::Board::Errors';

use AltSimpleBoard::Data::Board;
use AltSimpleBoard::Auth;

sub _switch_category {
    my ( $c, $cat ) = @_;
    $cat = $cat =~ m/\A(\w+)\z/xmsi ? $1 : undef;
    $c->session->{category} = $c->or_nostring( sub{AltSimpleBoard::Data::Board::check_category($cat) } );
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
    AltSimpleBoard::Data::Board::get_forum(@params);
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
            ? $c->or_empty( sub { AltSimpleBoard::Data::Board::get_categories($userid) } ) 
            : [] );
    if ( $c->error_handling({
        code        => sub { AltSimpleBoard::Data::Board::update_user_stats($userid, $act, $cat) },
        msg         => 'Etwas ist intern schief gegangen, bitte versuchen Sie es später noch einmal.',
        after_error => sub { 
            AltSimpleBoard::Auth::login_form($c, 'Etwas ist intern schief gegangen, bitte melden Sie sich an') },
    }) ) {
        $c->render('board/frontpage');
    }
}

sub get_counts {
    my $c = shift;
    my $userid = $c->session()->{userid};
AltSimpleBoard::Data::Board::count_newpost($userid);
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

