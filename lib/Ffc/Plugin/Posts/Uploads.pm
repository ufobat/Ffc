package Ffc::Plugin::Posts; # Uploads
use 5.18.0;
use strict; use warnings; use utf8;
use Mojo::Util 'quote';
use Encode qw( encode decode_utf8 );

###############################################################################
# Formular zum Upload bereit stellen
sub _upload_post_form {
    my $c = $_[0];
    $c->stash( dourl => $c->url_for('upload_'.$c->stash('controller').'_do', $c->additional_params) );
    _setup_stash($c);
    unless ( _get_single_post(@_) ) {
        $c->set_error_f('Konnte keinen passenden Beitrag um Anhänge hochzuladen finden');
        return _redirect_to_show($c);
    }
    $c->counting;
    $c->render( template => 'upload_form' );
}

###############################################################################
# Dateien hochladen
sub _upload_post_do {
    my ( $c, $allownofiles, $noredirect ) = @_[0,1,2];
    my ( $wheres, @wherep ) = $c->where_modify;
    my $postid = $c->param('postid');

    # Prüfen, ob der angemeldete Benutzer überhaupt etwas zum Beitrag hochladen kann und darf
    {
        my $sql = q~SELECT "id" FROM "posts" WHERE "id"=?~;
        $wheres and $sql   .= qq~ AND $wheres~;
        my $post = $c->dbh_selectall_arrayref( $sql, $postid, @wherep );
        unless ( @$post ) {
            $c->set_error_f('Zum angegebene Beitrag kann kein Anhang hochgeladen werden.');
            return _redirect_to_show($c) unless $noredirect;
            return;
        }
    }

    # Folgende Subroutine wird im Zusammenhang mit dem Upload über den entsprechenden Helper aufgerufen
    # und macht entsprechend die Einträge in der Datenbank und liefert daraus das Array, welches den
    # Dateipfad darstellt.
    # Ich brauche das hier als Closure, da ich mich ja hier auf die $postid beziehen muss.
    my $filepathsub = sub { 
        my ($c, $filename, $filetype, $content_type) = @_;

        # Attachment in der Datenbank als Datensatz anlegen
        $c->dbh_do('INSERT INTO "attachements" ("filename", "content_type", "isimage", "inline", "postid") VALUES (?,?,?,?,?)',
            $filename, $content_type, ($c->is_image($content_type)?1:0), ($c->is_inline($content_type)?1:0), $postid);
        # Die Id aus der Datenbank wird gleichzeitig zum Dateinamen
        my $fileid = $c->dbh_selectall_arrayref(
            'SELECT "id" FROM "attachements" WHERE "postid"=? ORDER BY "id" DESC LIMIT 1',
            $postid);
        # Keine Ahnung, was da schief gelaufen sein sollte ...
        if ( not @$fileid ) {
            $c->set_error_f('Beim Dateiupload ist etwas schief gegangen, ich finde die Datei nicht mehr in der Datenbank');
            defined $fileid and $c->dbh_do('DELETE FROM "attachements" WHERE "id"=?', $fileid);
            return;
        }
        # Das hier wird zum Dateipfad catdir't ($fileid ist das Datenbank-Resultset)
        return [ 'uploads', $fileid->[0]->[0] ];
    };

    my @ret = $c->file_upload( 'attachement', undef, 'Dateianhang', 1, $c->configdata->{maxuploadsize}, 2, 200, $filepathsub, $allownofiles );
    $c->set_info_f('Dateien an den Beitrag angehängt') if @ret;

    _redirect_to_show($c) unless $noredirect;
}

###############################################################################
# Datei herunterladen
sub _download_post {
    my $c = $_[0];
    my ( $wheres, @wherep ) = $c->where_select;
    my $fileid = $c->param('fileid');

    # Prüfen, ob die entsprechende Datei in der Datenbank zu finden ist
    # und wenn ja, dann alle Informationen dazu holen.
    # Den Post p brauchen wir eventuell für die $wheres
    my $sql = qq~SELECT\n~
            . qq~a."filename", a."content_type", a."isimage", a."inline"\n~
            . qq~FROM "attachements" a\n~
            . qq~INNER JOIN "posts" p ON a."postid"=p."id"\n~
            . qq~WHERE a."id"=?~;
    $wheres and $sql .= " AND $wheres";
    my $filename = $c->dbh_selectall_arrayref( $sql, $fileid, @wherep );
    # Gibt keine Datei in der Datenbank
    unless ( @$filename ) {
        $c->set_error('Konnte die gewünschte Datei in der Datenbank nicht finden.');
        return $c->rendered(404);
    }

    my ( $content_type, $isimage, $inline ) = @{$filename->[0]}[1,2,3];
    $filename = $filename->[0]->[0];
    my $file = catfile(@{$c->datapath}, 'uploads', $fileid);

    # Gibt es die Datei im Dateisystem?
    unless ( -e $file ) {
        $c->set_error('Konnte die gewünschte Datei im Dateisystem nicht finden.');
        return $c->renderd(404);
    }

    # Legacy, weil es für einige Dateien die Informationen hier damals seinerzeit nicht gab
    $content_type or ( ( $content_type, $isimage, $inline ) = ('*/*', 0, 0) );

    # Datei-Download-HTTP-Dingsi zusammenbasteln
    $file = Mojo::Asset::File->new(path => $file);
    my $headers = Mojo::Headers->new();
    $headers->add( 'Content-Length' => $file->size );
    $headers->add( 'Content-Type', $content_type );
    $headers->add( 'Content-Disposition', 
        ($inline ? 'inline' : 'attachment') 
        . qq~; filename=~ 
        . quote( encode 'UTF-8', $filename ) );
    $c->res->content->headers($headers);
    $c->res->content->asset($file);
    $c->rendered(200);
}

1;
