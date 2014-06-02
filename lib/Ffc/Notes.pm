package Ffc::Notes;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

# Where-Bestandteil zum Suchen von Beiträgen in der Datenbank
# - Dieser SQL-Bestandteil benötigt das Prefix "p." für Feldnamen, 
#   da hier mehere Tabellen beim "SELECT" gejoint werden
# - Dieser Bestandteil wird zum anzeigen der Beitragsliste ($c->show) 
#   sowie zum anzeigen des einzelnen Beitrags bei edit und delete verwendet
# - Dieser Bestandteil wird in die Where-Clause eingebaut
# - "?"-Parameter müssen beim Aufruf der entsprechenden Helper-Subs
#   mit in der entsprechenden Reihenfolge übergeben werden
our $WhereS = 'p."userfrom"=p."userto" AND p."userfrom"=?'; # needs $c->session->{userid}

# Where-Bestandteil zum Ändern von Beiträgen in der Datenbank
# - Dieser SQL-Bestandteil darf keine Prefixe für Feldnamen enthalten,
#   da "UPDATE" und "DELETE" sonst auffe Schnauze fallen
# - Dieser Bestandteil wird beim Ausführen des Editieren- und Löschenvorganes
#   in der Datenbank verwendet
# - Dieser Bestandteil wird in die Where-Clause eingebaut
# - "?"-Parameter müssen beim Aufruf der entsprechenden Helper-Subs
#   mit in der entsprechenden Reihenfolge übergeben werden
our $WhereM = '"userfrom"="userto" AND "userfrom"=?'; # needs $c->session->{userid}

# Diese Hilfsfunktion setzt den Rahmen für alle Formulare innerhalb
# der Beitrags-Handling-Routinen. Es legt einige Stash-Variablen fest,
# die von allen Templates benötigt werden
sub setup_stash {
    my $c = shift;
    # Aktueller Beitragskontext für die Markierung im Menü
    $c->stash( act      => 'notes' ); 
    # Routenname für Abbrüche, der auf die Einstiegsseite der Beitragsübersicht verweißt
    $c->stash( returl   => $c->url_for('show_notes') );
    # Routenname für Filter-Suchen aus dem Menü heraus
    $c->stash( queryurl => $c->url_for('query_notes') );
}

sub show {
    my $c = shift;
    $c->stash( heading => 'Persönliche Notizen' );
    $c->stash( dourl   => $c->url_for('add_note') );
    $c->stash( editurl => 'edit_note_form' );
    $c->stash( delurl  => 'delete_note_check' );
    $c->stash( pageurl => 'show_notes_page' );
    $c->show_posts($WhereS, $c->session->{userid});
}

sub query { $_[0]->query_posts }

sub add {
    my $c = shift;
    $c->add_post($c->session->{userid}, undef);
}

sub edit_form {
    my $c = shift;
    $c->stash( heading => 'Persönliche Notiz ändern' );
    $c->stash( dourl   => $c->url_for('edit_note_do') );
    $c->edit_post_form($WhereS, $c->session->{userid});
}

sub edit_do {
    my $c = shift;
    $c->edit_post_do($WhereM, $c->session->{userid});
}

sub delete_check {
    my $c = shift;
    $c->stash( heading => 'Persönliche Notiz entfernen' );
    $c->stash( dourl   => $c->url_for('delete_note_do') );
    $c->delete_post_check($WhereS, $c->session->{userid});
}

sub delete_do {
    my $c = shift;
    $c->delete_post_do($WhereM, $c->session->{userid});
}

1;

