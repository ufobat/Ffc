package Ffc::Forum;
use strict; use warnings; use utf8;

sub printpreview {
    my ( $c ) = @_;
    my $days = '-' . ( $c->session->{printpreviewdays} // 7 ) . ' days';
    my $sql .= << "EOSQL"; 
SELECT
    p."id", uf."id", uf."name", null, null, p."topicid", 
    datetime(p."posted",'localtime'), datetime(p."altered",'localtime'),
    p."cache", t."title", p."score", COALESCE(l."lastseen", -1)
FROM "topics" t
INNER JOIN "posts" p ON p."topicid"=t."id" AND date(p."posted", 'localtime') >= date('now', 'localtime', '$days')
INNER JOIN "users" uf ON p."userfrom"=uf."id"
LEFT OUTER JOIN "lastseenforum" l ON l."userid"=? AND l."topicid"=p."topicid" 
WHERE 0=COALESCE(l."ignore",0)
ORDER BY COALESCE(l."pin", 0) DESC, t."lastid" DESC, t."id" DESC
EOSQL
    $c->app->helper( set_lastseen => \&set_lastseen );
    $c->stash( posts => $c->dbh_selectall_arrayref($sql, $c->session->{userid}) );
    $c->stash( users => [1]);
    $c->render(template => 'printpreview');
}

sub set_period {
    my ( $c ) = @_;
    my $days = $c->session->{printpreviewdays} = $c->param('days');
    $c->dbh_do(
        'UPDATE "users" SET "printpreviewdays"=? WHERE "id"=?',
            $days, $c->session->{userid} );
    $c->redirect_to('printpreview');
}

1;

