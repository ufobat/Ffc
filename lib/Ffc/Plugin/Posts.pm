package Ffc::Plugin::Posts;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Plugin';

use strict;
use warnings;
use 5.010;

sub register {
    my ( $self, $app ) = @_;
    $app->helper( show_posts  => \&_show_posts  );
    $app->helper( query_posts => \&_query_posts );
    $app->helper( add_post    => \&_add_post    );
    return $self;
}

sub _pagination {
    my $c = shift;
    my $page = $c->param('page') // 1;
    my $postlimit = $c->configdata->{postlimit};
    $c->stash(page => $page);
    return $postlimit, ( $page - 1 ) * $postlimit;
}

sub _query_posts {
    my $c = shift;
    $c->session->{query} = $c->param('query');
    return $c;
}

sub _show_posts {
    my $c = shift;
    my $wheres = shift;
    my @wherep = @_;
    my $query  = $c->session->{query};
    $query = "\%$query\%" if $query;

    my $sql = qq~SELECT\n~
        .qq~p."id", uf."id", uf."name", ut."id", ut."name", p."topicid", p."posted", p."altered", p."cache"\n~
        .qq~FROM "posts" p\n~
        .qq~INNER JOIN "users" uf ON p."userfrom"=uf."id"\n~
        .qq~LEFT OUTER JOIN "users" ut ON p."userto"=ut."id"\n~;
    if ( $wheres ) {
        $sql .= "WHERE $wheres\n"
             . ( $query ? qq~AND UPPER(p."textdata") LIKE UPPER(?)\n~ : "\n" );
    }
    elsif ( $query ) {
        $sql .= qq~WHERE UPPER(p."textdata") LIKE UPPER(?)\n~;
    }
    $sql .= 'ORDER BY p."id" DESC LIMIT ? OFFSET ?';
    $c->stash(posts => $c->dbh->selectall_arrayref(
        $sql, undef, @wherep, ( $query || () ), _pagination($c)
    ));
    $c->render(template => 'posts');
}

sub _add_post {
    my ( $c, $userto, $topicid ) = @_;
    my $text = $c->param('textdata');
    if ( !defined($text) or (2 > length $text) ) {
        $c->stash(textdata => $text);
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen)');
        return;
    }
    $c->dbh->do( << 'EOSQL', undef,
INSERT INTO "posts"
    ("userfrom", "userto", "topicid", "textdata", "cache")
VALUES 
    (?,?,?,?,?)
EOSQL
        $c->session->{userid}, $userto, $topicid, $text, $c->pre_format($text)
    );
}

1;

