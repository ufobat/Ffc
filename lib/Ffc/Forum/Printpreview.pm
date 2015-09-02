package Ffc::Forum;
use strict; use warnings; use utf8;

sub printpreview {
    my ( $c ) = @_;
    my $sql .= << 'EOSQL'; 
SELECT
    p."id", uf."id", uf."name", null, null, p."topicid", 
    datetime(p."posted",'localtime'), datetime(p."altered",'localtime'),
    p."cache", t."title", p."score"
FROM "posts" p
INNER JOIN "users" uf ON p."userfrom"=uf."id"
INNER JOIN "topics" t ON p."topicid"=t."id"
LEFT OUTER JOIN "lastseenforum" l ON l."userid"=? AND l."topicid"=p."topicid" 
WHERE 0=COALESCE(l."ignore",0)
ORDER BY COALESCE(l."pin", 0) DESC, t."lastid" DESC, t."id" DESC
LIMIT ?
EOSQL
    $c->stash( posts => $c->dbh_selectall_arrayref(
        $sql, $c->session->{userid}, $c->session->{postlimit} ) );
    $c->stash( users => [1]);
    $c->render(template => 'printpreview');
}

1;

