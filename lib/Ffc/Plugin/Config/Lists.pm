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
        WHERE p."userto" IS NULL AND COALESCE(l."ignore",0)=0 AND p."id">COALESCE(l."lastseen",-1)',
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
    my $tlist = $c->dbh->selectall_arrayref(<< 'EOSQL'
        SELECT t."id", t."userfrom", t."title",
            COUNT(p."id"), t."lastid",
            COALESCE(l."ignore",0), COALESCE(l."pin",0)
        FROM "topics" t
        LEFT OUTER JOIN "lastseenforum" l ON l."userid"=? AND l."topicid"=t."id"
        LEFT OUTER JOIN "posts" p ON p."userfrom"<>? AND p."topicid"=t."id" AND COALESCE(l."ignore",0)=0 AND p."id">COALESCE(l."lastseen",-1)
EOSQL
        . ( $query ? << 'EOSQL' : '' )
        WHERE UPPER(t."title") LIKE UPPER(?)
EOSQL
        . << 'EOSQL'
        GROUP BY t."id", t."userfrom", t."title", l."ignore", l."pin", t."lastid"
        ORDER BY COALESCE(l."pin", 0) DESC, CASE WHEN "entrycount_new" THEN 1 ELSE 0 END DESC, t."lastid" DESC
        LIMIT ? OFFSET ?
EOSQL
        ,undef, $uid, $uid, ($query ? "\%$query\%" : ()), $topiclimit, ( $page - 1 ) * $topiclimit
    );
    for my $t ( @$tlist ) {
        $t->[7] = join ' ',
            ( $t->[3]            ? 'newpost'    : () ),
            ( $t->[5]            ? 'ignored'    : () ),
            ( $t->[6]            ? 'pin'        : () ),
            ( $t->[3] && $t->[6] ? 'newpinpost' : () ),
        ;
    }
    if ( $c->session->{chronsortorder} ) {
        $c->stash( $stashkey => [ sort { $a->[5] <=> $b->[5] or $b->[6] <=> $a->[6] or $b->[4] <=> $a->[4] } @$tlist ] );
    }
    else {
        $c->stash( $stashkey => [ sort { $a->[5] <=> $b->[5] or $b->[6] <=> $a->[6] or uc($a->[2]) cmp uc($b->[2]) } @$tlist ] );
    }
}

sub _generate_userlist {
    my $c = shift;
    my $uid = $c->session->{userid};
    #die $c->dumper($c->dbh->selectall_arrayref('SELECT * FROM lastseenmsgs WHERE userid=?', undef, $uid));
    $c->stash( users => $c->dbh->selectall_arrayref( << 'EOSQL'
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
        , undef, $uid, $uid, $uid
    ) );
}

1;

