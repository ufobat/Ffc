package Ffc::Plugin::Posts;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Plugin';

use strict;
use warnings;
use 5.010;

sub register {
    my ( $self, $app ) = @_;
    $app->helper( show_posts        => \&_show_posts        );
    $app->helper( query_posts       => \&_query_posts       );
    $app->helper( add_post          => \&_add_post          );
    $app->helper( edit_post_form    => \&_edit_post_form    );
    $app->helper( edit_post_do      => \&_edit_post_do      );
    $app->helper( delete_post_check => \&_delete_post_check );
    $app->helper( delete_post_do    => \&_delete_post_do    );
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
    $c->show;
}

sub _show_posts {
    my $c = shift;
    my $wheres = shift;
    my @wherep = @_;
    my $query  = $c->session->{query};
    $query = "\%$query\%" if $query;
    $c->setup_stash;

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

    return $c->render(template => 'posts');
}

sub _add_post {
    my ( $c, $userto, $topicid ) = @_;
    my $text = $c->param('textdata');
    if ( !defined($text) or (2 > length $text) ) {
        $c->stash(textdata => $text);
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen)');
        return $c->show;
    }
    $c->dbh->do( << 'EOSQL', undef,
INSERT INTO "posts"
    ("userfrom", "userto", "topicid", "textdata", "cache")
VALUES 
    (?,?,?,?,?)
EOSQL
        $c->session->{userid}, $userto, $topicid, $text, $c->pre_format($text)
    );

    $c->show;
}

sub _get_single_post {
    my $c = shift;
    my $wheres = shift;
    my @wherep = @_;

    my $postid = $c->param('postid');

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
    }
    else {
        $c->set_warning('Keine passenden Beiträge gefunden');
        $c->stash( post => '' );
    }

    $c->stash( textdata => $textdata );
    $c->stash( postid   => $postid );
}

sub _edit_post_form {
    my $c = shift;
    $c->setup_stash;
    _get_single_post($c, @_);
    $c->render( template => 'edit_form' );
}

sub _edit_post_do {
    my $c = shift;
    my $wheres = shift;
    my @wherep = @_;
    my $postid = $c->param('postid');
    my $text = $c->param('textdata');
    unless ( $postid and $postid =~ $Ffc::Digqr ) {
        $c->set_error('Konnte den Beitrag nicht ändern, da die Beitragsnummer irgendwie verloren ging');
        $c->stash(textdata => $text);
        return $c->show;
    }
    if ( !defined($text) or (2 > length $text) ) {
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen)');
        return $c->edit_form;
    }

    my $sql = qq~UPDATE "posts"\n~
            . qq~SET "textdata"=?, "cache"=?, "altered"=current_timestamp\n~
            . qq~WHERE "id"=?~;
    $sql .= qq~ AND $wheres~ if $wheres;
    $c->dbh->do( $sql, undef, $text, $c->pre_format($text), $postid, @wherep );
    $c->set_info('Beitrag geändert');
    return $c->show;
}

sub _delete_post_check {
    my $c = shift;
    $c->setup_stash;
    _get_single_post($c, @_);
    $c->render( template => 'delete_check' );
}

sub _delete_post_do {
    my $c = shift;
    my $wheres = shift;
    my @wherep = @_;
    my $postid = $c->param('postid');
    unless ( $postid and $postid =~ $Ffc::Digqr ) {
        $c->set_error('Konnte den Beitrag nicht ändern, da die Beitragsnummer irgendwie verloren ging');
        return $c->show();
    }
    my $sql = q~DELETE FROM "posts" WHERE "id"=?~;
    $sql .= qq~ AND $wheres~ if $wheres;

    $c->dbh->do( $sql, undef, $postid, @wherep );
    $c->set_info('Beitrag entfernt');
    $c->show();
}

1;

