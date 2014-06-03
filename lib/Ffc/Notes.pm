package Ffc::Notes;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

# Als erstes werden über die folgende Routine die notwendigen Routen definiert.
# Diese Routine wird aus Ffc::Routes angesprochen und übernimmt eine Bridge,
# bei welcher man bereits angemeldet ist und bei der die Anmeldung geprüft wird.
sub install_routes {
    my $l = shift;

    $l->route('/notes')->via('get')
      ->to('notes#show')->name('show_notes');
    $l->route('/notes/query')->via('post')
      ->to('notes#query')->name('query_notes');
    $l->route('/notes/:page', page => $Ffc::Digqr)->via('get')
      ->to('notes#show')->name('show_notes_page');

    $l->route('/notes/new')->via('post')
      ->to('notes#add')->name('add_note');

    $l->route('/notes/edit')->via('post')
      ->to('notes#edit_do')->name('edit_note_do');
    $l->route('/notes/edit/:postid', postid => $Ffc::Digqr)->via('get')
      ->to('notes#edit_form')->name('edit_note_form');

    $l->route('/notes/delete')->via('post')
      ->to('notes#delete_do')->name('delete_note_do');
    $l->route('/notes/delete/:postid', postid => $Ffc::Digqr)->via('get')
      ->to('notes#delete_check')->name('delete_note_check');

    $l->route('/notes/upload')->via('post')
      ->to('notes#upload_do')->name('upload_note_do');
    $l->route('/notes/upload/:postid', postid => $Ffc::Digqr)->via('get')
      ->to('notes#upload_form')->name('upload_note_form');

    $l->route('/notes/upload/delete')->via('post')
      ->to('notes#delete_upload_do')->name('delete_upload_note_do');
    $l->route('/notes/upload/delete/:uploadid', uploadid => $Ffc::Digqr)->via('get')
      ->to('notes#delete_upload_check')->name('delete_upload_note_check');
}
# Where-Bestandteile dienen dazu, den Aktionsradius von Funktionen
# innerhalb dieses Teils des Ffc einzuschränken, sind aber optional.

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

# Folge-Aktionen werden über Routennamen oder fertige Routen-URL's in
# Stash-Variablen gespeichert. Bestimmte Aktionen werden im Verlauf der
# Arbeit des Plugins "Posts" mit dynamischen Werten versehen und müssen
# dementsprechend als Routenname übergeben werden. Dazu werden sie in
# eine Arrayreferenz gepackt als ersten Eintrag und etwaige weitere
# Parameter, welche dieser Route übergeben werden müssen, können
# als weitere Parameter in dieser Arrayreferenz weiter hinten an
# gehängt werden. Einige Routen stehen allerdings fest und können
# vor dem Rendern der Templates schon fertig zur URL verbaut werden
# (wegen Performance). Diese Routen können bereits fertig erstellt werden
# an einer Stelle und werden als fertige URL's in die entsprechenden
# Stash-Variablen geschrieben.

# Diese Hilfsfunktion setzt den Rahmen für alle Formulare innerhalb
# der Beitrags-Handling-Routinen. Es legt einige Stash-Variablen fest,
# die von allen Templates benötigt werden
sub setup_stash {
    my $c = shift;
    $c->stash( 
        # Aktueller Beitragskontext für die Markierung im Menü
        act      => 'notes',
        # Routenname für Abbrüche, der auf die Einstiegsseite der Beitragsübersicht verweißt.
        # Diese Route wird direkt als URL festgelegt, da sie keine weiteren Daten braucht.
        returl   => $c->url_for('show_notes'),
        # Routenname für Filter-Suchen aus dem Menü heraus.
        # Diese Route wird direkt als URL festgelegt, da sie keine weiteren Daten braucht.
        queryurl => $c->url_for('query_notes'),
    );
}

# Folgende Funktionen stellen die Aktionen dar, die über die
# Routen dieses Teils des Ffc Beitragslisten enthalten. Sie 
# müssen, um mit den "Posts"-Plugin zu funktionieren, alle
# vorhanden sein, da sie von diesem Plugin verwendet werden.
# Jede Funktion kann optional über den Stash-Variablen "heading"
# eine Überschrift festlegen, die an prominenter Stelle auf der
# entsprechenden Seite angezeigt wird. Alles was über "dourl"
# definiert wird, kann fest als URL übergeben werden, da hier
# ein POST-Formular aufgebaut wird, welches keine weiteren Daten
# benötigt. Alle weiteren Routenangaben werden als Array-Referenz
# angelegt, und können somit weitere Parameter enthalten.

# Diese Funktion bietet die normale Anzeigeseite an. Hier werden
# Routen über Stash-Variablen definiert, welche auf dieser Seite 
# zu den einzelnen Posts angeboten werden, sowie eine "dourl", über 
# welche ein neuer Beitrag # erstellt wird. Außerdem wird die Route 
# "pageurl" angeboten, über welche die Seitenschaltung abgewickelt wird.
sub show {
    my $c = shift;
    $c->stash( 
        heading => 'Persönliche Notizen'         , # Überschrift
        dourl   => $c->url_for('add_note')       , # Neuen Beitrag erstellen
        editurl => [ 'edit_note_form'           ], # Formuar zum Bearbeiten von Beiträgen
        delurl  => [ 'delete_note_check'        ], # Formular, um den Löschvorgang einzuleiten
        uplurl  => [ 'upload_note_form'         ], # Formular für Dateiuploads
        delupl  => [ 'delete_upload_note_check' ], # Formular zum entfernen von Anhängen
        pageurl => [ 'show_notes_page'          ], # Seitenweiterschaltung
    );
    # Das folgende ist der Plugin-Helper-Aufruf, über den die Anzeige erfolgt.
    # Dieser Aufruf bekommt einen "WHERE"-Bestandteil und die Liste der entsprechenden Parameter.
    # Der Where-Bestandteil ist der für Anzeigen von Beiträgen.
    $c->show_posts($WhereS, $c->session->{userid});
}

# Hierüber wird die Filter aus dem Menü abgewickelt, was im 
# vorliegenden Fall direkt an die entsprechende Helper-Routine 
# weitergeleitet wird.
sub query { $_[0]->query_posts }

# Diese Funktion fügt neue Beiträge über die entsprechende
# Helper-Sub hinzu, was direkt aus der Übersicht heraus funktioniert.
# Als Argumente nimmt die Helper-Routine den Emfpänger (man selbst bei Notizen)
# sowie die ID des Themas (Topic), unter dem der Eintrag erscheinen soll
# (bleibt bei Notizen leer).
sub add { $_[0]->add_post($_[0]->session->{userid}, undef) }

# Diese Funktion erstellt ein Formular, über das Beiträge geändert werden können,
# "dourl" definiert hierbei die Route, über die die Änderung gespeichert wird.
# Bei Problemen bei der Änderung wird die Seite erneut angezeigt mit einer 
# entsprechenden Fehlermeldung. "heading" gibt auch hier die Überschrift
# an, falls gesetzt.
sub edit_form {
    my $c = shift;
    $c->stash(
        heading => 'Persönliche Notiz ändern',  # Überschrift für das Eingabeformular
        dourl   => $c->url_for('edit_note_do'), # Änderung am Beitrag speichern
    );
    # Dieser Helper erzeugt ein Formular zum Ändern des entsprechenden
    # Beitrages. Er bekommt den "WHERE"-Bestandteil zur Anzeige von Beiträgen
    # sowie die Liste für dessen Parameter.
    $c->edit_post_form($WhereS, $c->session->{userid});
}

# Diese Funktion führt Änderungen an Beiträgen durch, die in "edit_form"
# erstellt wurden. Sie leitet im Vorliegenden Fall einfach den Aufruf
# weiter an die entsprechende Helper-Sub und bekommt dabei den
# "WHERE"-Bestandteil und dessen Parameter für Datenmodifikationen mit.
sub edit_do { $_[0]->edit_post_do($WhereM, $_[0]->session->{userid}) }

# Diese Funktion leitet den Löschvorgang ein, indem sie nochmals um
# Bestätigung nachfragt. Wird die Bestätigung verweigert, dann leitet der
# zugehörige Helper auf "show" um, wird sie gewährt, wird die Route hinter
# "dourl" umgesetzt. Sie verwendet den "WHERE"-Bestandteil für die Beitragsanzeige
# mit passender Parameterliste.
sub delete_check {
    my $c = shift;
    $c->stash( 
        heading => 'Persönliche Notiz entfernen', # Überschrift für das Bestätigungsformular
        dourl   => $c->url_for('delete_note_do'), # Route zum tatsächlichen Löschen
    );
    $c->delete_post_check($WhereS, $c->session->{userid});
}

# Diese Funktion führt das Löschen über die Helper-Sub durch und verwendet
# dafür den "WHERE"-Bestandteil für Datenmodifikationen mit passender
# Parameterliste. Anschließend leitet sie auf "show" um.
sub delete_do { $_[0]->delete_post_do($WhereM, $_[0]->session->{userid}) }

# Diese Funktion stellt ein Dateiupload-Fomular für einen Beitrag zur Verfügung.
# Der Upload selber wird durch die Route hinter "dourl" umgesetzt. Sie verwendet
# den "WHERE"-Bestandteil für die Beitragsanzeige mit passender Parameterliste.
sub upload_form {
    my $c = shift;
    $c->stash(
        heading => 'Eine Datei zu einer persönlichen Notiz hochladen', # Überschrift für das Eingabeformular
        dourl   => $c->url_for('upload_note_do'), # Datei hochladen
    );
    # Dieser Helper erzeugt ein Formular zum Hochladen einer Datei zum entsprechenden
    # Beitrag. Er bekommt den "WHERE"-Bestandteil zur Anzeige von Beiträgen
    # sowie die Liste für dessen Parameter.
    $c->upload_post_form($WhereS, $c->session->{userid});
}

# Diese Funktion führt das Hochladen der gewählten Datei über die Helper-Sub 
# durch und verwendet dafür den "WHERE"-Bestandteil für Datenmodifikationen 
# mit passender Parameterliste. Anschließend leitet sie auf "show" um.
sub upload_do { $_[0]->upload_post_do($WhereM, $_[0]->session->{userid}) }

1;

