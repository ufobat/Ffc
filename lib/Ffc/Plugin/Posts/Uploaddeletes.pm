package Ffc::Plugin::Posts; # Create
use 5.010;
use strict; use warnings; use utf8;

use File::Spec qw(catfile);

sub _delete_upload_post_check {
    my $c = shift;
    $c->stash( dourl => $c->url_for('delete_upload_'.$c->stash('controller').'_do') );
    _setup_stash($c);
    return unless _get_single_post($c, @_);
    $c->render( template => 'delete_upload_check' );
}

sub _delete_upload_post_do {
    my $c = shift;
    my ( $wheres, @wherep ) = $c->where_select;
    my $fileid = $c->param('fileid');
    unless ( $fileid and $fileid =~ $Ffc::Digqr ) {
        $c->set_error('Kann den Anhang nicht löschen, da die IDs für den Beitrag oder den Anhang unterwegs irgendwie verloren gegangen sind');
        return $c->show;
    }
    return unless _get_single_post($c, @_);
    $c->stash(textdata => '');
    my $post = $c->stash('post');
    if ( $post->[0] != $c->stash('postid') ) {
        $c->set_error('Der gewünschte zu löschende Anhang passt nicht zum angegebenen Beitrag');
        return $c->show;
    }
    if ( $post->[1] != $c->session->{userid} ) {
        $c->set_error('Sie dürfen diesen Anhang nicht löschen, da der Beitrag nicht von Ihnen erstellt wurde');
        return $c->show;
    }
    _get_attachements($c, [$post]); 
    my $attachements = $c->stash('attachements');
    unless ( $attachements and @$attachements ) {
        $c->set_error('Der angegebene Beitrag enthält ja gar keine Anhänge zum löschen');
        return $c->show;
    }
    $attachements = [ grep { $_->[0] == $fileid } @$attachements ];
    unless ( $attachements and @$attachements and 1 == @$attachements ) {
        $c->set_error('Der angegebene Anhang gehört nicht zum angegebenen Beitrag');
        return $c->show;
    }
    my $file = catfile(@{$c->datapath}, 'uploads', $fileid);
    unless ( unlink $file ) {
        $c->set_error('Der angegebene Anhang konnte nicht aus dem Dateisystem gelöscht werden');
        return $c->show;
    }
    $c->dbh->do('DELETE FROM "attachements" WHERE "id"=?', undef, $fileid);
    $c->show;
}

1;

