package Ffc::Plugin::Posts;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Plugin';
use File::Spec::Functions qw(catfile);

use strict;
use warnings;
use 5.010;

# Die Dokumentation dieses Plugins wurde beispielhaft und sehr ausführlich
# im Controller Ffc::Notes durchgeführt. Bitte da rein schauen, um raus zu
# bekommen, wie dieses Plugin zu verwenden ist.

sub register {
    my ( $self, $app ) = @_;
    $app->helper( show_posts               => \&_show_posts               );
    $app->helper( query_posts              => \&_query_posts              );
    $app->helper( add_post                 => \&_add_post                 );
    $app->helper( edit_post_form           => \&_edit_post_form           );
    $app->helper( edit_post_do             => \&_edit_post_do             );
    $app->helper( delete_post_check        => \&_delete_post_check        );
    $app->helper( delete_post_do           => \&_delete_post_do           );
    $app->helper( upload_post_form         => \&_upload_post_form         );
    $app->helper( upload_post_do           => \&_upload_post_do           );
    $app->helper( download_post            => \&_download_post            );
    $app->helper( delete_upload_post_check => \&_delete_upload_post_check );
    $app->helper( delete_upload_post_do    => \&_delete_upload_post_do    );
    return $self;
}

sub _pagination {
    my $c = shift;
    my $page = $c->param('page') // 1;
    my $postlimit = $c->configdata->{postlimit};
    $c->stash(page => $page);
    return $postlimit, ( $page - 1 ) * $postlimit;
}

sub _query_posts {
    my $c = shift;
    $c->session->{query} = $c->param('query');
    $c->show;
}

sub _get_attachements {
    my $c = shift;
    my $posts = shift;
    my $wheres = shift;
    my @wherep = @_;
    my $sql = qq~SELECT\n~
            . qq~a."id", a."postid", a."filename",\n~
            . qq~CASE WHEN p."userfrom"=? THEN 1 ELSE 0 END AS "deleteable"\n~
            . qq~FROM "attachements" a\n~
            . qq~INNER JOIN "posts" p ON a."postid"=p."id"\n~
            .  q~WHERE a."postid" IN ('~
            . (join q~', '~, map { $_->[0] } @$posts)
            .  q~')~;
    $sql .= " AND $wheres" if $wheres;
    $sql .= qq~\nORDER BY a."filename", a."id"~;
    #die $sql;
    return $c->stash( attachements =>
        $c->dbh->selectall_arrayref( $sql, undef, $c->session->{userid}, @wherep ) );
}

sub _show_posts {
    my $c = shift;
    my $wheres = shift;
    my @wherep = @_;
    my $query  = $c->session->{query};
    $query = "\%$query\%" if $query;
    $c->setup_stash;

    my $sql = qq~SELECT\n~
        .qq~p."id", uf."id", uf."name", ut."id", ut."name", p."topicid", p."posted", p."altered", p."cache"\n~
        .qq~FROM "posts" p\n~
        .qq~INNER JOIN "users" uf ON p."userfrom"=uf."id"\n~
        .qq~LEFT OUTER JOIN "users" ut ON p."userto"=ut."id"\n~;
    if ( $wheres ) {
        $sql .= "WHERE $wheres\n"
             . ( $query ? qq~AND UPPER(p."textdata") LIKE UPPER(?)\n~ : "\n" );
    }
    elsif ( $query ) {
        $sql .= qq~WHERE UPPER(p."textdata") LIKE UPPER(?)\n~;
    }
    $sql .= 'ORDER BY p."id" DESC LIMIT ? OFFSET ?';

    my $posts = $c->dbh->selectall_arrayref(
        $sql, undef, @wherep, ( $query || () ), _pagination($c)
    );
    $c->stash(posts => $posts );

    _get_attachements($c, $posts, $wheres, @wherep);

    return $c->render(template => 'posts');
}

sub _add_post {
    my ( $c, $userto, $topicid ) = @_;
    my $text = $c->param('textdata');
    if ( !defined($text) or (2 > length $text) ) {
        $c->stash(textdata => $text);
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen)');
        return $c->show;
    }
    $c->dbh->do( << 'EOSQL', undef,
INSERT INTO "posts"
    ("userfrom", "userto", "topicid", "textdata", "cache")
VALUES 
    (?,?,?,?,?)
EOSQL
        $c->session->{userid}, $userto, $topicid, $text, $c->pre_format($text)
    );

    $c->set_info('Ein neuer Beitrag wurde erstellt');
    $c->show;
}

sub _get_single_post {
    my $c = shift;
    my $wheres = shift;
    my @wherep = @_;

    my $postid = $c->param('postid');

    my $sql = qq~SELECT\n~
        .qq~p."id", uf."id", uf."name", ut."id", ut."name", p."topicid", p."posted", p."altered", p."cache", p."textdata"\n~
        .qq~FROM "posts" p\n~
        .qq~INNER JOIN "users" uf ON p."userfrom"=uf."id"\n~
        .qq~LEFT OUTER JOIN "users" ut ON p."userto"=ut."id"\n~
        .qq~WHERE p."id"=?~;
    $sql .= qq~ AND $wheres~ if $wheres;
    my $post = $c->dbh->selectall_arrayref( $sql, undef, $postid, @wherep );
    my $textdata = $c->param('textdata') // '';
    if ( $post and @$post ) {
        $textdata = $post->[0]->[9] unless $textdata;
        $c->stash( post => $post->[0] );
        _get_attachements($c, $post, $wheres, @wherep);
    }
    else {
        $c->set_warning('Keine passenden Beiträge gefunden');
        $c->stash( post => '' );
    }

    $c->stash( textdata => $textdata );
    $c->stash( postid   => $postid );
}

sub _edit_post_form {
    my $c = shift;
    $c->setup_stash;
    _get_single_post($c, @_);
    $c->render( template => 'edit_form' );
}

sub _edit_post_do {
    my $c = shift;
    my $wheres = shift;
    my @wherep = @_;
    my $postid = $c->param('postid');
    my $text = $c->param('textdata');
    unless ( $postid and $postid =~ $Ffc::Digqr ) {
        $c->set_error('Konnte den Beitrag nicht ändern, da die Beitragsnummer irgendwie verloren ging');
        $c->stash(textdata => $text);
        return $c->show;
    }
    if ( !defined($text) or (2 > length $text) ) {
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen)');
        return $c->edit_form;
    }

    my $sql = qq~UPDATE "posts"\n~
            . qq~SET "textdata"=?, "cache"=?, "altered"=current_timestamp\n~
            . qq~WHERE "id"=?~;
    $sql .= qq~ AND $wheres~ if $wheres;
    $c->dbh->do( $sql, undef, $text, $c->pre_format($text), $postid, @wherep );
    $c->set_info('Der Beitrag wurde geändert');
    return $c->show;
}

sub _delete_post_check {
    my $c = shift;
    $c->setup_stash;
    _get_single_post($c, @_);
    $c->render( template => 'delete_check' );
}

sub _delete_post_do {
    my $c = shift;
    my $wheres = shift;
    my @wherep = @_;
    my $postid = $c->param('postid');
    unless ( $postid and $postid =~ $Ffc::Digqr ) {
        $c->set_error('Konnte den Beitrag nicht ändern, da die Beitragsnummer irgendwie verloren ging');
        return $c->show();
    }
    {
        my $sql = q~SELECT "id" FROM "posts" WHERE "id"=?~;
        $sql   .= qq~ AND $wheres~ if $wheres;
        my $post = $c->dbh->selectall_arrayref( $sql, undef, $postid, @wherep );
        unless ( @$post ) {
            $c->set_error('Der angegebene Beitrag konnte nicht entfernt werden.');
            return $c->show();
        }
    }
    my $atts = 0;
    {
        my $sql = q~SELECT "id" FROM "attachements" WHERE "postid"=?~;
        my $r = $c->dbh->selectall_arrayref( $sql, undef, $postid );
        $atts = @$r;
        my $delerr = 0;
        for my $r ( @$r ) {
            my $file = catfile(@{$c->datapath}, 'uploads', $r->[0]);
            unlink $file or $delerr++;
        }
        $c->set_warning("$delerr Anhänge konnten nicht entfernt werden.")
            if $delerr;
    }
    if ( $atts ) {
        my $sql = q~DELETE FROM "attachements" WHERE "postid"=?~;
        $c->dbh->do( $sql, undef, $postid );
    }
    {
        my $sql = q~DELETE FROM "posts" WHERE "id"=?~;
        $sql   .= qq~ AND $wheres~ if $wheres;
        $c->dbh->do( $sql, undef, $postid, @wherep );
    }
    $c->set_info('Der Beitrag wurde komplett entfernt');
    $c->show();
}

sub _upload_post_form {
    my $c = shift;
    $c->setup_stash;
    _get_single_post($c, @_);
    $c->render( template => 'upload_form' );
}

sub _upload_post_do {
    my $c = shift;
    my $wheres = shift;
    my @wherep = @_;

    my $file = $c->param('attachement');
    my $postid = $c->param('postid');
    unless ( $postid and $postid =~ $Ffc::Digqr ) {
        $c->set_error('Konnte keinen Anhang zu dem Beitrag hochladen, da die Beitragsnummer irgendwie verloren ging');
        return $c->show();
    }
    {
        my $sql = q~SELECT "id" FROM "posts" WHERE "id"=?~;
        $sql   .= qq~ AND $wheres~ if $wheres;
        my $post = $c->dbh->selectall_arrayref( $sql, undef, $postid, @wherep );
        unless ( @$post ) {
            $c->set_error('Zum angegebene Beitrag kann kein Anhang hochgeladen werden.');
            return $c->show();
        }
    }
    
    unless ( $file ) {
        $c->set_error('Kein Anhang angegeben.');
        return $c->options_form;
    }
    unless ( $file->isa('Mojo::Upload') ) {
        $c->set_error('Keine Datei als Anhang angegeben.');
        return $c->show;
    }
    if ( $file->size < 1 ) {
        $c->set_error('Datei ist zu klein, sollte mindestens 1B groß sein.');
        return $c->show;
    }
    if ( $file->size > 2000000 ) {
        $c->set_error('Datei ist zu groß, darf maximal 2MB groß sein.');
        return $c->show;
    }

    my $filename = $file->filename;

    unless ( $filename ) {
        $c->set_error('Der Dateiname zum Hochladenfehlt.');
        return $c->show;
    }
    if ( 2 > length $filename ) {
        $c->set_error('Dateiname ist zu kurz, muss mindestens 2 Zeichen inklusive Dateiendung enthalten.');
        return $c->show;
    }
    if ( 200 < length $filename ) {
        $c->set_error('Dateiname ist zu lang, darf maximal 200 Zeichen lang sein.');
        return $c->show;
    }
    if ( $file->filename =~ m/\A\./xms ) {
        $c->set_error('Der Dateiname darf nicht mit einem "." beginnen.');
        return $c->show;
    }
    if ( $filename =~ m/(?:\.\.|\/)/xmso ) {
        $c->set_error('Der Dateiname darf weder ".." noch "/" enthalten.');
        return $c->show;
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
        $c->set_error('Beim Dateiupload ist etwas schief gegangen, ich finde die Datei nicht mehr in der Datenbank');
        return $c->show;
    }

    unless ( $file->move_to(catfile(@{$c->datapath}, 'uploads', $fileid)) ) {
        $c->set_error('Das Hochladen des Anhanges ist fehlgeschlagen.');
        return $c->show;
    }

    $c->set_info('Datei an den Beitrag angehängt');
    $c->show;
};

sub _download_post {
    my $c = shift;
    my $wheres = shift;
    my @wherep = @_;
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
        return $c->show;
    }
    $filename = $filename->[0]->[0];
    my $file = catfile(@{$c->datapath}, 'uploads', $fileid);
    unless ( -e $file ) {
        $c->set_error('Konnte die gewünschte Datei im Dateisystem nicht finden.');
        return $c->show;
    }
    my $content = '';
    if ( open my $fh, '<', $file ) {
        local $/;
        $content = <$fh>;
    }
    else {
        $c->set_error('Konnte die gewünschte Datei im Dateisystem nicht auslesen.');
        return $c->show;
    }
    $c->res->headers->header('Content-Disposition' => qq~attachment; filename="$filename"~);
    $c->render(data => $content);
}

sub _delete_upload_post_check {
    my $c = shift;
    $c->setup_stash;
    _get_single_post($c, @_);
    $c->render( template => 'delete_upload_check' );
}

sub _delete_upload_post_do {
    my $c = shift;
    my $wheres = shift;
    my @wherep = @_;
    my $fileid = $c->param('fileid');
}

1;

