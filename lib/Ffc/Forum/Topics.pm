package Ffc::Forum;
use 5.18.0;
use strict; use warnings; use utf8;

use Ffc::Forum::Topics::Display;
use Ffc::Forum::Topics::Create;
use Ffc::Forum::Topics::Edit;
use Ffc::Forum::Topics::Movepost;
use Ffc::Forum::Topics::Flag;

sub _get_topicid_for_title {
    my $c = shift;
    my $r = $c->dbh_selectall_arrayref(
        'SELECT "id" FROM "topics" WHERE "title"=?',
        shift() // $c->param('titlestring')
    );
    return unless @$r;
    return $r->[0]->[0];
}

sub _check_titlestring {
    my $c = shift;
    my $titlestring = shift() // $c->param('titlestring');
    if ( !defined($titlestring) or (2 > length $titlestring) ) {
        $c->set_error('Die Übschrift ist zu kurz und muss mindestens zwei Zeichen enthalten.');
        return;
    }
    if ( 256 < length $titlestring ) {
        $c->set_error('Die Überschrift ist zu lang und darf höchstens 256 Zeichen enthalten.');
        return;
    }
    return 1;
}

sub _get_title_from_topicid {
    my $c = shift;
    my $r = $c->dbh_selectall_arrayref(
        'SELECT "title", "userfrom" FROM "topics" WHERE "id"=?',
        shift() // $c->param('topicid')
    );
    unless ( @$r ) {
        $c->set_error('Konnte das gewünschte Thema nicht finden.');
        $c->show_topiclist;
        return;
    }
    return wantarray ? @{$r->[0]} : $r->[0]->[0];
}


1;

