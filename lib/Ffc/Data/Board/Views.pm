package Ffc::Data::Board::Views;

use 5.010;
use strict;
use warnings;
use utf8;

use Ffc::Data;
use Ffc::Data::Auth;
use Ffc::Data::Formats;

sub get_userid { &Ffc::Data::Auth::get_userid }
sub get_username { &Ffc::Data::Auth::get_username }

sub _get_categories_sql {
    my $p = $Ffc::Data::Prefix;
    return << "EOSQL";
SELECT c.name       AS name, 
       c.short      AS short,
       COUNT(p1.id) AS cnt,
       1            AS sort
  FROM ${p}categories c
  LEFT OUTER JOIN ${p}lastseenforum f ON  f.category  =  c.id 
                                      AND f.userid    =  ?
  LEFT OUTER JOIN ${p}posts p1        ON  p1.category =  c.id 
                                      AND p1.posted   >= COALESCE(f.lastseen,0) 
                                      AND p1.from     != f.userid
                                      AND p1.to       IS NULL
  GROUP BY c.id
UNION
SELECT 'Allgemein'  AS name,
       ''           AS short,
       COUNT(p2.id) AS cnt,
       0            AS sort 
  FROM ${p}posts p2 
  WHERE p2.category IS NULL 
    AND p2.posted >= (SELECT u.lastseenforum FROM ${p}users u WHERE u.id=? LIMIT 1)
    AND p2.from   != ?
    AND p2.to     IS NULL
  ORDER BY sort, name
EOSQL
}

sub count_newmsgs {
    my $userid = get_userid( shift, 'Privatnachrichtenzähler' );
    my $sql = 'SELECT count(p.id) FROM '.$Ffc::Data::Prefix.'posts p INNER JOIN '.$Ffc::Data::Prefix.'users u ON u.id=p.to WHERE p.to IS NOT NULL AND p.to=? AND p.from <> p.to AND p.posted >= u.lastseenmsgs';
    return (Ffc::Data::dbh()->selectrow_array($sql, undef, $userid))[0];
}

sub count_newpost {
    my $userid = get_userid( shift, 'Beitragszähler' );
    my $sql = _get_categories_sql();
    $sql = "SELECT SUM(t.cnt) FROM ($sql) t";
    return (Ffc::Data::dbh()->selectrow_array($sql, undef, ($userid) x 3 ))[0];
}

sub count_notes {
    my $userid = get_userid( shift, 'Notizenzähler' );
    my $sql = 'SELECT count(p.id) FROM '.$Ffc::Data::Prefix.'posts p WHERE p.from=? AND p.to=p.from';
    return (Ffc::Data::dbh()->selectrow_array($sql, undef, $userid))[0];
}

sub get_categories {
    my $userid = get_userid( shift, 'Kategorieliste' );
    my $sql = _get_categories_sql();
    return Ffc::Data::dbh()->selectall_arrayref($sql, undef, ($userid) x 3);
}

sub get_notes { 
    my $userid = get_userid( shift, 'Notizenliste' );
    return _get_stuff( $userid, @_[ 0 .. 5 ], 'p.from=? AND p.to=p.from', $userid );
}
sub get_forum { 
    return _get_stuff( get_userid( shift, 'Beitragsliste' ), @_[ 0 .. 5 ], 'p.to IS NULL' );
}
sub get_msgs  {
    my $userid = get_userid( shift, 'Privatnachrichtenliste' );
    my @params = ( $userid, $userid );
    my $where = '( p.from=? OR p.to=? ) AND p.from <> p.to';
    if ( $_[6] ) {
        my $userid = get_userid( $_[6] );
        $where .= ' AND ( p.from=? OR p.to=? )';
        push @params, $userid, $userid;
    }
    return _get_stuff( $userid, @_[ 0 .. 5 ], $where, @params );
}

sub get_post {
    my $postid = shift;
    my $userid = get_userid( shift );
    die q{Ungültige ID für den Beitrag} unless $postid =~ m/\A\d+\z/xms;
    my $where = 'p.id=?';
    my $data = _get_stuff( $userid, @_[ 0 .. 5 ], $where, $postid );
    die q{Kein Datensatz gefunden} unless @$data;
    return $data->[0];
}

sub _get_stuff {
    my $userid = shift;
    my $page   = shift;
    my $lasts  = shift;
    my $query  = shift;
    my $cat    = shift;
    my $act    = shift;
    my $c      = shift;
    my $where  = shift;
    my @params = @_;
    $page = 1 unless $page and $page =~ m/\A\d+\z/xms;
    my $q = $query ? q{AND p.text LIKE ?} : '';
    my $p = $Ffc::Data::Prefix;
    my $l = _get_categories_sql();
    my $sql = << "EOSQL";
SELECT p.id, p.text, p.posted, 
       c.name, COALESCE(c.short,''),
       f.id, f.name, f.active,
       t.id, t.name, t.active,
       CASE WHEN p.from = p.to OR p.from = u.id
            THEN 0
            ELSE CASE WHEN p.to IS NOT NULL
                      THEN CASE WHEN p.posted >= t.lastseenmsgs THEN 1 ELSE 0 END
                      ELSE CASE WHEN p.category IS NULL
                                THEN CASE WHEN p.posted >= u.lastseenforum THEN 1 ELSE 0 END
                                ELSE CASE WHEN p.posted >= l.lastseen THEN 1 ELSE 0 END
                           END
                 END
       END
  FROM             ${p}posts         p
  INNER       JOIN ${p}users         u ON u.id = ?
  INNER       JOIN ${p}users         f ON f.id = p.from
  LEFT  OUTER JOIN ${p}users         t ON t.id = p.to
  LEFT  OUTER JOIN ${p}categories    c ON c.id = p.category
  LEFT  OUTER JOIN ${p}lastseenforum l ON c.id = l.category AND l.userid = u.id
  WHERE $where $q
    AND ( c.short = ? OR ( ( ? = '' OR ? IS NULL ) AND p.category IS NULL) )
  ORDER BY p.posted DESC LIMIT ? OFFSET ?
EOSQL
    return [ map { my $d = $_;
            $d = {
                text      => Ffc::Data::Formats::format_text($d->[1], $c),
                start     => Ffc::Data::Formats::format_text(do {(split /\n/, $d->[1])[0] // ''}, $c),
                raw       => $d->[1],
                active    => 0,
                newpost   => $d->[11],
                timestamp => Ffc::Data::Formats::format_timestamp($d->[2]),
                ownpost   => $d->[5] == $userid ? 1 : 0,
                category  => $d->[3] # kategorie
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
                              && $d->[$_->[1]] != $userid 
                              && $act          ne 'notes' )
                            ? 1 : 0, 
                        } )
                      : ( $_->[0] => undef ) }
                      ([from => 5,6,7], [to => 8,9,10]) ),
            };
            $d->{iconspresent} = $d->{editable} 
                || ( $d->{from} && $d->{from}->{chatable} ) 
                || ( $d->{to} && $d->{to}->{chatable} ) 
                ? 1 : 0;
            $d;
        } @{ Ffc::Data::dbh()
          ->selectall_arrayref( $sql, undef, $userid, @params, ( $query ? "\%$query\%" : () ), $cat, $cat, $cat,
            $Ffc::Data::Limit,
            ( ( $page - 1 ) * $Ffc::Data::Limit ) ) } ];
}

1;

