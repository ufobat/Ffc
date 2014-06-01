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
        $c->show();
    }
    my $uid = $c->session->{userid};
    $c->dbh->do(
        $AddNoteSQL, undef,
        $uid, $uid, $text, $c->pre_format($text)
    );
    $c->show();
}

sub edit_form {
    my $c = shift;
    $c->render(
        template => 'edit_form', 
        act      => 'notes', 
        returl   => 'show_notes', 
        dourl    => 'edit_notes_do',
    );
}

sub edit_do {
    my $c = shift;
    $c->render(template => 'notes');
}

sub delete_form {
    my $c = shift;
    $c->render(
        template => 'delete_check', 
        act      => 'notes', 
        returl   => 'show_notes', 
        dourl    => 'delete_notes_do',
    );
}

sub delete_do {
    my $c = shift;
    $c->render(template => 'notes');
}

1;

