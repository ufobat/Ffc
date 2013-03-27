package Ffc::Board::Views;

use 5.010;
use strict;
use warnings;
use utf8;

use base 'Ffc::Board::Errors';

use Ffc::Auth;
use Ffc::Data::General;
use Ffc::Data::Board;
use Ffc::Data::Board::Views;

sub _switch_category {
    my ( $c, $cat ) = @_;
    $c->error_handling({
        code        => sub { Ffc::Data::General::check_category($cat) },
        msg         => 'Die gewählte Kategorie ist ungültig.',
        after_error => sub { $c->session->{category} = '' },
        after_ok    => sub { $c->session->{category} = $cat },
    });
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
    $s->{msgs_username} = $c->param('msgs_username');
    delete($s->{msgs_username}) unless $s->{msgs_username};
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
        $session->{user}, 
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

    unless ( Ffc::Auth::check_login($c) ) {
        return Ffc::Auth::login_form($c, 'Bitte melden Sie sich an');
    }

    my $page   = $c->param('page')     // 1;
    my $postid = $c->param( 'postid' ) // '';
    my $user = $s->{user};
    my $userid = Ffc::Data::Auth::get_userid($user);
    $page   = 1  unless $page   =~ m/\A\d+\z/xms;
    $postid = '' unless $postid =~ m/\A\d+\z/xms;
    $c->stash(page   => $page);
    $c->stash(postid => $postid);
    
    for my $k ( qw(error post msgs_username) ) {
        my $d = $c->stash($k);
        $c->stash($k => '') unless $d;
    }
    my @params = $c->get_params($s, $page);
    my $posts  = [];
    my $act = $s->{act};
    my $cat = $s->{category};
    Ffc::Data::Board::Views::get_forum(@params);
    given ( $act ) {
        when('forum'  ){$posts=$c->or_empty(sub{Ffc::Data::Board::Views::get_forum(@params)})}
        when('notes'  ){$posts=$c->or_empty(sub{Ffc::Data::Board::Views::get_notes(@params)})}
        when('msgs'   ){$posts=$c->or_empty(sub{Ffc::Data::Board::Views::get_msgs(@params,$s->{msgs_username})})}
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
Ffc::Data::Board::Views::get_categories($user);
    $c->stash( categories => ($act eq 'forum') 
            ? $c->or_empty( sub { Ffc::Data::Board::Views::get_categories($user) } ) 
            : [] );
    if ( $c->error_handling({
        code        => sub { Ffc::Data::Board::update_user_stats($user, $act, $cat) },
        msg         => 'Etwas ist intern schief gegangen, bitte versuchen Sie es später noch einmal.',
        after_error => sub { 
            Ffc::Auth::login_form($c, 'Etwas ist intern schief gegangen, bitte melden Sie sich an') },
    }) ) {
        $c->render('board/frontpage');
    }
}

sub get_counts {
    my $c = shift;
    my $user = $c->session()->{user};
    $c->stash(notecount    => $c->or_zero(sub{Ffc::Data::Board::Views::count_notes(  $user)}));
    $c->stash(newmsgscount => $c->or_zero(sub{Ffc::Data::Board::Views::count_newmsgs($user)}));
    $c->stash(newpostcount => $c->or_zero(sub{Ffc::Data::Board::Views::count_newpost($user)}));
}
sub search {
    my $c = shift;
    $c->session->{query} = $c->param('query') || '';
    $c->frontpage();
}

1;

