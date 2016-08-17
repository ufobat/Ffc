package Ffc::Plugin::Posts; # Utils
use 5.18.0;
use strict; use warnings; use utf8;


# Diese Hilfsfunktion setzt den Rahmen für alle Formulare innerhalb
# der Beitrags-Handling-Routinen. Es legt einige Stash-Variablen fest,
# die von allen Templates benötigt werden
sub _setup_stash {
    my $c = shift;
    my $cname = $c->stash('controller');
    my $act = $c->stash('action');
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
    $c->stash(
        # Routenname für Filter-Suchen aus dem Menü heraus.
        # Diese Route wird direkt als URL festgelegt, da sie keine weiteren Daten braucht.
        queryurl => $c->url_for("query_$cname"),
    ) if $act ne 'search';
}

sub _redirect_to_show {
    $_[0]->redirect_to('show_'.$_[0]->stash('controller'), $_[0]->additional_params)
}

sub _redirect_to_search {
    $_[0]->redirect_to('search_'.$_[0]->stash('controller').'_posts')
}

sub _get_single_post {
    my $c = shift;
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
    $sql .= qq~ AND $wheres~ if $wheres;
    my $post = $c->dbh_selectall_arrayref( $sql, $postid, @wherep );
    #use Data::Dumper; warn Dumper $sql, [$postid, @wherep], $post;
    my $textdata = $c->param('textdata') // '';
    if ( $post and @$post ) {
        $textdata = $post->[0]->[9] unless $textdata;
        $c->stash( post => $post->[0] );
        return unless _get_attachements($c, $post, $wheres, @wherep);
    }
    else {
        $c->set_warning('Keine passenden Beiträge gefunden');
        $c->stash( post => '' );
        return;
    }

    $c->stash( textdata => $textdata );
    $c->stash( postid   => $postid );
}

sub _get_attachements {
    my $c = shift;
    my ( $wheres, @wherep ) = $c->where_select;
    my $posts = shift;
    my $sql = qq~SELECT\n~
            . qq~a."id", a."postid", a."filename", a."isimage", a."inline",\n~
            . qq~CASE WHEN p."userfrom"=? THEN 1 ELSE 0 END AS "deleteable"\n~
            . qq~FROM "attachements" a\n~
            . qq~INNER JOIN "posts" p ON a."postid"=p."id"\n~
            .  q~WHERE a."postid" IN ('~
            . (join q~', '~, map { $_->[0] } @$posts)
            .  q~')~;
    $sql .= " AND $wheres" if $wheres;
    $sql .= qq~\nORDER BY a."filename", a."id"~;
    return $c->stash( attachements =>
        $c->dbh_selectall_arrayref( $sql, $c->session->{userid}, @wherep ) );
}

sub _update_highscore {
    my ( $c, $up ) = @_;
    my $score = $c->dbh_selectall_arrayref('SELECT "score", "userfrom" FROM "posts" WHERE "id"=?', $c->param('postid'));
    return _redirect_to_show($c)
        if $score->[0]->[1] eq $c->session->{userid};
    $score = $score->[0]->[0] || 0;
    my $maxscore = $c->configdata->{maxscore};
    if ( $up ) {
        $score++;
        $score = $maxscore if $score > $maxscore;
    }
    else {
        $score--;
        $score = -$maxscore if $score < -$maxscore;
    }
    $c->dbh_do('UPDATE "posts" SET "score"=? WHERE "id"=?', $score, $c->param('postid'));
    $c->set_info_f( 'Bewertung ' . ( $up ? 'erhöht' : 'veringert' ) );
    _redirect_to_show($c);
}
sub _inc_highscore { _update_highscore( $_[0], 1 ) }
sub _dec_highscore { _update_highscore( $_[0], 0 ) }

sub _update_topic_lastid {
    my ( $c, $topicid, $summary, $zeroing ) = @_;
    if ( $zeroing ) {
        $c->dbh_do( << 'EOSQL', $topicid );
UPDATE "topics" 
SET "summary"='', "lastid"=-1
WHERE "id"=?
EOSQL
    }
    else {
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
}

sub _update_pmsgs_lastid {
    my ( $c, $userid, $userto ) = @_;
    $c->dbh_do( << 'EOSQL', $userid, $userto, $userid, $userto );
UPDATE "lastseenmsgs"
SET "lastid"=(
    SELECT p."id"
    FROM "posts" p
    WHERE p."userfrom"=? AND p."userto"=?
    ORDER BY p."id" DESC
    LIMIT 1)
WHERE "userfromid"=? AND "userid"=?
EOSQL
        

}

1;

