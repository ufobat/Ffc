package Ffc::Board::Forms;

use 5.010;
use strict;
use warnings;
use utf8;

use base 'Ffc::Board::Errors';

use Ffc::Data;
use Ffc::Data::Board::Views;
use Ffc::Data::Board::Forms;

sub edit_form {
    my $c = shift;
    my $rewrite = shift // 0;
    my $act = $c->stash('act');
    if ( $act eq 'msgs' ) {
        $c->error_handling( { plain => "Privatnachrichten dürfen nicht geändert werden" } );
    }
    elsif ( not $rewrite ) {
        my $id   = $c->stash('postid');
        my $post = $c->or_nostring( sub { Ffc::Data::Board::Views::get_post($act, $id, $c->get_params() ) } );
        $c->stash( post => $post );
    }
    $c->frontpage();
}

sub delete_check {
    my $c = shift;
    my $act = $c->param('act');
    if ( $act eq 'msgs' ) {
        $c->error_handling( { plain => "Privatnachrichten dürfen nicht gelöscht werden" } );
        $c->frontpage();
    }
    else {
        my $id = $c->stash('postid');
        $c->get_counts();
        my $post;
Ffc::Data::Board::Views::get_post($act, $id, $c->get_params());
        $c->error_handling( {
            code => sub { $post = Ffc::Data::Board::Views::get_post($act, $id, $c->get_params()) },
            msg  => 'Beitrag zum Löschen konnte nicht ermittelt werden',
            after_error => sub { $c->redirect_to_show() },
            after_ok    => sub { $post->{active} = 1; $c->stash( post => $post ); $c->render('board/deletecheck') },
        } );
    }
}
sub delete_post {
    my $c = shift;
    my $act = $c->stash('act');
    my $s = $c->session;
    $c->error_handling( { plain => "Privatnachrichten dürfen nicht gelöscht werden" } ) if $act eq 'msgs';
    $c->error_handling( { code => sub { Ffc::Data::Board::Forms::delete_post($s->{user}, $c->param('postid')) }, msg  => 'Beitrag konnte nicht gelöscht werden',
    after_ok => sub { $c->info('Beitrag wurde gelöscht'); $c->redirect_to_show() },
    } );
}

sub insert_post {
    my $c = shift;
    my $act = $c->stash('act');
    if ( $act ne 'notes' and check_for_updates($c) ) {
        $c->error_stash('Ein neuer Beitrag wurde zwischenzeitlich durch einen anderen Benutzer erstellt. Bitte Beitrag vor dem Absenden nochmal überprüfen.');
        $c->stash(post => {raw => $c->param('post')});
        return $c->edit_form(1);
    }
    my $s = $c->session;
    my $text = $c->param('post');
    $c->error_handling({plain => 'Text des Beitrages ungültig'}) unless $text;
    my $from = $s->{user};
    my @params = ( $from, $text, $c->stash('category') );
    given ( $act ) {
        when ( 'notes' ) { push @params, $from }
        when ( 'msgs'  ) { push @params, $c->stash('msgs_username') }
    }
    $c->error_handling( {
        code        => sub { Ffc::Data::Board::Forms::insert_post(@params) }, 
        msg         => 'Beitrag ungültig, bitte erneut eingeben', 
        after_ok    => sub { $c->info('Beitrag wurde erstellt'); $c->redirect_to_show},
        after_error => sub { $c->edit_form() },
    } );
}

sub update_post {
    my $c = shift;
    my $act = $c->stash('act');
    if ( $act ne 'notes' and check_for_updates($c) ) {
        $c->error_stash('Ein neuer Beitrag wurde zwischenzeitlich durch einen anderen Benutzer erstellt. Bitte Beitrag vor dem Absenden nochmal überprüfen.');
        $c->stash(post => {raw => $c->param('post')});
        return $c->edit_form(1);
    }
    my $s = $c->session;
    my $text = $c->param('post');
    $c->error_handling({plain => 'Text des Beitrages ungültig'}) unless $text;
    my $postid = $c->stash('postid');
    my $from = $s->{user};
    my @params = ( $from, $text, $postid );
    given ( $act ) {
        when ( 'msgs'  ) { $c->error_handling( { plain => 'Privatnachrichten dürfen nicht geändert werden' } ) }
    }
    $c->error_handling( {
        code        => sub { Ffc::Data::Board::Forms::update_post(@params) },
        msgs        => 'Beitrag ungültig, bitte erneut eingeben',
        after_ok    => sub { $c->info('Beitrag wurde geändert'); $c->param(post => undef); $c->stash(postid => undef); $c->redirect_to_show() },
        after_error => sub { $c->edit_form() },
    } );
}

sub check_for_updates {
    my $c = shift;
    return #$c->or_zero(sub{
        Ffc::Data::Board::Views::check_for_updates(
            $c->session()->{user}, $c->stash('act'), $c->stash('category'), $c->stash('msgs_username')
        )
    #});
}

1;

