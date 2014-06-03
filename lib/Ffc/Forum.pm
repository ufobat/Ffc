package Ffc::Forum;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

sub install_routes {
    my $l = $_[0];
    $l->get('/forum')->to('forum#show')->name('show_forum');
}

sub _setup_forum {
    my $c = shift;
    $c->stash( act      => 'forum' );
    $c->stash( addurl   => $c->url_for('add_forum') );
    $c->stash( editurl  => 'edit_forum_form' );
    $c->stash( delurl   => 'delete_forum_check' );
    $c->stash( returl   => $c->url_for('show_forum') );
    $c->stash( pageurl  => 'show_forum_page' );
    $c->stash( queryurl => $c->url_for('query_forum') );
}

sub show {
    my $c = shift;
    $c->_setup_forum;
    $c->set_error('Der Text, der erscheint, wenn etwas schief gelaufen ist oder so nicht gemacht werden darf.');
    $c->set_info('Dieser Text weißt den Benutzer auf erfolgreiche Aktionen im System hin.');
    $c->set_warning('Mit diesem Text soll dem Benutzer deutlich gemacht werden, dass etwas im Moment noch nicht so wie erwartet ausgeführt werden konnte und dass der Benutzer ggf. noch etwas korrigieren oder prüfen sollte.');
    $c->render(template => 'forum');
}

1;

