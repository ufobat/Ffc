package Ffc::Notes;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

our $GetNotesSQL = << 'EOSQL';
SELECT p."id", uf."id", '', uf."id", '', p."posted", p."altered", p."cache" 
  FROM "posts" p
  INNER JOIN "users" uf ON p."userfrom"=uf."id"
 WHERE p."userfrom"=p."userto" AND p."userfrom"=?
 ORDER BY p."id" DESC
    LIMIT ? OFFSET ?
EOSQL

our $AddNoteSQL = << 'EOSQL';
INSERT INTO "posts"
    ("userfrom", "userto", "textdata", "cache")
VALUES 
    (?,?,?,?)
EOSQL

our $UpdateNoteSQL = << 'EOSQL';
UPDATE "posts" 
SET "textdata"=?, "cache"=?
WHERE "id"=? AND "userfrom"="userto" AND "userfrom"=?
EOSQL

our $GetNoteTextSQL = << 'EOSQL';
SELECT p."id", uf."id", '', uf."id", '', p."posted", p."altered", p."cache", p."textdata"
  FROM "posts" p
  INNER JOIN "users" uf ON p."userfrom"=uf."id"
 WHERE p."id"=? AND p."userfrom"=p."userto" AND p."userfrom"=?
EOSQL

sub show {
    my $c = shift;
    $c->stash(notes => $c->dbh->selectall_arrayref(
        $GetNotesSQL, undef,
        $c->session->{userid}, $c->pagination
    ));
    $c->render(template => 'notes');
}

sub add {
    my $c = shift;
    my $text = $c->param('textdata');
    if ( !defined($text) or (2 > length $text) ) {
        $c->stash(textdata => $text);
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen)');
        return $c->show();
    }
    my $uid = $c->session->{userid};
    $c->dbh->do(
        $AddNoteSQL, undef,
        $uid, $uid, $text, $c->pre_format($text)
    );
    $c->show();
}

sub _get_single_post {
    my $c = shift;

    my $postid = $c->param('postid');
    my $post   = $c->dbh->selectall_arrayref(
        $GetNoteTextSQL, undef, 
        $postid, $c->session->{userid}
    );
    my $textdata = '';
    if ( $post and @$post ) {
        $textdata = $post->[0]->[8];
    }
    else {
        $c->set_warning('Keine passenden Beiträge gefunden');
    }

    $c->stash( textdata => $textdata );
    $c->stash( postid   => $postid );
    $c->stash( post     => $post );
    $c->stash( act      => 'notes' );
    $c->stash( returl   => $c->url_for('show_notes') ); 
}

sub edit_form {
    my $c = shift;
    $c->_get_single_post;
    $c->stash( heading  => 'Persönliche Notiz ändern' );
    $c->stash( dourl    => $c->url_for('edit_note_do') );
    $c->render( template => 'edit_form' );
}

sub edit_do {
    my $c = shift;
    my $postid = $c->param('postid');
    unless ( $postid and $postid =~ $Ffc::Digqr ) {
        $c->set_error('Konnte den Beitrag nicht ändern, da die Beitragsnummer irgendwie verloren ging');
        return $c->edit_form();
    }
    my $text = $c->param('textdata');
    if ( !defined($text) or (2 > length $text) ) {
        $c->stash(textdata => $text);
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen)');
        return $c->edit_form();
    }
    $c->dbh->do(
        $UpdateNoteSQL, undef,
        $text, $c->pre_format($text), $postid, $c->session->{userid}
    );
    $c->set_info('Beitrag geändert');
    $c->show();
}

sub delete_check {
    my $c = shift;
    $c->_get_single_post;
    $c->stash( heading  => 'Persönliche Notiz ändern' );
    $c->stash( dourl    => 'delete_notes_do' );
    $c->render( template => 'delete_check' );
}

sub delete_do {
    my $c = shift;
    $c->render(template => 'notes');
}

1;

