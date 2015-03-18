package Ffc::Plugin::Config;
use 5.010;
use strict; use warnings; use utf8;

sub _newpostcount {
    return $_[0]->dbh_selectall_arrayref(
        'SELECT COUNT(p."id")
        FROM "posts" p
        INNER JOIN "topics" t on t."id"=p."topicid"
        LEFT OUTER JOIN "lastseenforum" l ON l."topicid"=p."topicid" AND l."userid"=?
        WHERE p."userto" IS NULL AND COALESCE(l."ignore",0)=0 AND p."id">COALESCE(l."lastseen",0)',
        $_[0]->session->{userid}
    )->[0]->[0];
}

sub _newmsgscount {
    return $_[0]->dbh_selectall_arrayref(
        'SELECT COUNT(p."id")
        FROM "posts" p
        INNER JOIN "users" u ON u."id"<>? AND u."id"=p."userfrom" AND u."active"=1
        LEFT OUTER JOIN "lastseenmsgs" l ON l."userfromid"=u."id" AND l."userid"=?
        WHERE p."userto"=? AND p."id">COALESCE(l."lastseen",0)',
        ( $_[0]->session->{userid} ) x 3
    )->[0]->[0];
}

sub _counting { 
    $_[0]->stash(
        newpostcount => _newpostcount($_[0]),
        newmsgscount => _newmsgscount($_[0]),
        notecount => $_[0]->dbh_selectall_arrayref(
                'SELECT COUNT("id") FROM "posts" WHERE "userfrom"=? AND "userfrom"="userto"',
                $_[0]->session->{userid}
            )->[0]->[0],
    );
    $_[0]->generate_topiclist();
    $_[0]->generate_userlist();
    $_[0]->res->headers( 'Cache-Control' => 'public, max-age=0, no-cache' );
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
    my $session = $c->session;
    my $topiclimit = $session->{topiclimit};
    my $query = uc $session->{topicquery};
    my $tlist = $c->dbh_selectall_arrayref(<< 'EOSQL'
        SELECT t."id", t."userfrom", t."title",
            COUNT(p."id"), t."lastid",
            COALESCE(l."ignore",0), COALESCE(l."pin",0),
            UPPER(t."title") as "uctitle"
        FROM "topics" t
        LEFT OUTER JOIN "lastseenforum" l ON l."userid"=? AND l."topicid"=t."id"
        LEFT OUTER JOIN "posts" p ON p."userfrom"<>? AND p."topicid"=t."id" AND COALESCE(l."ignore",0)=0 AND p."id">COALESCE(l."lastseen",0)
EOSQL
        . ( $query ? << 'EOSQL' : '' )
        WHERE "uctitle" LIKE ?
EOSQL
        . << 'EOSQL'
        GROUP BY t."id", t."userfrom", t."title", l."ignore", l."pin", t."lastid"
        ORDER BY COALESCE(l."pin", 0) DESC, t."lastid" DESC
        LIMIT ? OFFSET ?
EOSQL
        , ( $session->{userid} ) x 2, ($query ? "\%$query\%" : ()), $topiclimit, ( $page - 1 ) * $topiclimit
    );
    for my $t ( @$tlist ) {
        $t->[8] = join ' ',
            ( $t->[3]            ? 'newpost'    : () ),
            ( $t->[5]            ? 'ignored'    : () ),
            ( $t->[6]            ? 'pin'        : () ),
            ( $t->[3] && $t->[6] ? 'newpinpost' : () ),
        ;
    }
    if ( $session->{chronsortorder} ) {
        $c->stash( $stashkey => [ sort { $a->[5] <=> $b->[5] or $b->[6] <=> $a->[6] or $b->[4] <=> $a->[4] } @$tlist ] );
    }
    else {
        $c->stash( $stashkey => [ sort { $a->[5] <=> $b->[5] or $b->[6] <=> $a->[6] or $a->[7] cmp $b->[7] } @$tlist ] );
    }
}

sub _generate_userlist {
    $_[0]->stash( users => $_[0]->dbh_selectall_arrayref( << 'EOSQL'
SELECT u."id", u."name",
    COALESCE(COUNT(p."id"),0), l."lastid"
FROM "users" u
LEFT OUTER JOIN "lastseenmsgs" l ON u."id"=l."userfromid" AND l."userid"=?
LEFT OUTER JOIN "posts" p ON p."userfrom"=u."id" AND p."userto" IS NOT NULL AND p."userto"=? 
    AND p."id">COALESCE(l."lastseen",0)
WHERE u."active"=1 AND u."id"<>? 
GROUP BY u."id", u."name", l."lastid"
ORDER BY l."lastid" DESC, UPPER(u."name") ASC
EOSQL
        , ( $_[0]->session->{userid} ) x 3
    ) );
}

1;

