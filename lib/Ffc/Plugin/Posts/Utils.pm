package Ffc::Plugin::Posts; # Utils
use 5.010;
use strict; use warnings; use utf8;


# Diese Hilfsfunktion setzt den Rahmen für alle Formulare innerhalb
# der Beitrags-Handling-Routinen. Es legt einige Stash-Variablen fest,
# die von allen Templates benötigt werden
sub _setup_stash {
    my $c = shift;
    my $cname = $c->stash('controller');
    $c->stash( 
        # Routenname für Abbrüche, der auf die Einstiegsseite der Beitragsübersicht verweißt.
        # Diese Route wird direkt als URL festgelegt, da sie keine weiteren Daten braucht.
        returl   => $c->url_for("show_$cname", page => 1),
        # Routenname für Filter-Suchen aus dem Menü heraus.
        # Diese Route wird direkt als URL festgelegt, da sie keine weiteren Daten braucht.
        queryurl => $c->url_for("query_$cname"),
        # Der folgende Routenname wird für den Download von Dateianhängen benötigt.
        # Hierbei handelt es sich auch um eine Array-Referenz, welche zusätzliche Daten
        # enthalten kann.
        downld   => "download_att_$cname",
        # Der folgende Eintrag beschreibt zusätzliche Parameter, die bei jeder URL
        # mit angegeben werden müssen.
        additional_params => [ $c->additional_params ],
    );
}

sub _redirect_to_show {
    $_[0]->redirect_to('show_'.$_[0]->stash('controller'), $_[0]->additional_params)
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
    my $post = $c->dbh->selectall_arrayref( $sql, undef, $postid, @wherep );
    my $textdata = $c->param('textdata') // '';
    if ( $post and @$post ) {
        $textdata = $post->[0]->[9] unless $textdata;
        $c->stash( post => $post->[0] );
        return unless _get_attachements($c, $post, $wheres, @wherep);
    }
    else {
        $c->set_warning('Keine passenden Beiträge gefunden');
        $c->stash( post => '' );
    }

    $c->stash( textdata => $textdata );
    $c->stash( postid   => $postid );
}

sub _get_attachements {
    my $c = shift;
    my ( $wheres, @wherep ) = $c->where_select;
    my $posts = shift;
    my $sql = qq~SELECT\n~
            . qq~a."id", a."postid", a."filename",\n~
            . qq~CASE WHEN p."userfrom"=? THEN 1 ELSE 0 END AS "deleteable"\n~
            . qq~FROM "attachements" a\n~
            . qq~INNER JOIN "posts" p ON a."postid"=p."id"\n~
            .  q~WHERE a."postid" IN ('~
            . (join q~', '~, map { $_->[0] } @$posts)
            .  q~')~;
    $sql .= " AND $wheres" if $wheres;
    $sql .= qq~\nORDER BY a."filename", a."id"~;
    return $c->stash( attachements =>
        $c->dbh->selectall_arrayref( $sql, undef, $c->session->{userid}, @wherep ) );
}

1;

