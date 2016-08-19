package Ffc::Forum;
use 5.18.0;
use strict; use warnings; use utf8;

###############################################################################
# Das Formular für der Erstellen eines neuen Themas vorbereiten und anzeigen
sub add_topic_form {
    my $c = $_[0];
    $c->counting;
    $c->stash(
        titlestring => $c->param('titlestring') // '',
        topicid     => undef,
        textdata    => $c->param('textdata') // '',
    );
    $c->render(template => 'topicform');
}

###############################################################################
# Ein neues Thema wird erstellt
sub _create_topic {
    my $c = $_[0];
    my ( $uid, $titlestring ) = ( $c->session->{userid}, $c->param('titlestring') );

    # Prüfen, ob der Titel überhaupt ins Schema passt
    $c->_check_titlestring( $titlestring ) or return;

    # Prüfen, ob es ein Thema mit selben Titel schon gibt, dann übernehmen wir nämlich diese Id
    # und fügen den neuen Beitrag einfach da mit hinzu
    if ( my $topicid = $c->_get_topicid_for_title($titlestring) ) {
        $c->set_warning('Das Thema gab es bereits, der eingegebene Beitrag wurde zum Thema hinzugefügt.');
        return $topicid;
    }
    $c->set_error('');

    # Das neue Thema anlegen
    $c->dbh_do(
        'INSERT INTO "topics" ("userfrom", "title") VALUES (?,?)',
        $uid, $titlestring
    );
    # Die Id des neuen Themas ermitteln
    my $r = $c->dbh_selectall_arrayref(
        'SELECT "id" FROM "topics" WHERE "userfrom"=? AND "title"=? ORDER BY "id" DESC LIMIT 1',
        $uid, $titlestring
    );
    # Etwas undefiniertes ist schief gegangen, naja, Pech gehabt
    unless ( @$r ) {
        $c->set_error('Das Thema konnte irgendwie nicht angelegt werden. Bitte versuchen Sie es erneut.');
        return;
    }

    # Die Id des neuen Themas einfach zurück liefern
    return $r->[0]->[0];
}

###############################################################################
# Ein neuer Beitrag wird eventuell in einem neuen (oder aber eben bestehenden) Thema eingetragen
sub add_topic_do {
    my $c = $_[0];
    my $uid = $c->session->{userid};

    # Der Text wird schon mal geprüft
    my $text = $c->param('textdata');
    if ( !defined($text) or (2 > length $text) ) {
        $c->stash(textdata => $text);
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen)');
        return $c->add_topic_form;
    }

    # Wird tatsächlich ein neues Thema angelegt, dann wird unter dessen neuer Themen-Id ein Artikel angelegt
    if ( my $topicid = _create_topic($c) ) {
        $c->param(topicid => $topicid);
        $c->add;
        return;
    }
    
    # Es wurde kein Thema angelegt, wir müssen also noch einmal zurück
    $c->add_topic_form;
}

1;
