package Ffc::Plugin::Posts; # Create
use 5.18.0;
use strict; use warnings; use utf8;

use File::Spec qw(catfile);

###############################################################################
# Nachfrageformular, ob ein Upload wirklich gelöscht werden soll
sub _delete_upload_post_check {
    my $c = $_[0];
    $c->stash( dourl => $c->url_for('delete_upload_'.$c->stash('controller').'_do', $c->additional_params) );
    if ( not _get_single_post(@_) ) {
        $c->set_error_f('Konnte keinen passenden Beitrag zum Löschen der Anhänge finden');
        return _redirect_to_show($c);
    }
    _setup_stash($c);
    $c->counting;
    $c->render( template => 'delete_upload_check' );
}

###############################################################################
# Löschen eines Uploads mit allem drum und dran
sub _delete_upload_post_do {
    my $c = $_[0];
    my ( $wheres, @wherep ) = $c->where_modify;
    my $fileid = $c->param('fileid');

    # Bekommen wir auch wirklich einen Beitrag heraus?
    unless ( _get_single_post(@_) ) {
        $c->set_error_f('Konnte keinen passenden Beitrag zum Löschen der Anhänge finden');
        return _redirect_to_show($c);
    }

    # Passt der angegebene Anhang zum übergebenen Beitrag
    $c->stash(textdata => '');
    my $post = $c->stash('post');
    if ( $post->[0] != $c->stash('postid') ) {
        $c->set_error_f('Der gewünschte zu löschende Anhang passt nicht zum angegebenen Beitrag');
        return _redirect_to_show($c);
    }
    # Darf ich genau diesen Anhang löschen?
    if ( $post->[1] != $c->session->{userid} ) {
        $c->set_error_f('Sie dürfen diesen Anhang nicht löschen, da der Beitrag nicht von Ihnen erstellt wurde');
        return _redirect_to_show($c);
    }

    # Hat der Beitrag überhaupt Anhänge, die ich löschen könnte
    _get_attachements($c, [$post]); 
    my $attachements = $c->stash('attachements');
    unless ( $attachements and @$attachements ) {
        $c->set_error_f('Der angegebene Beitrag enthält ja gar keine Anhänge zum löschen');
        return _redirect_to_show($c);
    }

    # Ist der angegebene Anhäng überhaupt bei den Anhängen des Beitrags dabei
    $attachements = [ grep { $_->[0] == $fileid } @$attachements ];
    unless ( $attachements and @$attachements and 1 == @$attachements ) {
        $c->set_error_f('Der angegebene Anhang gehört nicht zum angegebenen Beitrag');
        return _redirect_to_show($c);
    }

    # Die Datei muss ich erst mal löschen, das ist wichtig
    my $file = catfile(@{$c->datapath}, 'uploads', $fileid);
    unless ( unlink $file ) {
        $c->set_error_f('Der angegebene Anhang konnte nicht aus dem Dateisystem gelöscht werden');
        return _redirect_to_show($c);
    }

    # Und jetzt noch den Datenbankeintrag löschen
    $c->dbh_do('DELETE FROM "attachements" WHERE "id"=?', $fileid);
    $c->set_info_f('Anhang entfernt');

    _redirect_to_show($c);
}

1;
