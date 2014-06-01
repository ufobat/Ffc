package Ffc::Pmsgs;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

sub _setup_pmsgs {
    my $c = shift;
    $c->stash( act      => 'pmsgs' );
    $c->stash( addurl   => $c->url_for('add_pmsgs') );
    $c->stash( editurl  => 'edit_pmsgs_form' );
    $c->stash( delurl   => 'delete_pmsgs_check' );
    $c->stash( returl   => $c->url_for('show_pmsgs') );
    $c->stash( pageurl  => 'show_pmsgs_page' );
    $c->stash( queryurl => $c->url_for('query_pmsgs') );
}

sub show {
    my $c = shift;
    $c->_setup_pmsgs;
    $c->set_error('Der Text, der erscheint, wenn etwas schief gelaufen ist oder so nicht gemacht werden darf.');
    $c->set_info('Dieser Text weißt den Benutzer auf erfolgreiche Aktionen im System hin.');
    $c->set_warning('Mit diesem Text soll dem Benutzer deutlich gemacht werden, dass etwas im Moment noch nicht so wie erwartet ausgeführt werden konnte und dass der Benutzer ggf. noch etwas korrigieren oder prüfen sollte.');
    $c->render(template => 'pmsgs');
}

1;

