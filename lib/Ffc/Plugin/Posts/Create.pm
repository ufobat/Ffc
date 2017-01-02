package Ffc::Plugin::Posts; # Create
use 5.18.0;
use strict; use warnings; use utf8;

###############################################################################
# Einen Beitrag hinzu fügen
sub _add_post {
    my ( $c, $userto, $topicid, $noinfo, $noredirect ) = @_;
    my ( $text, $userid ) = ( $c->param('textdata'), $c->session->{userid} );

    # Eingabeprüfungen
    if ( !defined($text) or (2 > length $text) ) {
        $c->stash(textdata => $text);
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen)');
        return $c->show;
    }
    my $cache = $c->pre_format($text, undef, $c->configdata->{inlineimage});
    if ( !defined($cache) or (2 > length $cache) ) {
        $c->stash(textdata => $text);
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen ohne Auszeichnungen)');
        return $c->show;
    }

    my $controller = $c->stash('controller');
    
    # Spezialbehandlung "Forum" - Gibt es neue Beiträge zwischenzeitlich?
    if ( $controller eq 'forum' and $topicid ) {
        my $sql = << 'EOSQL';
SELECT t.lastid, COALESCE(l.lastseen,0)
FROM topics t
LEFT OUTER JOIN lastseenforum l ON  l.topicid=t.id
WHERE l.userid=? AND t.id=?
GROUP BY t.id
EOSQL
        my $r = $c->dbh_selectall_arrayref( $sql, $userid, $topicid );
        if ( @$r and $r->[0]->[0] > $r->[0]->[1] ) {
            $c->stash(textdata => $text);
            $c->set_warning('Es wurde zwischenzeitlich ein neuer Beitrag erstellt, bitte prüfen!');
            return $c->show;
        }
    }

    # Neuen Beitrag in die Datenbank schreiben
    $c->dbh_do( << 'EOSQL', 
INSERT INTO "posts"
    ("userfrom", "userto", "topicid", "textdata", "cache")
VALUES 
    (?,?,?,?,?)
EOSQL
        $userid, $userto, $topicid, $text, $cache
    );

    # Ermitteln der neuen ID für diesen neuen Beitrag
    my $sql = << 'EOSQL',
SELECT "id" FROM "posts"
WHERE "userfrom"=?
EOSQL
    my @params = ( $userid );

    # Jeweilige Sonderbehandlungen zur Einschränkung des Suchkreises
    if ( $controller eq 'forum' ) {
        # Topic-Eintrag auf aktuellsten Beitrag setzen
        $topicid and
            _update_topic_lastid($c, $topicid, $c->format_short($text) // '');
        $sql .= ' AND "topicid"=? AND "userto" IS NULL';
        push @params, $topicid;
    }
    elsif ( $controller eq 'pmsgs' ) {
        # Privatnachrichten-Eintrag auf die aktuellste Nachricht setzen
        #$userto and
        #    _update_pmsgs_lastid( $c, $userid, $userto );
        $sql .= ' AND "userto"=? AND "topicid" IS NULL';
        push @params, $userto;
    }
    elsif ( $controller eq 'notes' ) {
        $sql .= ' AND "userto"="userfrom" AND "topicid" IS NULL';
    }
    $sql .= << 'EOSQL';

ORDER BY "id" DESC
LIMIT 1;
EOSQL
    my $r = $c->dbh_selectall_arrayref($sql, @params);
    
    # Einfache Prüfung, ob alles passte, und dann raus mit der Webseite
    unless ( @$r and $r->[0]->[0] ) {
        $c->set_error('Konnte den neuen Beitrag nicht finden in der Datenbank, irgend etwas ging schief');
        return $c->show;
    }

    if ( $controller eq 'forum' ) {
        $c->set_lastseenforum($userid, $topicid);
    }
    $c->param(postid => $r->[0]->[0]);
    
    # Attachements? - aber ohne meckern, wenn nix kommt
    $c->upload_post_do(1,1);

    $c->set_info_f('Ein neuer Beitrag wurde erstellt') unless $noinfo;
    _redirect_to_show($c) unless $noredirect;
}

###############################################################################
# Formular zum ändern eines einzelnen Beitrags zusammen stellen
sub _edit_post_form {
    my $c = shift;
    $c->stash( dourl => $c->url_for('edit_'.$c->stash('controller').'_do', $c->additional_params) );
    _setup_stash($c);
    unless ( _get_single_post($c, @_) ) {
        $c->set_error_f('Konnte keinen passenden Beitrag zum Ändern finden');
        return _redirect_to_show($c);
    }
    $c->counting;
    $c->render( template => 'edit_form' );
}

###############################################################################
# Einen einzelnen Beitrag ändern
sub _edit_post_do {
    my $c = $_[0];
    my ( $wheres, @wherep ) = $c->where_modify;
    my ( $postid, $topicid, $text ) = ( $c->param('postid'), $c->param('topicid'), $c->param('textdata') );

    # Texteingabe überprüfen
    if ( !defined($text) or (2 > length $text) ) {
        $c->stash(textdata => $text);
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen)');
        return $c->edit_form;
    }
    my $cache = $c->pre_format($text, undef, $c->configdata->{inlineimage});
    if ( !defined($cache) or (2 > length $cache) ) {
        $c->stash(textdata => $text);
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen ohne Auszeichnungen)');
        return $c->edit_form;
    }

    # Es sollte schon einen Eintrag zum Ändern geben
    my $sql = qq~ SELECT COUNT("id")\nFROM "posts"\n~
            . qq~ WHERE "id"=? AND "blocked"=0~;
    $sql .= qq~ AND $wheres~ if $wheres;
    if ( not $c->dbh_selectall_arrayref( $sql, $postid, @wherep )->[0]->[0] ) {
        $c->set_error_f('Kein passender Beitrag zum ändern gefunden');
        return _redirect_to_show($c);
    }

    # Das Update auf den Datensatz durchführen
    $sql = qq~UPDATE "posts"\n~
            . qq~SET "textdata"=?, "cache"=?, "altered"=current_timestamp\n~
            . qq~WHERE "id"=? AND "blocked"=0~;
    $wheres and $sql .= qq~ AND $wheres~;
    $c->dbh_do( $sql, $text, $cache, $postid, @wherep );

    # Im Forenteil muss noch die Themenliste für die entsprechende Topic auf Stand 
    # (Zusammenfassung des aktuellsten Beitrags, nicht notwendigerweise der bearbeitete)
    # gebracht werden
    if ( $c->stash('controller') eq 'forum' ) {
        $sql = 'SELECT "id", "textdata" FROM "posts" WHERE "topicid"=? ORDER BY "id" DESC LIMIT 1';
        my $text = $c->dbh_selectall_arrayref($sql, $topicid);
        if ( @$text and $text->[0]->[0] == $postid ) {
            $sql = q~UPDATE "topics" SET "summary"=? WHERE "id"=?~;
            $c->dbh_do( $sql, $c->format_short($text->[0]->[1]) // '', $topicid );
        }
    }

    # Attachements? - aber ohne meckern, wenn nix kommt
    $c->upload_post_do(1,1);

    # Und raus mit der Webseite
    $c->set_info_f('Der Beitrag wurde geändert');
    _redirect_to_show($c);
}

1;
