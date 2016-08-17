package Ffc::Plugin::Posts; # Create
use 5.18.0;
use strict; use warnings; use utf8;

use File::Spec qw(catfile);

sub _delete_upload_post_check {
    my $c = shift;
    $c->stash( dourl => $c->url_for('delete_upload_'.$c->stash('controller').'_do', $c->additional_params) );
    _setup_stash($c);
    unless ( _get_single_post($c, @_) ) {
        $c->set_error_f('Konnte keinen passenden Beitrag zum Löschen der Anhänge finden');
        return _redirect_to_show($c);
    }
    $c->counting;
    $c->render( template => 'delete_upload_check' );
}

sub _delete_upload_post_do {
    my $c = shift;
    my ( $wheres, @wherep ) = $c->where_select;
    my $fileid = $c->param('fileid');
    unless ( $fileid and $fileid =~ $Ffc::Digqr ) {
        $c->set_error_f('Kann den Anhang nicht löschen, da die IDs für den Beitrag oder den Anhang unterwegs irgendwie verloren gegangen sind');
        return _redirect_to_show($c);
    }
    unless ( _get_single_post($c, @_) ) {
        $c->set_error_f('Konnte keinen passenden Beitrag zum Löschen der Anhänge finden');
        return _redirect_to_show($c);
    }
    $c->stash(textdata => '');
    my $post = $c->stash('post');
    if ( $post->[0] != $c->stash('postid') ) {
        $c->set_error_f('Der gewünschte zu löschende Anhang passt nicht zum angegebenen Beitrag');
        return _redirect_to_show($c);
    }
    if ( $post->[1] != $c->session->{userid} ) {
        $c->set_error_f('Sie dürfen diesen Anhang nicht löschen, da der Beitrag nicht von Ihnen erstellt wurde');
        return _redirect_to_show($c);
    }
    _get_attachements($c, [$post]); 
    my $attachements = $c->stash('attachements');
    unless ( $attachements and @$attachements ) {
        $c->set_error_f('Der angegebene Beitrag enthält ja gar keine Anhänge zum löschen');
        return _redirect_to_show($c);
    }
    $attachements = [ grep { $_->[0] == $fileid } @$attachements ];
    unless ( $attachements and @$attachements and 1 == @$attachements ) {
        $c->set_error_f('Der angegebene Anhang gehört nicht zum angegebenen Beitrag');
        return _redirect_to_show($c);
    }
    my $file = catfile(@{$c->datapath}, 'uploads', $fileid);
    unless ( unlink $file ) {
        $c->set_error_f('Der angegebene Anhang konnte nicht aus dem Dateisystem gelöscht werden');
        return _redirect_to_show($c);
    }
    $c->dbh_do('DELETE FROM "attachements" WHERE "id"=?', $fileid);
    $c->set_info_f('Anhang entfernt');
    _redirect_to_show($c);
}

1;

