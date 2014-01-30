package Ffc::Board::Views;

use 5.010;
use strict;
use warnings;
use utf8;

use Carp;
use Ffc::Data::General;
use Ffc::Auth;
use Ffc::Board::Options;
use Ffc::Data::Board;
use Ffc::Data::Board::Views;
use Ffc::Data::Board::Avatars;

use base 'Ffc::Board::Errors';

sub get_params {
    my $c = shift;
    return
        $c->session->{user},
        $c->stash('page'),
        $c->session->{query},
        $c->stash('msgs_username'),
        $c->stash('category'),
        $c;
}

sub frontpage {
    my $c = shift;
    my $s = $c->session;
    my $act = $c->stash('act');
    my ( $userp, $page, $query, $msgs_username, $cat ) = $c->get_params();           

    {
        my $prev_act = $s->{prev_act} // 'forum';
        if ( $prev_act ne $act ) {
            if ( $act eq 'forum' ) {
                $c->stash('category' => $cat = $s->{prev_category});
            }
            $s->{prev_act} = $act;
        }
        if ( $act eq 'forum' ) {
            $s->{prev_category} = $cat;
        }
    }

    my $postid = $c->stash('postid');

    if ( $act eq 'options' ) {
        return Ffc::Board::Options::options_form( $c );
    }

    my $user = $s->{user};
    
    for my $k ( qw(error post) ) {
        my $d = $c->stash($k);
        $c->stash($k => '') unless $d;
    }
    my $posts  = [];
    my @params = $c->get_params(); #($user, $page, $s->{query}, $cat, $c);
    if ( $act eq 'forum' ) {
        $posts = Ffc::Data::Board::Views::get_forum(@params);
    }
    elsif ( $act eq 'notes' ) {
        $posts = Ffc::Data::Board::Views::get_notes(@params);
    }
    elsif ( $act eq 'msgs' ) {
        $c->stash(userlist => Ffc::Data::Board::Views::get_userlist($user));
        $posts = Ffc::Data::Board::Views::get_msgs(@params,$msgs_username);
    }
    else {
        $c->error_handling({plain=>qq("$act" unbekannt)});
    }
    if ( $postid ) {
        my @post = grep { exists($_->{id}) and defined($_->{id}) and ( $_->{id} eq $postid ) } @$posts;
        if ( @post ) {
            $post[0]->{raw} = $c->stash('post') if $c->stash('post');
            $post[0]->{active} = 1;
        }
    }
    $c->stash( posts => $posts);
    $c->get_counts;
    $c->stash( categories => ($act eq 'forum') 
            ? Ffc::Data::Board::Views::get_categories($user) 
            : [] );
    $c->stash( footerlinks => $Ffc::Data::Footerlinks );
    if ( Ffc::Data::Board::update_user_stats($user, $act, $cat) ) {
        $c->render('board/frontpage');
    }
}

sub get_counts {
    my $c = shift;
    my $user = $c->session()->{user};
    $c->stash(notecount    => Ffc::Data::Board::Views::count_notes(   $user));
    $c->stash(newmsgscount => Ffc::Data::Board::Views::count_newmsgs( $user));
    $c->stash(newpostcount => Ffc::Data::Board::Views::count_newposts($user));
}
sub search {
    my $c = shift;
    $c->session->{query} = $c->param('query') || '';
    $c->frontpage();
}

sub show_avatar {
    my $c = shift;
    $c->render_static(
            Ffc::Data::Board::Avatars::get_avatar_path($c->param('username'))
         || "$Ffc::Data::Themedir/".$c->bgcolor().'/img/avatar.png'
    );
}

1;
