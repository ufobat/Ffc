package Ffc::Plugin::Posts; # View
use 5.18.0;
use strict; use warnings; use utf8;

###############################################################################
# Seitenschaltungs-Hilfsfunktion, welche die zugehörigen Variablen passend setzt
sub _pagination {
    my $page = $_[0]->param('page') // 1;
    my $postlimit = $_[0]->session->{postlimit};
    $_[0]->stash(page => $page);
    return $postlimit, ( $page - 1 ) * $postlimit;
}

###############################################################################
# Suche mit Suchtext initialisieren
sub _search_posts {
    my $url = $_[0]->url_for('search_'.$_[0]->stash('controller').'_posts');
    $_[0]->stash( queryurl => $url, returl => $url );
    $_[0]->session->{query} = $_[0]->param('query');
    _show_posts($_[0]);
}

###############################################################################
# Den Suchtext in der Session speichern
sub _query_posts {
    $_[0]->session->{query} = $_[0]->param('query');
    _show_posts($_[0]);
}

###############################################################################
# Das SQL-Statement für die Beitragsabfrage zusammen basteln
# (wird auch für Readlater gebraucht, dort ist es aber über einen Helper erreichbar)
sub _get_show_sql {
    my ( $c, $wheres, $noorder, $postid, $groupbys, $nolimit, $noquery, $orderbys, $reverseorder, $new ) = @_;
    my $query = $noquery ? '' : $c->session->{query};

    # Das ist die Basis, die gleichzeitig die Rückgabe-Reihenfolge festlegt
    my $sql = << 'EOSQL';
SELECT
    p."id", uf."id", uf."name", ut."id", ut."name", p."topicid",
    datetime(p."posted",'localtime'), datetime(p."altered",'localtime'), p."cache",
    t."title", p."score", p."blocked", r."postid"
FROM "posts" p
INNER JOIN "users" uf ON p."userfrom"=uf."id"
LEFT OUTER JOIN "users" ut ON p."userto"=ut."id"
LEFT OUTER JOIN "topics" t ON p."topicid"=t."id"
LEFT OUTER JOIN "readlater" r ON r."postid"=p."id" AND "userid"=?
EOSQL

    # Kommen den Einschränkungen?
    ( $wheres or $query or $postid or $new ) and ( $sql .= 'WHERE ' );
    if ( $wheres ){
        $sql .= "$wheres\n";
        $query and ( $sql .= 'AND ' );
    }

    # Es wird eine Textsuche durchgeführt
    $query and ( $sql .= qq~UPPER(p."textdata") LIKE UPPER(?)\n~ );
    
    # Es geht um einen einzigen bestimmten Beitrag
    if ( $postid ) {
        ( $wheres or $query ) and ( $sql .= q~AND ~ );
        $sql .= qq~p."id"=?\n~;
    }

    # Nur die neuen Beiträge
    if ( $new ) {
        ( $wheres or $query or $postid ) and ( $sql .= q~AND ~ );
        $sql .= q~p."id" > ?~;
    }

    # Soll gruppiert werden
    $groupbys and ( $sql .= "GROUP BY $groupbys\n" );

    # Soll die Sortierung ausgeschalten werden
    $noorder or (
        $sql .= 'ORDER BY ' . ( $orderbys || '' )
             . ' p."id" ' . ( $reverseorder ? 'ASC' : 'DESC' ) . "\n" );

    # Anzahl-Begrenzung
    $nolimit or ( $sql .= "LIMIT ? OFFSET ?\n" );

    return $sql;
}

###############################################################################
# Eine Liste von Beiträgen anzeigen
sub _show_posts {
    my ( $c, $queryurl, $ajax, $new ) = @_[0,1,2,3];
    my ( $wheres, @wherep ) = $c->where_select;
    my ( $query, $postid, $cname ) = ( $c->session->{query}, $c->param('postid'), $c->stash('controller') );
    $c->stash( query => $query );

    # Hier werden verschiedene Routen-Namen gesetzt, die später im Template im Bedarsfall verwendet werden
    if ( $c->stash('action') ne 'search' ) {
        $c->stash(
            dourl        => $c->url_for("add_${cname}", $c->additional_params ), # Neuen Beitrag erstellen
            # Die hier werden nicht immer angezeigt, 
            # aber wenn, dann müssen die jeweils dynamisch mit der Beitrags-ID erzeugt werden
            editurl      => "edit_${cname}_form",                                # Formular zum Bearbeiten von Beiträgen
            delurl       => "delete_${cname}_check",                             # Formular, um den Löschvorgang einzuleiten
            uplurl       => "upload_${cname}_form",                              # Formular für Dateiuploads
            delupl       => "delete_upload_${cname}_check",                      # Formular zum entfernen von Anhängen
            # ... oder eben mit der Seitenzahl, auf die geblättert werden soll
            pageurl      => "show_${cname}_page",                                # URL für die Seitenweiterschaltung
            fetchnewurl  => $c->url_for("fetch_new_${cname}"),                   # URL für AJAX - Neue Beiträge
        );
        _setup_stash($c);
    }
    else {
        $c->stash( 
            pageurl      => "search_${cname}_posts_page",
            fetchnewurl  => $c->url_for("fetch_new_${cname}"),
        );
        # Hier muss setup_stash vor dem nächsten Stash-Schritt kommen, weil
        # in dem folgenden Schritt werden einige Variablen aus setup_stash wieder überschrieben, is halt so
        _setup_stash($c);
        $c->stash( 
            additional_params => [],
            returl            => $c->url_for("search_${cname}_posts"),
        );
    }

    # Suchanfrage für das Seitenrendering weiterreichen
    $queryurl and $c->stash(queryurl => $queryurl);

    # Und hier holen wir uns unsere schöne SQL-Abfrage aus der anderen Subroutine,
    # führen diese aus und legen die im Stash für das Seitenrendering ab ...
    # zusätzlich mit den anderen notwendigen Daten (counting)
    ### $c, $wheres, $noorder, $postid, $groupbys, $nolimit, $noquery, $orderbys, $reverseorder, $new
    my $sql = _get_show_sql($c, $wheres, undef, $postid, undef, undef, undef, undef, undef, $new);
    my $posts = $c->dbh_selectall_arrayref(
        $sql, 
        $c->session->{userid}, 
        @wherep, 
        ( $query ? "\%$query\%" : () ), 
        ($postid || ()), 
        ( $new   ? $c->stash('lastseen') : ()),
        $c->pagination()
    );
    $c->stash(posts => $posts);
    $c->counting;

    # Bei einer Suchanfrage wird das passende Such-Ergebnis-Formular angezeigt
    $c->stash('action') eq 'search' and return $c->render(template => 'search');

    # Für alles andere benötigen wir natürlich noch die Anhängsel zu den Beiträgen
    $c->get_attachements($posts, $wheres, @wherep);

    # Eine komplette Seite für einen Beitrag oder mehrere Beiträge ausgeben
    $c->render(template => $postid ? 'display': 'posts')
        unless $ajax;

    # JSON-Liste der Beiträge zurück geben
}

###############################################################################
# Neue Beiträge als Ajax-Liste abholen
sub _fetch_new_posts { _show_posts( $_[0], 1, 1 ) }

###############################################################################
# Die Anzahl der auf einer Seite angezeigten Beiträge einstellen
sub _set_post_postlimit {
    my $c = $_[0];
    my $postlimit = $c->param('postlimit');
    
    # Es gibt Grenzen, was eingetragen werden darf
    unless ( $postlimit > 0 and $postlimit < 128 ) {
        $c->set_error_f('Die Anzahl der auf einer Seite in der Liste angezeigten Beiträge muss eine ganze Zahl kleiner 128 sein.');
        return _redirect_to_show($c);
    }

    # Hier wird die Einstellung in die Session übernommen und gleichzeitig im Cookie
    # Benutzerübergreifend als clientseitig verfügbar abgelegt
    $c->session->{limits}->{$c->session->{userid}}->{postlimit} = $c->session->{postlimit} = $postlimit;

    # Änderung aktiv
    $c->set_info_f("Anzahl der auf einer Seite der Liste angezeigten Beiträge auf $postlimit geändert.");
    return _redirect_to_show($c);
}

1;
