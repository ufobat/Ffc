package Ffc::Plugin::Posts; # View
use 5.010;
use strict; use warnings; use utf8;

sub _pagination {
    my $c = shift;
    my $page = $c->param('page') // 1;
    my $postlimit = $c->configdata->{postlimit};
    $c->stash(page => $page);
    return $postlimit, ( $page - 1 ) * $postlimit;
}

sub _search_posts {
    my $c = shift;
    $c->session->{query} = $c->param('query');
    _show_posts($c);
}

sub _query_posts {
    my $c = shift;
    $c->session->{query} = $c->param('query');
    _redirect_to_show($c);
}

sub _get_show_sql {
    my ( $c, $wheres, $noorder ) = @_;
    my $query  = $c->session->{query};

    my $sql = qq~SELECT\n~
        .qq~p."id", uf."id", uf."name", ut."id", ut."name", p."topicid", ~
        .qq~datetime(p."posted",'localtime'), datetime(p."altered",'localtime'), p."cache", ~
        .qq~t."title"\n~
        .qq~FROM "posts" p\n~
        .qq~INNER JOIN "users" uf ON p."userfrom"=uf."id"\n~
        .qq~LEFT OUTER JOIN "users" ut ON p."userto"=ut."id"\n~
        .qq~LEFT OUTER JOIN "topics" t ON p."topicid"=t."id"\n~;
    if ( $wheres ) {
        $sql .= "WHERE $wheres\n"
             . ( $query ? qq~AND UPPER(p."textdata") LIKE UPPER(?)\n~ : "\n" );
    }
    elsif ( $query ) {
        $sql .= qq~WHERE UPPER(p."textdata") LIKE UPPER(?)\n~;
    }

    $sql .= 'ORDER BY p."id" DESC LIMIT ? OFFSET ?' unless $noorder;
    return $sql;
}

sub _show_posts {
    my $c = shift;
    my ( $wheres, @wherep ) = $c->where_select;
    my $query  = $c->session->{query};
    my $cname = $c->stash('controller');
    $c->stash( 
        query   => $query,
        dourl   => $c->url_for("add_${cname}", $c->additional_params ), # Neuen Beitrag erstellen
        editurl => "edit_${cname}_form",           # Formuar zum Bearbeiten von Beiträgen
        delurl  => "delete_${cname}_check",        # Formular, um den Löschvorgang einzuleiten
        uplurl  => "upload_${cname}_form",         # Formular für Dateiuploads
        delupl  => "delete_upload_${cname}_check", # Formular zum entfernen von Anhängen
        pageurl => "show_${cname}_page",           # Seitenweiterschaltung
    );
    _setup_stash($c);

    my $sql = $c->get_show_sql($wheres);
    my $posts = $c->dbh->selectall_arrayref(
        $sql, undef, @wherep, ( $query ? "\%$query\%" : () ), _pagination($c)
    );
    $c->stash(posts => $posts);

    $c->get_attachements($posts, $wheres, @wherep);

    return $c->render(template => 'posts');
}

1;

