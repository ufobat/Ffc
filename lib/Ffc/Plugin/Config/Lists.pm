package Ffc::Plugin::Config;
use 5.18.0;
use strict; use warnings; use utf8;

###############################################################################
# Anzahl neuer Beiträge direkt aus der Datenbank ermitteln
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

###############################################################################
# Anzahl neuer Privatnachrichten direkt aus der Datenbank ermitteln
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

###############################################################################
# Liste der Themen mit allen notwendigen Zusatzinformationen generieren
sub _generate_topiclist {
    my ( $c, $stashkey ) = @_;
    my $page = 1;

    # Sonderbehandlung der Seitenanzahl, wenn der Stashkey gesetzt ist ... oder Stashkey setzen
    $stashkey and $page = $c->param('page') // 1 or $stashkey = 'topics';

    # Eingrenzungen der Datenbankabfragen ermitteln
    my $session = $c->session;
    my $topiclimit = $session->{topiclimit} || 20;
    my $query = uc( $session->{topicquery} // '');

    # Komplexe zusammengesetzte Datenbankabfrage durchführen
    my $tlist = $c->dbh_selectall_arrayref(<< 'EOSQL'
        SELECT t."id", t."userfrom", t."title",
            COUNT(p."id"), t."lastid",
            COALESCE(l."ignore",0), COALESCE(l."pin",0),
            UPPER(t."title") as "uctitle",
            u."name", datetime(p2."posted",'localtime'), 
            COALESCE(l."newsmail",0), t."summary", l."mailed"
        FROM "topics" t
        LEFT OUTER JOIN "lastseenforum" l ON l."userid"=? AND l."topicid"=t."id"
        LEFT OUTER JOIN "posts" p ON p."userfrom"<>? AND p."topicid"=t."id" AND COALESCE(l."ignore",0)=0 AND p."id">COALESCE(l."lastseen",0)
        LEFT OUTER JOIN "posts" p2 ON p2."id"=t."lastid"
        LEFT OUTER JOIN "users" u ON p2."userfrom"=u."id"
EOSQL
        . ( $query ? << 'EOSQL' : '' )
        WHERE "uctitle" LIKE ?
EOSQL
        . << 'EOSQL'
        GROUP BY t."id", t."userfrom", t."title", l."ignore", l."pin", t."lastid", p2."posted", u."name"
        ORDER BY COALESCE(l."pin", 0) DESC, COALESCE(l."ignore",0) ASC, t."lastid" DESC
        LIMIT ? OFFSET ?
EOSQL
        , ( $session->{userid} ) x 2, ($query ? "\%$query\%" : ()), $topiclimit, ( $page - 1 ) * $topiclimit
    );

    for my $t ( @$tlist ) {
        # Zeitstempel in das gewünschte Format bringen
        $t->[9] = $c->format_timestamp($t->[9]);
        # CSS-Class-String für die Themen zusammenstellen
        $t->[14] = join ' ',
            ( $t->[3]             ? 'newpost'    : () ),
            ( $t->[5]             ? 'ignored'    : () ),
            ( $t->[6]             ? 'pin'        : () ),
            ( $t->[3]  && $t->[6] ? 'newpinpost' : () ),
            ( $t->[10]            ? 'newsmail'   : () ),
        ;
    }

    # Nachträgliche Sortierung der ermittelten Datensätze für die Themenliste
    # und eintragen der Themenliste in den Stash unterhalb des vorgesehenen Stash-Keys $stashkey
    if ( $session->{chronsortorder} ) {
        $c->stash( $stashkey => [ sort { $a->[5] <=> $b->[5] or $b->[6] <=> $a->[6] or $b->[4] <=> $a->[4] } @$tlist ] );
    }
    else {
        $c->stash( $stashkey => [ sort { $a->[5] <=> $b->[5] or $b->[6] <=> $a->[6] or $a->[7] cmp $b->[7] } @$tlist ] );
    }
}

###############################################################################
# Liste der Benutzer und aller notwendiger zugehöriger Informationen generieren
sub _generate_userlist {
    # Benutzerdaten aus der Datenbank holen
    my $data = $_[0]->dbh_selectall_arrayref( << 'EOSQL'
SELECT
    u."id", u."name", COUNT(p."id"), l."lastid",
    CASE WHEN u."hideemail"=1 THEN '' ELSE u."email" END,
    CASE WHEN u."hidelastseen"=1 THEN '' ELSE datetime(u."lastonline", 'localtime') END,
    u."birthdate", u."infos", l."mailed"
FROM "users" u
LEFT OUTER JOIN "lastseenmsgs" l ON u."id"=l."userfromid" AND l."userid"=?
LEFT OUTER JOIN "posts" p ON p."userfrom"=u."id" AND p."userto" IS NOT NULL AND p."userto"=? 
    AND p."id">COALESCE(l."lastseen",0)
WHERE u."active"=1 AND u."id"<>? 
GROUP BY 1,2,4,5,6,7,8,9
ORDER BY 6 DESC, 4 DESC, UPPER(u."name") ASC
EOSQL
        , ( $_[0]->session->{userid} ) x 3,
    );

    # Aufbereitung des Geburtstdatums
    for my $dat ( @$data ) {
        if ( $dat->[6] and $dat->[6] =~ $Ffc::Dater ) {
            if ( $+{jahr} ) { 
                $dat->[6] = sprintf '%02d.%02d.%04d', $+{tag}, $+{monat}, $+{jahr} 
            }
            else { 
                $dat->[6] = sprintf '%02d.%02d.', $+{tag}, $+{monat} 
            }
        }
        else {
            $dat->[6] = '';
        }
    }

    # Generierte Benutzerliste entsprechend im Stash unter "users" ablegen
    $_[0]->stash( users => $data );
}

###############################################################################
# Aktualisierung der Informationen, wann ein Benutzer das letzte mal im Forenbereich etwas angesehen hat
sub _set_lastseen {
    my ( $c, $uid, $topicid, $mailonly ) = @_;

    # Gibt es Einträge zum User im Foren-Themen-Tracker zur entsprechenden Topic-Id bereits
    my $lastseen = $c->dbh_selectall_arrayref(
        'SELECT "lastseen" FROM "lastseenforum" WHERE "userid"=? AND "topicid"=?'
        , $uid, $topicid
    );

    # Soll das Update nur nach dem Mail-Versenden stattfinden, dann wird das hier abgehandelt,
    # bevor noch irgend etwas anderes gemacht werden muss
    if ( $mailonly ) {
        $c->dbh_do(
            ( @$lastseen
                ? 'UPDATE "lastseenforum" SET "mailed"=1 WHERE "userid"=? AND "topicid"=?'
                : 'INSERT INTO "lastseenforum" ("userid", "topicid", "mailed") VALUES (?,?,1)'
            ), $uid, $topicid );
    }

    # Was ist denn die neueste Id zum Thema der entsprechenden Topic-Id
    my $newlastseen = $c->dbh_selectall_arrayref(
        'SELECT "id" FROM "posts" WHERE "userto" IS NULL AND "topicid"=? ORDER BY "id" DESC LIMIT 1',
        $topicid);
    $newlastseen = @$newlastseen ? $newlastseen->[0]->[0] : -1;

    # Es gibt bereits einen Eintrag für den Benutzer im Foren-Themen-Tracker zur entsprechenden Topic-Id,
    # da reicht uns ein Update auf den entsprechenden Datensatz
    if ( @$lastseen ) {
        $c->stash( lastseen => $lastseen->[0]->[0] );
        $c->dbh_do(
            'UPDATE "lastseenforum" SET "lastseen"=?, "mailed"=1 WHERE "userid"=? AND "topicid"=?',
            $newlastseen, $uid, $topicid );
    }
    # Es gibt noch keinen Eintrag für den Benutzer im Foren-Themen-Tracker zur entsprechenden Topic-Id,
    # dieser muss also direkt mal erstellt werden mit den entsprechenden Daten
    else {
        $c->stash( lastseen => -1 );
        $c->dbh_do(
            'INSERT INTO "lastseenforum" ("userid", "topicid", "lastseen", "mailed") VALUES (?,?,?,1)',
            $uid, $topicid, $newlastseen );
    }
}

###############################################################################
# Generalroutine fürs Durchzählen und Erstellen der Listen
sub _counting { 
    # Anzahlen ermitteln
    $_[0]->stash(
        newpostcount => _newpostcount($_[0]),
        newmsgscount => _newmsgscount($_[0]),
        readlatercount => $_[0]->dbh_selectall_arrayref(
                'SELECT COUNT(r."postid") FROM "readlater" r WHERE r."userid"=?',
                $_[0]->session->{userid}
            )->[0]->[0],
        notecount => $_[0]->dbh_selectall_arrayref(
                'SELECT COUNT("id") FROM "posts" WHERE "userfrom"=? AND "userfrom"="userto"',
                $_[0]->session->{userid}
            )->[0]->[0],
    );

    # Passgenaue Themen- und Benutzerliste generlieren
    $_[0]->generate_topiclist();
    $_[0]->generate_userlist();

    # Rückgabe einstellen
    $_[0]->res->headers( 'Cache-Control' => 'public, max-age=0, no-cache' );
    return $_[0];
}

1;
