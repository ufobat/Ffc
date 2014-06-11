package Ffc::Plugin::Posts; # Uploads
use 5.010;
use strict; use warnings; use utf8;

sub _upload_post_form {
    my $c = shift;
    $c->stash( dourl => $c->url_for('upload_'.$c->stash('controller').'_do', $c->additional_params) );
    _setup_stash($c);
    return unless _get_single_post($c, @_);
    $c->render( template => 'upload_form' );
}

sub _upload_post_do {
    my $c = shift;
    my ( $wheres, @wherep ) = $c->where_modify;

    my $file = $c->param('attachement');
    my $postid = $c->param('postid');
    unless ( $postid and $postid =~ $Ffc::Digqr ) {
        $c->set_error_f('Konnte keinen Anhang zu dem Beitrag hochladen, da die Beitragsnummer irgendwie verloren ging');
        return _redirect_to_show($c);
    }
    {
        my $sql = q~SELECT "id" FROM "posts" WHERE "id"=?~;
        $sql   .= qq~ AND $wheres~ if $wheres;
        my $post = $c->dbh->selectall_arrayref( $sql, undef, $postid, @wherep );
        unless ( @$post ) {
            $c->set_error_f('Zum angegebene Beitrag kann kein Anhang hochgeladen werden.');
            return _redirect_to_show($c);
        }
    }
    
    unless ( $file ) {
        $c->set_error_f('Kein Anhang angegeben.');
        return _redirect_to_show($c);
    }
    unless ( $file->isa('Mojo::Upload') ) {
        $c->set_error_f('Keine Datei als Anhang angegeben.');
        return _redirect_to_show($c);
    }
    if ( $file->size < 1 ) {
        $c->set_error_f('Datei ist zu klein, sollte mindestens 1B groß sein.');
        return _redirect_to_show($c);
    }
    if ( $file->size > 2000000 ) {
        $c->set_error_f('Datei ist zu groß, darf maximal 2MB groß sein.');
        return _redirect_to_show($c);
    }

    my $filename = $file->filename;

    unless ( $filename ) {
        $c->set_error_f('Der Dateiname zum hochladen fehlt.');
        return _redirect_to_show($c);
    }
    if ( 2 > length $filename ) {
        $c->set_error_f('Dateiname ist zu kurz, muss mindestens 2 Zeichen inklusive Dateiendung enthalten.');
        return _redirect_to_show($c);
    }
    if ( 200 < length $filename ) {
        $c->set_error_f('Dateiname ist zu lang, darf maximal 200 Zeichen lang sein.');
        return _redirect_to_show($c);
    }
    if ( $file->filename =~ m/\A\./xms ) {
        $c->set_error_f('Der Dateiname darf nicht mit einem "." beginnen.');
        return _redirect_to_show($c);
    }
    if ( $filename =~ m/(?:\.\.|\/)/xmso ) {
        $c->set_error_f('Der Dateiname darf weder ".." noch "/" enthalten.');
        return _redirect_to_show($c);
    }

    $c->dbh->do('INSERT INTO "attachements" ("filename", "postid") VALUES (?,?)',
        undef, $filename, $postid);
    my $fileid = $c->dbh->selectall_arrayref(
        'SELECT "id" FROM "attachements" WHERE "postid"=? ORDER BY "id" DESC LIMIT 1',
        undef, $postid);
    if ( @$fileid ) {
        $fileid = $fileid->[0]->[0];
    }
    else {
        $c->set_error_f('Beim Dateiupload ist etwas schief gegangen, ich finde die Datei nicht mehr in der Datenbank');
        return _redirect_to_show($c);
    }

    unless ( $file->move_to(catfile(@{$c->datapath}, 'uploads', $fileid)) ) {
        $c->set_error_f('Das Hochladen des Anhanges ist fehlgeschlagen.');
        return _redirect_to_show($c);
    }

    $c->set_info_f('Datei an den Beitrag angehängt');
    _redirect_to_show($c);
};

sub _download_post {
    my $c = shift;
    my ( $wheres, @wherep ) = $c->where_select;
    my $fileid = $c->param('fileid');
    unless ( $fileid ) {
        $c->set_error('Download des gewünschten Dateianhanges nicht möglich');
        return $c->show;
    }
    my $sql = qq~SELECT\n~
            . qq~a."filename"\n~
            . qq~FROM "attachements" a\n~
            . qq~INNER JOIN "posts" p ON a."postid"=p."id"\n~
            . qq~WHERE a."id"=?~;
    $sql .= " AND $wheres" if $wheres;
    my $filename = $c->dbh->selectall_arrayref( $sql, undef, $fileid, @wherep );
    unless ( @$filename ) {
        $c->set_error('Konnte die gewünschte Datei in der Datenbank nicht finden.');
        return $c->renderd(404);
    }
    $filename = $filename->[0]->[0];
    my $file = catfile(@{$c->datapath}, 'uploads', $fileid);
    unless ( -e $file ) {
        $c->set_error('Konnte die gewünschte Datei im Dateisystem nicht finden.');
        return $c->renderd(404);
    }
    $file = Mojo::Asset::File->new(path => $file);
    my $headers = Mojo::Headers->new();
    $headers->add( 'Content-Disposition', 'attachment;filename=' . $filename );
    $headers->add( 'Content-Length' => $file->size );
    $c->res->content->headers($headers);
    $c->res->content->asset($file);
    $c->rendered(200);
}

1;

