package Ffc::Board::Views;

use 5.010;
use strict;
use warnings;
use utf8;

use base 'Ffc::Board::Errors';

use Carp;
use Ffc::Data::General;
use Ffc::Auth;
use Ffc::Board::Options;
use Ffc::Data::Board;
use Ffc::Data::Board::Views;
use Ffc::Data::Board::Avatars;

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
    my $postid = $c->stash('postid');

    if ( $act eq 'options' ) {
        return Ffc::Board::Options::options_form( $c );
    }

    my $user = $s->{user};
    my $userid = Ffc::Data::Auth::get_userid($user);
    
    for my $k ( qw(error post) ) {
        my $d = $c->stash($k);
        $c->stash($k => '') unless $d;
    }
    my $posts  = [];
    my @params = $c->get_params(); #($user, $page, $s->{query}, $cat, $c);
    Ffc::Data::Board::Views::get_forum(@params);
    given ( $act ) {
        when('forum' ){$posts=$c->or_empty(sub{Ffc::Data::Board::Views::get_forum(@params)})}
        when('notes' ){$posts=$c->or_empty(sub{Ffc::Data::Board::Views::get_notes(@params)})}
        when('msgs'  ){
            $c->stash(userlist => $c->or_empty(sub{Ffc::Data::Board::Views::get_userlist($user)}));
            $posts=$c->or_empty(sub{Ffc::Data::Board::Views::get_msgs(@params,$msgs_username)});
        }
        default       {$c->error_handling({plain=>qq("$act" unbekannt)})}
    }
    if ( $postid ) {
        my @post = grep { exists($_->{id}) and defined($_->{id}) and ( $_->{id} eq $postid ) } @$posts;
        if ( @post ) {
            $c->stash( post => $post[0] );
            $post[0]->{active} = 1;
        }
    }
    $c->stash( posts => $posts);
    $c->get_counts;
    $c->stash( categories => ($act eq 'forum') 
            ? $c->or_empty( sub { Ffc::Data::Board::Views::get_categories($user) } ) 
            : [] );
    $c->stash( footerlinks => $Ffc::Data::Footerlinks );
    if ( $c->error_handling({
        code        => sub { Ffc::Data::Board::update_user_stats($user, $act, $cat) },
        msg         => 'Etwas ist intern schief gegangen, bitte versuchen Sie es später noch einmal.',
        after_error => sub { 
            Ffc::Auth::logout($c, 'Etwas ist intern schief gegangen, bitte melden Sie sich an') },
    }) ) {
        $c->render('board/frontpage');
    }
}

sub get_counts {
    my $c = shift;
    my $user = $c->session()->{user};
    $c->stash(notecount    => $c->or_zero(sub{Ffc::Data::Board::Views::count_notes(   $user)}));
    $c->stash(newmsgscount => $c->or_zero(sub{Ffc::Data::Board::Views::count_newmsgs( $user)}));
    $c->stash(newpostcount => $c->or_zero(sub{Ffc::Data::Board::Views::count_newposts($user)}));
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
         || "$Ffc::Data::Themedir/".$c->session->{theme}.'/img/avatar.png'
    );
}

1;
