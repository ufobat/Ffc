package Ffc::Forum;
use 5.18.0;
use strict; use warnings; use utf8;

use Ffc::Forum::Topics::Routes;
use Ffc::Forum::Topics::Display;
use Ffc::Forum::Topics::Create;
use Ffc::Forum::Topics::Edit;
use Ffc::Forum::Topics::Movepost;
use Ffc::Forum::Topics::Flag;

###############################################################################
# Eine Themenid anhand des Thementitels ermitteln
sub _get_topicid_for_title {
    my $r = $_[0]->dbh_selectall_arrayref(
        'SELECT "id" FROM "topics" WHERE "title"=?',
        $_[1] // $_[0]->param('titlestring')
    );
    @$r or return;
    return $r->[0]->[0];
}

###############################################################################
# Den Titel zu einem Thema entsprechend der Themen-Id ermitteln
sub _get_title_from_topicid {
    my $r = $_[0]->dbh_selectall_arrayref(
        'SELECT "title", "userfrom" FROM "topics" WHERE "id"=?',
        $_[1] // $_[0]->param('topicid')
    );
    unless ( @$r ) {
        # Wahlweise kann die Weiterleitung unterbunden werden ... da muss man aber ein extra Flag setzen
        unless ( $_[1] ) {
            $_[0]->set_error('Konnte das gewünschte Thema nicht finden.');
            $_[0]->show_topiclist;
        }
        return;
    }
    return wantarray ? @{$r->[0]} : $r->[0]->[0];
}

###############################################################################
# Prüfen, ob ein Titel ins Schema passt (hauptsächlich Längenprüfung)
sub _check_titlestring {
    my $titlestring = $_[1] // $_[0]->param('titlestring');
    if ( not defined($titlestring) or (2 > length $titlestring) ) {
        $_[0]->set_error('Die Übschrift ist zu kurz und muss mindestens zwei Zeichen enthalten.');
        return;
    }
    if ( 256 < length $titlestring ) {
        $_[0]->set_error('Die Überschrift ist zu lang und darf höchstens 256 Zeichen enthalten.');
        return;
    }
    return 1;
}

1;
