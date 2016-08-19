package Ffc::Forum;
use 5.18.0;
use strict; use warnings; use utf8;

###############################################################################
# Das Formular für die Bearbeitung des Thementitels
sub edit_topic_form {
    my $c = $_[0];
    $c->counting;
    $c->stash(
        topicid     => $c->param('topicid'),
        titlestring => $c->param('titlestring') // scalar($c->_get_title_from_topicid),
    );
    $c->render(template => 'topicform');
}

###############################################################################
# Prüfen, ob wir das Thema bearbeiten dürfen (Themenersteller oder Admin)
sub _check_topic_edit {
    my $c = $_[0];

    # Admins dürfen alles
    $c->session->{admin} and return 1;

    # Schauen wir mal, ob dem angemeldeten Benutzer das Thema gehört, weil nur dann darf der da den Titel ändern
    my $topicid = $_[1] // $c->param('topicid');
    my $r = $c->dbh_selectall_arrayref(
        'SELECT "id" FROM "topics" WHERE "id"=? AND "userfrom"=?',
        $topicid, $c->session->{userid}
    );
    # Und es ist sein Thema, er darf das Ändern
    @$r and return 1;

    # Der angemeldete Benutzer hat das Thema nicht erstellt und er ist auch kein Admin, deswegen darf er den Titel nicht ändern
    $c->set_error_f('Kann das Thema nicht ändern, da es nicht von Ihnen angelegt wurde und Sie auch kein Administrator sind.');
    $c->redirect_to('show_forum', topicid => $topicid);
    return;
}

###############################################################################
# Den Titel des Themas tatsächlich ändern
sub edit_topic_do {
    my $c = $_[0];
    my ( $titlestring, $topicid ) = ( $c->param('titlestring'), $c->param('topicid') );

    # Darf der angemeldete Benutzer das Thema ändern?
    $c->_check_topic_edit($topicid) or return;
    # Passt der Titel ins Schema?
    $c->_check_titlestring($titlestring) or return $c->edit_topic_form;

    # Prüfen, ob es den Titeln schon einmal gibt
    if ( my $topicidto = $c->_get_topicid_for_title($titlestring) ) {
        # Sonderfall: Der Titel hat sich gar nicht geändert, da machen wir auch nichts weiter
        if ( $topicidto == $topicid ) {
            $c->set_warning_f('Der Titel wurde nicht verändert.');
            return $c->redirect_to('show_forum', topicid => $topicid);
        }

        # Der neue Titel existiert bereits, wir könnten höchstens die Beiträge alle in das andere Thema verschieben
        # (und so die Themen zusammen fassen)
        $c->set_warning('Das gewünschte Thema existiert bereits.');
        $c->counting;
        $c->stash(
            topicid         => $topicid,
            topicidto       => $topicidto,
            titlestringdest => $titlestring,
            titlestringorig => scalar($c->_get_title_from_topicid($topicid)),
        );
        return $c->render(template => 'topicmoveform');
    }

    # Wir können den Titel direkt ohne Sorgen setzen und alles ist palettig
    $c->dbh_do( 'UPDATE "topics" SET "title"=? WHERE "id"=?', $titlestring, $topicid);
    $c->set_info_f('Die Überschrift des Themas wurde geändert.');
    $c->redirect_to('show_forum', topicid => $topicid);
}

###############################################################################
# Und hier verschieben wir ein Thema komplett in ein anderes hinein.
# Im Gegensatz zum Verschieben in "Movepost.pm" werden hier alle Beiträge auf einmal direkt
# in der Datenbank verschoben, weil sich das beim Ändern des Thementitels so ergeben hat.
# "Movepost.pm" hingegeben verschiebt einzelne Beiträge, was ein wenig komplizierter ist,
# weil da ja immer noch ein Link in das jeweils andere Thema bestehen bleibt.
sub move_topic_do {
    my $c = $_[0];
    my ( $topicid, $topicidto, $uid ) = ( $c->param('topicid'), $c->param('topicidto'), $c->session->{userid} );

    # Wie üblich: Darf der angemeldete Benutzer das Thema überhaupt bearbeiten
    $c->_check_topic_edit($topicid) or return $c->redirect_to('show_forum_topiclist');

    # Verschieben der Beiträge über einen Datenbankaufruf
    $c->dbh_do( 'UPDATE "posts" SET "topicid"=? WHERE "topicid"=?', $topicidto, $topicid );

    # Wieviele Beiträge sind jetzt im alten Thema verblieben?
    my $r = $c->dbh_selectall_arrayref( 'SELECT COUNT("id") FROM "posts" WHERE "topicid"=?', $topicid );
    # Im alten Thema sind noch Beiträge erhalten, also ist was schief gegangen und wir lassen das erstmal, bevor Beiträge verloren gehen
    if ( $r->[0]->[0] ) {
        $c->set_error_f('Die Beiträge konnten nicht verschoben werden.');
        return $c->redirect_to('show_forum_topiclist');
    }
    # Das alte Thema und das zugehörige Usertracking kann getrost gelöscht werden
    $c->dbh_do( 'DELETE FROM "topics" WHERE "id"=?', $topicid );
    $c->dbh_do( 'DELETE FROM "lastseenforum" WHERE "topicid"=?', $topicid );

    # Wars
    $c->set_info_f('Die Beiträge wurden in ein anderes Thema verschoben.');
    $c->redirect_to('show_forum', topicid => $topicidto);
}

1;
