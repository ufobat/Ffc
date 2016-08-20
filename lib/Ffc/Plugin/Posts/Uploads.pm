package Ffc::Plugin::Posts; # Uploads
use 5.18.0;
use strict; use warnings; use utf8;
use Mojo::Util 'quote';
use Encode qw( encode decode_utf8 );

###############################################################################
sub _upload_post_form {
    my $c = shift;
    $c->stash( dourl => $c->url_for('upload_'.$c->stash('controller').'_do', $c->additional_params) );
    _setup_stash($c);
    unless ( _get_single_post($c, @_) ) {
        $c->set_error_f('Konnte keinen passenden Beitrag um Anhänge hochzuladen finden');
        return _redirect_to_show($c);
    }
    $c->counting;
    $c->render( template => 'upload_form' );
}

###############################################################################
sub _upload_post_do {
    my $c = shift;
    my ( $wheres, @wherep ) = $c->where_modify;

    my $postid = $c->param('postid');
    unless ( $postid and $postid =~ $Ffc::Digqr ) {
        $c->set_error_f('Konnte keinen Anhang zu dem Beitrag hochladen, da die Beitragsnummer irgendwie verloren ging');
        return _redirect_to_show($c);
    }
    {
        my $sql = q~SELECT "id" FROM "posts" WHERE "id"=?~;
        $sql   .= qq~ AND $wheres~ if $wheres;
        my $post = $c->dbh_selectall_arrayref( $sql, $postid, @wherep );
        unless ( @$post ) {
            $c->set_error_f('Zum angegebene Beitrag kann kein Anhang hochgeladen werden.');
            return _redirect_to_show($c);
        }
    }

    my $fileid;
    my $filepathsub = sub { 
        my ($c, $filename, $filetype, $content_type) = @_;
        $c->dbh_do('INSERT INTO "attachements" ("filename", "content_type", "isimage", "inline", "postid") VALUES (?,?,?,?,?)',
            $filename, $content_type, ($c->is_image($content_type)?1:0), ($c->is_inline($content_type)?1:0), $postid);
        $fileid = $c->dbh_selectall_arrayref(
            'SELECT "id" FROM "attachements" WHERE "postid"=? ORDER BY "id" DESC LIMIT 1',
            $postid);
        if ( @$fileid ) {
            $fileid = $fileid->[0]->[0];
        }
        else {
            $c->set_error_f('Beim Dateiupload ist etwas schief gegangen, ich finde die Datei nicht mehr in der Datenbank');
            $c->dbh_do('DELETE FROM "attachements" WHERE "id"=?', $fileid) if defined $fileid;
            return;
        }
        return [ 'uploads', $fileid ];
    };
    $c->file_upload( 'attachement', undef, 'Dateianhang', 1, $c->configdata->{maxuploadsize}, 2, 200, $filepathsub);
    $c->set_info_f('Dateien an den Beitrag angehängt');

    _redirect_to_show($c);
};

###############################################################################
sub _download_post {
    my $c = shift;
    my ( $wheres, @wherep ) = $c->where_select;
    my $fileid = $c->param('fileid');
    unless ( $fileid ) {
        $c->set_error('Download des gewünschten Dateianhanges nicht möglich');
        return $c->show;
    }
    my $sql = qq~SELECT\n~
            . qq~a."filename", a."content_type", a."isimage", a."inline"\n~
            . qq~FROM "attachements" a\n~
            . qq~INNER JOIN "posts" p ON a."postid"=p."id"\n~
            . qq~WHERE a."id"=?~;
    $sql .= " AND $wheres" if $wheres;
    my $filename = $c->dbh_selectall_arrayref( $sql, $fileid, @wherep );
    unless ( @$filename ) {
        $c->set_error('Konnte die gewünschte Datei in der Datenbank nicht finden.');
        return $c->rendered(404);
    }
    
    my ( $content_type, $isimage, $inline ) = @{$filename->[0]}[1,2,3];
    $filename = $filename->[0]->[0];
    my $file = catfile(@{$c->datapath}, 'uploads', $fileid);
    unless ( -e $file ) {
        $c->set_error('Konnte die gewünschte Datei im Dateisystem nicht finden.');
        return $c->renderd(404);
    }
    $file = Mojo::Asset::File->new(path => $file);
    my $headers = Mojo::Headers->new();
    $headers->add( 'Content-Length' => $file->size );
    unless ( $content_type ) {
        if ( $filename =~ m~\.(\w+)\z~xmso ) {
            my $fe = $1;
            if ( $fe =~ m~png|jpe?g|ico|bmp|gif~xmsio ) {
                $content_type = "image/$fe";
                $isimage = 1;
                $inline  = 1;
            }
            else {
                $content_type = "*/$fe";
                $isimage = 0;
                $inline  = 0;
            }
        }
        else {
            $content_type = '*/*';
            $isimage = 0;
            $inline  = 0;
        }
    }
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

