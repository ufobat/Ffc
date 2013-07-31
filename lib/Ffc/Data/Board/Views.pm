package Ffc::Data::Board::Views;

use 5.010;
use strict;
use warnings;
use utf8;

use Carp;

use Ffc::Data;
use Ffc::Data::Auth;
use Ffc::Data::Formats;
use Ffc::Data::General;

sub _get_userid { &Ffc::Data::Auth::get_userid }
sub _get_username { &Ffc::Data::Auth::get_username }

sub _get_categories_sql {
    my $p = $Ffc::Data::Prefix;
    return << "EOSQL";
SELECT 'Allgemein'  AS name,
       ''           AS short,
       COUNT(p2.id) AS cnt,
       0            AS sort 
  FROM ${p}posts p2 
  WHERE p2.category  IS NULL 
    AND p2.posted    >= (SELECT u.lastseenforum FROM ${p}users u WHERE u.id=? LIMIT 1)
    AND p2.user_from != ?
    AND p2.user_to   IS NULL

UNION

SELECT c.name       AS name, 
       c.short      AS short,
       COUNT(p1.id) AS cnt,
       c.sort + 1   AS sort
  FROM ${p}categories c
  LEFT OUTER JOIN ${p}lastseenforum f ON  f.category   =  c.id 
                                      AND f.userid     =  ?
  LEFT OUTER JOIN ${p}posts p1        ON  p1.category  =  c.id 
                                      AND p1.posted    >= COALESCE(f.lastseen,0) 
                                      AND p1.user_from != ?
                                      AND p1.user_to   IS NULL
  GROUP BY c.id

ORDER BY sort, name
EOSQL
}

sub check_for_updates {
    my $userid = _get_userid( shift, 'Prüfung auf neue Beiträge' );
    my $act = shift or die 'Keine Aktion angegeben';
    die 'Aktion unbekannt' unless $act =~ m/\Aforum|msgs|notes\z/xms;
    my $cat = shift;
    my $msgsuser = shift;
    return 0 if $act eq 'notes';
    my @param;
    my $sql = '';
    given ( $act ) {
        when ( 'forum' ) {
            if ( $cat ) {
                push @param, Ffc::Data::General::get_category_id($cat);
                $sql = << "EOSQL";
SELECT COUNT(p.id)
FROM            ${Ffc::Data::Prefix}posts         p
INNER JOIN      ${Ffc::Data::Prefix}users         u ON u.id       = ?          AND p.user_from <> u.id
LEFT OUTER JOIN ${Ffc::Data::Prefix}lastseenforum f ON p.category = f.category AND f.userid     = u.id
WHERE p.posted   >= COALESCE(f.lastseen,0)
  AND p.user_to  IS NULL
  AND p.category IS NOT NULL
  AND p.category = ?
EOSQL
            }
            else {
                $sql = << "EOSQL";
SELECT COUNT(p.id)
FROM       ${Ffc::Data::Prefix}posts p 
INNER JOIN ${Ffc::Data::Prefix}users u ON u.id = ? AND p.user_from <> u.id
WHERE p.posted   >= COALESCE(u.lastseenforum, 0)
  AND p.user_to  IS NULL
  AND p.category IS NULL
EOSQL
            }
        }
        when ( 'msgs'  ) {
            if ( $msgsuser ) {
                push @param, _get_userid( $msgsuser );
                $sql = << "EOSQL";
SELECT COUNT(p.id)
FROM       ${Ffc::Data::Prefix}posts p 
INNER JOIN ${Ffc::Data::Prefix}users u ON u.id = ? AND p.user_from <> u.id
WHERE p.posted    >= COALESCE(u.lastseenmsgs, 0)
  AND p.user_to   =  u.id
  AND p.user_to   IS NOT NULL
  AND p.user_from =  ?
EOSQL
            }
            else {
                $sql = << "EOSQL";
SELECT COUNT(p.id)
FROM       ${Ffc::Data::Prefix}posts p 
INNER JOIN ${Ffc::Data::Prefix}users u ON u.id = ? AND p.user_from <> u.id
WHERE p.posted    >= COALESCE(u.lastseenmsgs, 0)
  AND p.user_to   =  u.id
  AND p.user_to   IS NOT NULL
EOSQL
            }
        }
        default {$sql = ''}
    }
    return 0 unless $sql;
    my $cnt = (Ffc::Data::dbh()->selectrow_array($sql, undef, $userid, @param))[0];
    #warn "$cnt (@param):  $sql" if $cnt;
    return $cnt;
}

sub count_newmsgs {
    my $userid = _get_userid( shift, 'Privatnachrichtenzähler' );
    my $sql = 'SELECT count(p.id) FROM '.$Ffc::Data::Prefix.'posts p INNER JOIN '.$Ffc::Data::Prefix.'users u ON u.id=p.user_to WHERE p.user_to IS NOT NULL AND p.user_to=? AND p.user_from <> p.user_to AND p.posted >= u.lastseenmsgs';
    return (Ffc::Data::dbh()->selectrow_array($sql, undef, $userid))[0];
}

sub get_userlist {
    my $userid = _get_userid( shift, 'Privatnachrichtennutzerliste' );
    my $sql = 'SELECT 
        u2.name,
        (SELECT COUNT(p.id) AS cnt FROM '.$Ffc::Data::Prefix.'posts p WHERE p.user_to IS NOT NULL AND p.user_to = u1.id AND p.posted >= u1.lastseenmsgs AND p.user_from=u2.id),
        u2.lastseen,
        u2.active
    FROM '.$Ffc::Data::Prefix.'users u2
    INNER JOIN '.$Ffc::Data::Prefix.'users u1 ON u1.id = ?
    WHERE u2.id <> u1.id
    ORDER BY u2.name';
    return [ map {$_->[2] = Ffc::Data::Formats::format_timestamp($_->[2]); $_} @{ Ffc::Data::dbh()->selectall_arrayref( $sql, undef, $userid ) } ];
}

sub count_newposts {
    my $userid = _get_userid( shift, 'Beitragszähler' );
    my $sql = _get_categories_sql();
    $sql = "SELECT SUM(t.cnt) FROM ($sql) t";
    return (Ffc::Data::dbh()->selectrow_array($sql, undef, ($userid) x 4 ))[0];
}

sub count_notes {
    my $userid = _get_userid( shift, 'Notizenzähler' );
    my $sql = 'SELECT count(p.id) FROM '.$Ffc::Data::Prefix.'posts p WHERE p.user_from=? AND p.user_to=p.user_from';
    return (Ffc::Data::dbh()->selectrow_array($sql, undef, $userid))[0];
}

sub get_categories {
    my $userid = _get_userid( shift, 'Kategorieliste' );
    my $sql = _get_categories_sql();
    return Ffc::Data::dbh()->selectall_arrayref($sql, undef, ($userid) x 4);
}

sub get_notes { 
    my $userid = _get_userid( shift, 'Notizenliste' );
    my @params = @_[0..4];
    $params[2] = undef;
    $params[3] = undef;
    return _get_stuff( 'notes', $userid, @params, 'p.user_from=? AND p.user_to=p.user_from', $userid );
}
sub get_forum { 
    my $userid = _get_userid( shift, 'Forenbeiträge' );
    my @params = @_[ 0 .. 4 ];
    $params[2] = undef;
    if ( $params[3] ) {
        Ffc::Data::General::check_category($params[3]);
    }
    else {
        $params[3] = undef;
    }
    return _get_stuff( 'forum', $userid, @params, 'p.user_to IS NULL' );
}
sub get_msgs  {
    my $userid = _get_userid( shift, 'Privatnachrichtenliste' );
    my @params = ( $userid, $userid );
    my $where = '( p.user_from=? OR p.user_to=? ) AND p.user_from <> p.user_to';
    if ( $_[2] ) {
        my $userid = _get_userid( $_[2] );
        $where .= ' AND ( p.user_from=? OR p.user_to=? )';
        push @params, $userid, $userid;
    }
    my @params2 = @_[0..4];
    $params2[3] = undef;
    return _get_stuff( 'msgs', $userid, @params2, $where, @params );
}

sub get_post {
    my $act = shift;
    croak qq(Aktion nicht angegeben) unless $act;
    croak qq{Aktion unbekannt ("$act") oder Privatnachricht (nicht änderbar)} unless $act =~ m/\A(?:forum|notes)\z/xms;
    my $postid = shift;
    croak q{Keine ID für den Beitrag angegeben} unless $postid;
    croak q{Ungültige ID für den Beitrag angegeben} unless $postid =~ m/\A\d+\z/xms;
    my $userid = _get_userid( shift );
    my $where = << 'EOWHERE';
    p.id=? AND f.id=u.id AND ( t.id IS NULL OR t.id=f.id )
EOWHERE
    my @params = @_[ 0 .. 4 ];
    #die Data::Dumper::Dumper({act => $act, userid => $userid, params => [@params[0..3]], where => $where, postid => $postid});
    $params[2] = undef unless $params[2];
    $params[2] = undef unless $act eq 'msgs';
    if ( $params[2] ) {
        Ffc::Data::Auth::check_username($params[2]);
    }
    $params[3] = undef unless $params[3];
    $params[3] = undef unless $act eq 'forum';
    if ( $params[3] ) {
        Ffc::Data::General::check_category($params[3]);
    }
    my $data = _get_stuff( $act, $userid, @params, $where, $postid );
    croak q{Kein Datensatz gefunden} unless @$data;
    return $data->[0];
}

sub _get_stuff {
    my $act    = shift;
    my $userid = shift;
    my $page   = shift;
    my $query  = shift;
    my $msgu   = shift // '';
    my $cat    = shift;
    my $c      = shift;
    my $where  = shift;
    my @params = @_;
    my $q = '';
    my $p = $Ffc::Data::Prefix;
    $cat = undef unless $act eq 'forum';
    $page = 1 unless $page and $page =~ m/\A\d+\z/xms;
    if ( $query ) {
        push @params, "\%$query\%";
        $q = q{AND UPPER(p.textdata) LIKE UPPER(?)};
    }
    my $sql = << "EOSQL";
SELECT p.id, p.textdata, p.posted, 
       c.name, COALESCE(c.short,''),
       f.id, f.name, f.active,
       t.id, t.name, t.active,
       f.avatar,
       CASE WHEN f.id = t.id OR f.id = u.id
            THEN 0
            ELSE CASE WHEN t.id IS NOT NULL
                      THEN CASE WHEN p.posted >= t.lastseenmsgs THEN 1 ELSE 0 END
                      ELSE CASE WHEN p.category IS NULL
                                THEN CASE WHEN p.posted >= u.lastseenforum THEN 1 ELSE 0 END
                                ELSE CASE WHEN p.posted >= l.lastseen THEN 1 ELSE 0 END
                           END
                 END
       END
  FROM             ${p}posts         p
  INNER       JOIN ${p}users         u ON u.id = ?
  INNER       JOIN ${p}users         f ON f.id = p.user_from
  LEFT  OUTER JOIN ${p}users         t ON t.id = p.user_to
  LEFT  OUTER JOIN ${p}categories    c ON c.id = p.category
  LEFT  OUTER JOIN ${p}lastseenforum l ON c.id = l.category AND l.userid = u.id
  WHERE $where $q
    AND ( c.short = ? OR ( ( ? = '' OR ? IS NULL ) AND p.category IS NULL) )
  ORDER BY p.posted DESC, p.id DESC LIMIT ? OFFSET ?
EOSQL
    push @params, ( $cat, $cat, $cat );
    push @params, $Ffc::Data::Limit, ( ( $page - 1 ) * $Ffc::Data::Limit );
    unshift @params, $userid;
#die Data::Dumper::Dumper( { sql => $sql, userid => $userid, params => \@params, query => [( $query ? "\%$query\%" : () )], cat => [$cat, $cat, $cat]});
    return [ map { my $d = $_;
            $d = {
                text       => Ffc::Data::Formats::format_text($d->[1], $c),
                start      => Ffc::Data::Formats::format_text(do {(split /\n/, $d->[1])[0] // ''}, $c),
                raw        => $d->[1],
                active     => 0,
                avatar     => $d->[11] ? $d->[6] : '',
                newpost    => $d->[12],
                timestamp  => Ffc::Data::Formats::format_timestamp($d->[2]),
                ( $d->[5] == $userid 
                    ? (ownpost => 1, uploadable => 1) 
                    : (ownpost => 0, uploadable => 0) ),
                ownpost    => $d->[5] == $userid ? 1 : 0,
                category   => $d->[3] # kategorie
                    ? { name => $d->[3], short => $d->[4] }
                    : undef,
                $d->[5] == $userid && $act ne 'msgs' # editierbarkeit
                    ? (editable => 1, id => $d->[0]) 
                    : (editable => 0, id => undef),
                map( { $d->[$_->[1]] 
                      ? ( $_->[0] => { 
                          id       => $d->[$_->[1]], 
                          name     => $d->[$_->[2]], 
                          active   => $d->[$_->[3]], 
                          chatable => 
                            (    $d->[$_->[3]]
                              && $act          ne 'notes'
                              && $d->[$_->[1]] != $userid 
                              && $msgu         ne $d->[$_->[2]]
                            ) ? 1 : 0, 
                        } )
                      : ( $_->[0] => undef ) }
                      ([from => 5,6,7], [to => 8,9,10]) ),
            };
            $d->{iconspresent} = $d->{editable} 
                || ( $d->{from} && $d->{from}->{chatable} ) 
                || ( $d->{to} && $d->{to}->{chatable} ) 
                ? 1 : 0;
            $d;
        } @{ Ffc::Data::dbh()->selectall_arrayref( $sql, undef, @params ) } ];
}

1;

