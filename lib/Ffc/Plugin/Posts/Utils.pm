package Ffc::Plugin::Posts; # Utils
use 5.18.0;
use strict; use warnings; use utf8;

###############################################################################
# Diese Hilfsfunktion setzt den Rahmen für alle Formulare innerhalb
# der Beitrags-Handling-Routinen. Es legt einige Stash-Variablen fest,
# die von allen Templates benötigt werden
sub _setup_stash {
    my $c = $_[0];
    my ( $cname, $act ) = ( $c->stash('controller'), $c->stash('action') );
    $c->stash(
        # Routenname für Abbrüche, der auf die Einstiegsseite der Beitragsübersicht verweißt.
        # Diese Route wird direkt als URL festgelegt, da sie keine weiteren Daten braucht.
        returl   => $c->url_for("show_$cname", page => 1),
        # Der folgende Routenname wird für den Download von Dateianhängen benötigt.
        # Hierbei handelt es sich auch um eine Array-Referenz, welche zusätzliche Daten
        # enthalten kann.
        downld   => "download_att_$cname",
        # Der folgende Eintrag beschreibt zusätzliche Parameter, die bei jeder URL
        # mit angegeben werden müssen.
        additional_params => [ $c->additional_params ],
    );
    $act ne 'search'
        and $c->stash(
           # Routenname für Filter-Suchen aus dem Menü heraus.
           # Diese Route wird direkt als URL festgelegt, da sie keine weiteren Daten braucht.
            queryurl => $c->url_for("query_$cname"),
        );
}

###############################################################################
# Zur Liste der Beiträge zurück kehren
sub _redirect_to_show   { $_[0]->redirect_to('show_'.$_[0]->stash('controller'), $_[0]->additional_params) }

###############################################################################
# Einen einzigen Beitrag ermitteln
sub _get_single_post {
    my $c = $_[0];
    my ( $wheres, @wherep ) = $c->where_select;

    my $postid = $c->param('postid');
    unless ( $postid and $postid =~ $Ffc::Digqr ) {
        $c->set_error('Konnte den gewünschten Beitrag nicht finden, da die Beitragsnummer irgendwie verloren ging');
        $c->show;
        return;
    }

    my $sql = qq~SELECT\n~
        .qq~p."id", uf."id", uf."name", ut."id", ut."name", p."topicid", p."posted", p."altered", p."cache", p."textdata"\n~
        .qq~FROM "posts" p\n~
        .qq~INNER JOIN "users" uf ON p."userfrom"=uf."id"\n~
        .qq~LEFT OUTER JOIN "users" ut ON p."userto"=ut."id"\n~
        .qq~WHERE p."id"=?~;
    $wheres and ( $sql .= qq~ AND $wheres~ );
    my $post = $c->dbh_selectall_arrayref( $sql, $postid, @wherep );

    # Eventuell wurde Text eingegeben, den wollen wir natürlich nicht übschreiben
    my $textdata = $c->param('textdata') // '';
    if ( $post and @$post ) {
        $textdata ||= $post->[0]->[9];
        $c->stash( post => $post->[0] );
        _get_attachements($c, $post, $wheres, @wherep) or return;
    }
    else {
        $c->set_warning('Keine passenden Beiträge gefunden');
        $c->stash( post => '' );
        return;
    }

    # Wir haben etwas passendes gefunden
    $c->stash( textdata => $textdata, postid   => $postid );
}

###############################################################################
# Alle Anhänge zu einem Beitrag finden
sub _get_attachements {
    my ( $c, $posts ) = @_;
    my ( $wheres, @wherep ) = $c->where_select;
    my $sql = qq~SELECT\n~
            . qq~a."id", a."postid", a."filename", a."isimage", a."inline",\n~
            . qq~CASE WHEN p."userfrom"=? THEN 1 ELSE 0 END AS "deleteable"\n~
            . qq~FROM "attachements" a\n~
            . qq~INNER JOIN "posts" p ON a."postid"=p."id"\n~
            .  q~WHERE a."postid" IN ('~
            . (join q~', '~, map { $_->[0] } @$posts)
            .  q~')~;
    $wheres and ( $sql .= " AND $wheres" );
    $sql .= qq~\nORDER BY a."filename", a."id"~;
    return $c->stash( attachements =>
        $c->dbh_selectall_arrayref( $sql, $c->session->{userid}, @wherep ) );
}

###############################################################################
# Bewertung ändern
sub _update_highscore {
    my ( $c, $up, $ajax ) = @_;

    # Den bestehenden Score holen
    my $score = $c->dbh_selectall_arrayref('SELECT "score", "userfrom" FROM "posts" WHERE "id"=?', $c->param('postid'));

    # Man selber darf seine eigenen Beiträge natürlich nicht bewerten, klar
    if ( $score->[0]->[1] == $c->session->{userid} ) {
        if ( $ajax ) {
            return $c->render( text => 'failed ownpost' );
        }
        else {
            $c->set_error_f( 'Eigene Beiträge können nicht bewertet werden' );
            return _redirect_to_show($c);
        }
    }
    $score = $score->[0]->[0];

    # Aufpassen, dass der Score nicht überläuft
    my $maxscore = $c->configdata->{maxscore};
    my $fail = 0;
        $up and $score >=  $maxscore and $fail = 1;
    not $up and $score <= -$maxscore and $fail = 1;
    if ( $fail ) {
        if ( $ajax ) {
            return $c->render( text => 'failed ' . ( $up ? 'max' : 'min' ) );
        }
        else {
            $c->set_error_f( 'Bewertung hat das ' . ( $up ? 'Maximum' : 'Minimum' ) . ' erreicht' );
            return _redirect_to_show($c);
        }
    }
    $score = $score + ( $up ? 1 : -1 );

    # Und ab damit in die Datenbank und weiter zur Seite
    $c->dbh_do('UPDATE "posts" SET "score"=? WHERE "id"=?', $score, $c->param('postid'));
    if ( $ajax ) {
        $c->render( text => $up ? 'up' : 'down' );
    }
    else {
        $c->set_info_f( 'Bewertung ' . ( $up ? 'erhöht' : 'veringert' ) );
        _redirect_to_show($c);
    }
}
# Bewertungs-Zugriff
sub _inc_highscore      { _update_highscore( $_[0], 1, 0 ) }
sub _dec_highscore      { _update_highscore( $_[0], 0, 0 ) }
sub _inc_highscore_ajax { _update_highscore( $_[0], 1, 1 ) }
sub _dec_highscore_ajax { _update_highscore( $_[0], 0, 1 ) }

###############################################################################
# Für das gelesen-Tracking für das Forum
sub _update_topic_lastid {
    my ( $c, $topicid, $summary, $zeroing ) = @_;
    # Alles auf Null zurück für ein Thema, wenn nichts angegeben wurde
    # (letzter Beitrag im Thema wurde gelöscht)
    $zeroing and return $c->dbh_do( << 'EOSQL', $topicid );
UPDATE "topics"
SET "summary"='', "lastid"=-1
WHERE "id"=?
EOSQL

    # Normal auf den aktuellsten Beitrag im Thema setzen
    $c->dbh_do( << 'EOSQL', $summary, $topicid, $topicid );
UPDATE "topics"
SET
  "summary"=?,
  "lastid"=(
    SELECT p."id"
    FROM "posts" p
    WHERE p."topicid" IS NOT NULL
      AND p."topicid"=?
      AND p."userto" IS NULL
    ORDER BY p."id" DESC
    LIMIT 1
  )
WHERE "id"=?
EOSQL
}

###############################################################################
# Für das gelesen-Tracking bei den Privatnachrichten
# (früher:  my ( $c, $userid, $userto ) = @_;)
sub _update_pmsgs_lastid {
    my ( $c, $userid, $userto ) = @_;
    $_[0]->dbh_do( << 'EOSQL', $_[1], $_[2], $_[1], $_[2] );
UPDATE "lastseenmsgs"
SET "lastseen"=(
    SELECT p."id"
    FROM "posts" p
    WHERE p."userfrom"=? AND p."userto"=?
    ORDER BY p."id" DESC
    LIMIT 1)
WHERE "userfromid"=? AND "userid"=?
EOSQL
}

1;
