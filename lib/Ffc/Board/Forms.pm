package Ffc::Board::Forms;

use 5.010;
use strict;
use warnings;
use utf8;

use Mojo::Base 'Ffc::Board::Errors';

use Ffc::Data::Board::Views;
use Ffc::Data::Board::Forms;

sub edit_form {
    my $c = shift;
    $c->error_prepare;
    my $id   = $c->param('postid');
    my $s    = $c->session;
    my $post = $c->or_nostring( sub { Ffc::Data::Board::Views::get_post($id, $c->get_params($s) ) } );
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
        code => sub { $post = Ffc::Data::Board::Views::get_post($id, $c->get_params($s)) },
        msg  => 'Beitrag zum Löschen konnte nicht ermittelt werden',
        after_error => sub { $c->frontpage() },
        after_ok    => sub { $post->{active} = 1; $c->stash( post => $post ); $c->render('board/deletecheck') },
    } );
}
sub delete_post {
    my $c = shift;
    my $s = $c->session;
    $c->error_handling( { plain => "Privatnachrichten dürfen nicht gelöscht werden" } ) if $s->{act} eq 'msgs';
    $c->error_handling( { code => sub { Ffc::Data::Board::Forms::delete_post($s->{userid}, $c->param('postid')) }, msg  => 'Beitrag konnte nicht gelöscht werden',
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
        code        => sub { Ffc::Data::Board::Forms::insert_post(@params) }, 
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
        code        => sub { Ffc::Data::Board::Forms::update_post(@params) },
        msgs        => 'Beitrag ungültig, bitte erneut eingeben',
        after_ok    => sub { $c->redirect_to('show') },
        after_error => sub { $c->edit_form() },
    } );
}

1;

