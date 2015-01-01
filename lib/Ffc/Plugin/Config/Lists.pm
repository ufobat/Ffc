package Ffc::Plugin::Config;
use 5.010;
use strict; use warnings; use utf8;

sub _newpostcount {
    my $uid = $_[0]->session->{userid};
    return $_[0]->dbh->selectall_arrayref(
        'SELECT COUNT(p."id")
        FROM "posts" p
        INNER JOIN "topics" t on t."id"=p."topicid"
        LEFT OUTER JOIN "lastseenforum" l ON l."topicid"=p."topicid" AND l."userid"=?
        WHERE p."userto" IS NULL AND p."userfrom"<>? AND COALESCE(l."ignore",0)=0 AND p."id">COALESCE(l."lastseen",-1)',
        undef, $uid, $uid
    )->[0]->[0];
}

sub _newmsgscount {
    my $uid = $_[0]->session->{userid};
    return $_[0]->dbh->selectall_arrayref(
        'SELECT COUNT(p."id")
        FROM "posts" p
        INNER JOIN "users" u ON u."id"<>? AND u."id"=p."userfrom" AND u."active"=1
        LEFT OUTER JOIN "lastseenmsgs" l ON l."userfromid"=u."id" AND l."userid"=?
        WHERE p."userto"=? AND p."id">COALESCE(l."lastseen",-1)',
        undef, $uid, $uid, $uid
    )->[0]->[0];
}

sub _counting { 
    my $c = $_[0];
    $c->stash(
        newpostcount => _newpostcount($c),
        newmsgscount => _newmsgscount($c),
        notecount => $c->dbh->selectall_arrayref(
                'SELECT COUNT("id") FROM "posts" WHERE "userfrom"=? AND "userfrom"="userto"',
                undef, $c->session->{userid}
            )->[0]->[0],
    );
    $c->generate_topiclist();
    $c->generate_userlist();
}

sub _generate_topiclist {
    my $c = shift;
    my $stashkey = shift;
    my $page = 1;
    if ( $stashkey ) {
        $page = $c->param('page') // 1;
    }
    else {
        $stashkey = 'topics';
    }
    my $topiclimit = $c->configdata->{topiclimit};
    my $uid = $c->session->{userid};
    my $query = $c->session->{topicquery};
    $c->stash( $stashkey => [ sort { $b->[6] <=> $a->[6] or uc($a->[2]) cmp uc($b->[2]) } @{ 
            $c->dbh->selectall_arrayref( << 'EOSQL'
        SELECT t."id", t."userfrom", t."title",
            (SELECT COUNT(p."id") 
                FROM "posts" p
                LEFT OUTER JOIN "lastseenforum" l ON l."userid"=? AND l."topicid"=p."topicid"
                WHERE p."userto" IS NULL AND p."userfrom"<>? AND p."topicid"=t."id" AND COALESCE(l."ignore",0)=0 AND p."id">COALESCE(l."lastseen",-1)
            ) AS "entrycount_new",
            (SELECT MAX(p2."id")
                FROM "posts" p2
                WHERE p2."userto" IS NULL AND p2."topicid"=t."id"
            ) AS "sorting",
            COALESCE(l2."ignore",0),
            COALESCE(l2."pin",0)
        FROM "topics" t
        LEFT OUTER JOIN "lastseenforum" l2 ON l2."userid"=? AND l2."topicid"=t."id"
EOSQL
        . ( $query ? << 'EOSQL' : '' )
        WHERE UPPER(t."title") LIKE UPPER(?)
EOSQL
        . << 'EOSQL'
        ORDER BY COALESCE(l2."pin", 0) DESC, CASE WHEN "entrycount_new" THEN 1 ELSE 0 END DESC, "sorting" DESC
        LIMIT ? OFFSET ?
EOSQL
        ,undef, $uid, $uid, $uid, ($query ? "\%$query\%" : ()), $topiclimit, ( $page - 1 ) * $topiclimit
    ) } ] );
}

sub _generate_userlist {
    my $c = shift;
    my $uid = $c->session->{userid};
    $c->stash( users => $c->dbh->selectall_arrayref(
        'SELECT u."id", u."name",
            (SELECT COUNT(p."id") 
                FROM "posts" p
                LEFT OUTER JOIN "lastseenmsgs" l ON l."userid"=? AND l."userfromid"=u."id"
                WHERE p."userfrom"=u."id" AND p."userto"=? AND p."id">COALESCE(l."lastseen",-1)
            ) AS "msgcount_newtome",
            (SELECT MAX(p2."id")
                FROM "posts" p2
                WHERE p2."userfrom"=? AND p2."userto"=u."id"
            ) AS "sorting" -- , u."lastseen"
        FROM "users" u
        WHERE u."active"=1 AND u."id"<>? 
        GROUP BY u."id"
        ORDER BY "msgcount_newtome" DESC, "sorting" DESC, UPPER(u."name") ASC',
        undef, $uid, $uid, $uid, $uid
    ) );
}

1;

