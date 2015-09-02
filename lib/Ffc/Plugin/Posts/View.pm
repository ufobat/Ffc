package Ffc::Plugin::Posts; # View
use 5.010;
use strict; use warnings; use utf8;

sub _pagination {
    my $c = shift;
    my $page = $c->param('page') // 1;
    my $postlimit = $c->session->{postlimit};
    $c->stash(page => $page);
    return $postlimit, ( $page - 1 ) * $postlimit;
}

sub _search_posts {
    my $c = shift;
    my $cname = $c->stash('controller');
    $c->stash( 
        queryurl => $c->url_for("search_${cname}_posts"),
        returl   => $c->url_for("search_${cname}_posts"),
    );
    $c->counting;
    if ( my $q = $c->param('query') ) {
        $c->session->{query} = $q;
    }
    _show_posts($c);
}

sub _query_posts {
    my $c = shift;
    $c->session->{query} = $c->param('query');
    $c->show;
}

sub _get_show_sql {
    my ( $c, $wheres, $noorder, $postid, $groupbys, $nolimit, $noquery, $orderbys, $reverseorder ) = @_;
    my $query  = $noquery ? '' : $c->session->{query};

    my $sql = qq~SELECT\n~
        .qq~p."id", uf."id", uf."name", ut."id", ut."name", p."topicid", ~
        .qq~datetime(p."posted",'localtime'), datetime(p."altered",'localtime'), p."cache", ~
        .qq~t."title", p."score"\n~
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
    if ( $postid ) {
        if ( $wheres or $query ) {
            $sql .= q~AND ~;
        }
        else {
            $sql .= q~WHERE ~;
        }
        $sql .= qq~p."id"=?\n~;
    }

    $sql .= "GROUP BY $groupbys\n" if $groupbys;
    unless ( $noorder ) {
        $sql .= 'ORDER BY';
        $sql .= " $orderbys," if $orderbys;
        $sql .= ' p."id" ' . ( $reverseorder ? 'ASC' : 'DESC' ) . "\n";
    }
    $sql .= "LIMIT ? OFFSET ?\n" unless $nolimit;
    return $sql;
}

sub _show_posts {
    my $c = shift;
    my $queryurl = shift;
    my ( $wheres, @wherep ) = $c->where_select;
    my $query  = $c->session->{query};
    my $postid = $c->param('postid');
    my $cname = $c->stash('controller');
    $c->stash( query => $query );
    if ( $c->stash('action') ne 'search' ) {
        $c->stash(
            dourl   => $c->url_for("add_${cname}", $c->additional_params ), # Neuen Beitrag erstellen
            editurl => "edit_${cname}_form",           # Formuar zum Bearbeiten von Beiträgen
            delurl  => "delete_${cname}_check",        # Formular, um den Löschvorgang einzuleiten
            uplurl  => "upload_${cname}_form",         # Formular für Dateiuploads
            delupl  => "delete_upload_${cname}_check", # Formular zum entfernen von Anhängen
            pageurl => "show_${cname}_page",
        );
        _setup_stash($c);
    }
    else {
        $c->stash( pageurl => "search_${cname}_posts_page" );
        _setup_stash($c);
        $c->stash( 
            additional_params => [],
            returl            => $c->url_for("search_${cname}_posts"),
        );
    }
    $c->stash(queryurl => $queryurl) if $queryurl;
    my $sql = $c->get_show_sql($wheres, undef, $postid);
    my $posts = $c->dbh_selectall_arrayref(
        $sql, @wherep, ( $query ? "\%$query\%" : () ), ($postid || ()),  _pagination($c)
    );
    $c->stash(posts => $posts);

    if ( $c->stash('action') eq 'search' ) {
        $c->render(template => 'search');
    }
    else {
        $c->get_attachements($posts, $wheres, @wherep);
        if ( $postid ) {
            $c->render(template => 'display');
        }
        else {
            $c->render(template => 'posts');
        }
    }
}

sub _set_post_postlimit {
    my $c = $_[0];
    my $postlimit = $c->param('postlimit');
    unless ( $postlimit =~ $Ffc::Digqr and $postlimit > 0 and $postlimit < 128 ) {
        $c->set_error_f('Die Anzahl der auf einer Seite in der Liste angezeigten Beiträge muss eine ganze Zahl kleiner 128 sein.');
        return _redirect_to_show($c);
    }
    $c->session->{postlimit} = $postlimit;
    $c->dbh_do('UPDATE "users" SET "postlimit"=? WHERE "id"=?',
        $postlimit, $c->session->{userid});
    $c->set_info_f("Anzahl der auf einer Seite der Liste angezeigten Beiträge auf $postlimit geändert.");
    return _redirect_to_show($c);
}

1;

