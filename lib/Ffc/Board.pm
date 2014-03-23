package Ffc::Board;
use Mojo::Base 'Mojolicious::Controller';

sub frontpage {
    my $c = shift;
    $c->set_error('Der Text, der erscheint, wenn etwas schief gelaufen ist oder so nicht gemacht werden darf.');
    $c->set_info('Dieser Text weißt den Benutzer auf erfolgreiche Aktionen im System hin.');
    $c->set_warning('Mit diesem Text soll dem Benutzer deutlich gemacht werden, dass etwas im Moment noch nicht so wie erwartet ausgeführt werden konnte und dass der Benutzer ggf. noch etwas korrigieren oder prüfen sollte.');
    $c->render(template => 'board/frontpage');
}

1;

