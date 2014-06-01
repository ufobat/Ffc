package Ffc::Notes;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

sub _setup_notes {
    my $c = shift;
    $c->stash( act      => 'notes' );
    $c->stash( addurl   => $c->url_for('add_note') );
    $c->stash( editurl  => 'edit_note_form' );
    $c->stash( delurl   => 'delete_note_check' );
    $c->stash( returl   => $c->url_for('show_notes') );
    $c->stash( pageurl  => 'show_notes_page' );
    $c->stash( queryurl => $c->url_for('query_notes') );
}

sub show {
    my $c = shift;
    $c->_setup_notes();
    $c->stash( heading => 'Persönliche Notizen' );
    return $c->show_posts(
        'p."userfrom"=p."userto" AND p."userfrom"=?',
        $c->session->{userid}
    );
}

sub query { 
    my $c = shift;
    $c->query_posts();
    $c->show;
}

sub add {
    my $c = shift;
    $c->add_post($c->session->{userid}, undef);
    $c->show();
}

sub _get_single_post {
    my $c = shift;

    my $postid = $c->param('postid');
    my $post   = $c->dbh->selectall_arrayref( << 'EOSQL', undef,
SELECT p."id", uf."id", '', uf."id", '', p."posted", p."altered", p."cache", p."textdata"
  FROM "posts" p
  INNER JOIN "users" uf ON p."userfrom"=uf."id"
 WHERE p."id"=? AND p."userfrom"=p."userto" AND p."userfrom"=?
EOSQL
        $postid, $c->session->{userid}
    );
    my $textdata = '';
    if ( $post and @$post ) {
        $textdata = $post->[0]->[8];
        $c->stash( post => $post->[0] );
    }
    else {
        $c->set_warning('Keine passenden Beiträge gefunden');
        $c->stash( post => '' );
    }

    $c->stash( textdata => $textdata );
    $c->stash( postid   => $postid );
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
    $c->dbh->do( << 'EOSQL', undef,
UPDATE "posts" 
SET "textdata"=?, "cache"=?, altered=current_timestamp
WHERE "id"=? AND "userfrom"="userto" AND "userfrom"=?
EOSQL
        $text, $c->pre_format($text), $postid, $c->session->{userid}
    );
    $c->set_info('Beitrag geändert');
    $c->show();
}

sub delete_check {
    my $c = shift;
    $c->_get_single_post;
    $c->stash( heading  => 'Persönliche Notiz entfernen' );
    $c->stash( dourl    => $c->url_for('delete_note_do') );
    $c->render( template => 'delete_check' );
}

sub delete_do {
    my $c = shift;
    my $postid = $c->param('postid');
    unless ( $postid and $postid =~ $Ffc::Digqr ) {
        $c->set_error('Konnte den Beitrag nicht ändern, da die Beitragsnummer irgendwie verloren ging');
        return $c->show();
    }
    $c->dbh->do( << 'EOSQL', undef,
DELETE FROM "posts" 
WHERE "id"=? AND "userfrom"="userto" AND "userfrom"=?
EOSQL
        $postid, $c->session->{userid}
    );
    $c->set_info('Beitrag entfernt');
    $c->show();
}

1;

