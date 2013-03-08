package AltSimpleBoard::Data::Board;

use 5.010;
use strict;
use warnings;
use utf8;
use AltSimpleBoard::Data;
use AltSimpleBoard::Data::Auth;
use AltSimpleBoard::Data::Formats;

sub update_email {
    my ( $userid, $email ) = @_;
    check_user( $userid );
    die qq{Neue Emailadresse ist zu lang (<=1024)} unless 1024 >= length $email;
    die qq(Neue Emailadresse schaut komisch aus) unless $email =~ m/\A[-.\w]+\@[-.\w]+\.\w+\z/xmsi;
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'users u SET u.email=? WHERE u.id=?';
    AltSimpleBoard::Data::dbh()->do($sql, undef, $email, $userid);
}

sub _check_password_change {
    my ( $newpw1, $newpw2, $oldpw ) = @_;
    for ( ( $oldpw ? ['Altes Passwort' => $oldpw] : () ), ['Neues Passwort' => $newpw1], ['Passwortwiederholung' => $newpw2] ) {
        die qq{$_->[0] entspricht nicht der Norm (4-16 Zeichen)} unless $_->[1] =~ m/\A.{4,16}\z/xms;
    }
    die qq{Das neue Passwort und dessen Wiederholung stimmen nicht überein} unless $newpw1 eq $newpw2;
    return 1;
}

sub update_password {
    my ( $userid, $oldpw, $newpw1, $newpw2 ) = @_;
    check_user( $userid );
    _check_password_change( $newpw1, $newpw2, $oldpw );
    die qq{Das alte Passwort ist falsch} unless AltSimpleBoard::Data::Auth::check_password($userid, $oldpw);
    AltSimpleBoard::Data::Auth::set_password($userid, $newpw1);
}

sub update_show_images {
    my $s = shift;
    my $x = shift;
    die qq{show_images muss 0 oder 1 sein} unless $x =~ m/\A[01]\z/xms;
    $s->{show_images} = $x;
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'users u SET u.show_images=? WHERE u.id=?';
    AltSimpleBoard::Data::dbh()->do($sql, undef, $x, $s->{userid});
}

sub update_theme {
    my $s = shift;
    my $t = shift;
    die qq{Themenname zu lang (64 Zeichen maximal)} if 64 < length $t;
    die qq{Thema ungültig: $t} unless $t ~~ @AltSimpleBoard::Data::Themes; 
    $s->{theme} = $t;
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'users u SET u.theme=? WHERE u.id=?';
    AltSimpleBoard::Data::dbh()->do($sql, undef, $t, $s->{userid});
}

sub admin_update_password {
    my $adminuid = shift;
    die 'Passworte von anderen Benutzern dürfen nur Administratoren ändern'
        unless AltSimpleBoard::Data::Auth::is_user_admin($adminuid);
    my $userid = shift;
    check_user( $userid );
    my $pw1 = shift;
    my $pw2 = shift;
    _check_password_change( $pw1, $pw2 );
    AltSimpleBoard::Data::Auth::set_password($userid, $pw1);
}

sub admin_update_active {
    my $adminuid = shift;
    die 'Benutzern aktivieren oder deaktiveren dürfen nur Administratoren'
        unless AltSimpleBoard::Data::Auth::is_user_admin($adminuid);
    my $userid = shift;
    check_user( $userid );
    my $active = shift() ? 1 : 0;
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'users u SET u.active=? WHERE u.id=?';
    AltSimpleBoard::Data::dbh()->do($sql, undef, $active, $userid);
}

sub admin_update_admin {
    my $adminuid = shift;
    die 'Benutzern zu Administratoren befördern oder ihnen den Adminstratorenstatus wegnehmen dürfen nur Administratoren'
        unless AltSimpleBoard::Data::Auth::is_user_admin($adminuid);
    my $userid = shift;
    check_user( $userid );
    my $admin = shift() ? 1 : 0;
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'users u SET u.admin=? WHERE u.id=?';
    AltSimpleBoard::Data::dbh()->do($sql, undef, $admin, $userid);
}

sub admin_create_user {
    my $adminuid = shift;
    die 'Neue Benutzer anlegen dürfen nur Administratoren'
        unless AltSimpleBoard::Data::Auth::is_user_admin($adminuid);
    my $username = shift;
    die qq(Benutzer "$username" existiert bereits und darf nicht neu angelegt werden)
        if AltSimpleBoard::Data::Board::get_userid($username);
    my $pw1 = shift;
    my $pw2 = shift;
    _check_password_change( $pw1, $pw2 );
    my $active = shift() ? 1 : 0;
    my $admin  = shift() ? 1 : 0;
    my $sql = 'INSERT INTO '.$AltSimpleBoard::Data::Prefix.'users (name, password, active, admin) VALUES (?,?,?,?)';
    AltSimpleBoard::Data::dbh()->do($sql, undef, $username, crypt($pw1, AltSimpleBoard::Data::cryptsalt()), $active, $admin);
}

sub _get_categories_sql {
    my $p = $AltSimpleBoard::Data::Prefix;
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
    my $userid = shift;
    check_user( $userid );
    my $sql = 'SELECT count(p.id) FROM '.$AltSimpleBoard::Data::Prefix.'posts p INNER JOIN '.$AltSimpleBoard::Data::Prefix.'users u ON u.id=p.to WHERE p.to IS NOT NULL AND p.to=? AND p.from <> p.to AND p.posted >= u.lastseenmsgs';
    return (AltSimpleBoard::Data::dbh()->selectrow_array($sql, undef, $userid))[0];
}

sub count_newpost {
    my $userid = shift;
    die qq{Benutzer unbekannt} unless get_username($userid);
    my $sql = _get_categories_sql();
    $sql = "SELECT SUM(t.cnt) FROM ($sql) t";
    return (AltSimpleBoard::Data::dbh()->selectrow_array($sql, undef, ($userid) x 3 ))[0];
}

sub count_notes {
    my $userid = shift;
    die qq{Benutzer unbekannt} unless get_username($userid);
    my $sql = 'SELECT count(p.id) FROM '.$AltSimpleBoard::Data::Prefix.'posts p WHERE p.from=? AND p.to=p.from';
    return (AltSimpleBoard::Data::dbh()->selectrow_array($sql, undef, $userid))[0];
}

sub get_categories {
    my $userid = shift;
    die qq{Benutzer unbekannt} unless get_username($userid);
    my $sql = _get_categories_sql();
    return AltSimpleBoard::Data::dbh()->selectall_arrayref($sql, undef, ($userid) x 3);
}
sub get_category {
    my $id = shift;
    die qq{Kategorie-ID ist ungültig} unless $id =~ m/\A\d+\z/xms;
    my $sql = 'SELECT c.short FROM '.$AltSimpleBoard::Data::Prefix.'categories c WHERE c.id=? LIMIT 1';
    ( AltSimpleBoard::Data::dbh()->selectrow_array($sql, undef, $id) )[0];
}
sub get_category_id {
    my $c = shift;
    die qq{Kategoriekürzel ungültig} unless $c =~ m/\A\w{1,64}\z/xms;
    my $sql = 'SELECT c.id FROM '.$AltSimpleBoard::Data::Prefix.'categories c WHERE c.short=?';
    my $cats = AltSimpleBoard::Data::dbh()->selectall_arrayref($sql, undef, $c);
    die qq{Kategorie ungültig} unless @$cats;
    return $cats->[0]->[0];
}
sub check_category {
    return $_[0] if get_category_id($_[0]);
    return;
}

sub check_user { 
    eval { get_username( shift ) };
    die shift() // $@ if $@;
    return 1;
}
sub get_userid {
    my $username = shift;
    die qq{Benutzername ungültig, zwei bis 64 Zeichen erlaubt}
        unless $username =~ m/\A\w{2,64}\z/xms;
    my $sql = 'SELECT u.id FROM '.$AltSimpleBoard::Data::Prefix.'users u WHERE u.name = ?';
    $username = AltSimpleBoard::Data::dbh()->selectall_arrayref($sql, undef, $username);
    return $username->[0]->[0] if @$username;
    return;
}

sub get_username {
    my $id = shift;
    die qq{Benutzerid ungültig} unless $id =~ m/\A\d+\z/xms;
    my $sql = 'SELECT u.name FROM '.$AltSimpleBoard::Data::Prefix.'users u WHERE u.id=?';
    $id = AltSimpleBoard::Data::dbh()->selectall_arrayref($sql, undef, $id);
    die qq{Benutzer unbekannt} unless @$id and $id->[0]->[0];
    return $id;
}

sub get_useremail {
    my $id = shift;
    check_user( $id );
    my $sql = 'SELECT u.email FROM '.$AltSimpleBoard::Data::Prefix.'users u WHERE u.id=? AND u.active=1';
    return (AltSimpleBoard::Data::dbh()->selectrow_array($sql, undef, $id))[0];
}

sub get_userlist {
    my $sql = 'SELECT u.id, u.name, u.active, u.admin FROM '.$AltSimpleBoard::Data::Prefix.'users u ORDER BY u.active DESC, u.name ASC';
    return AltSimpleBoard::Data::dbh()->selectall_arrayref($sql);
}

sub delete_post {
    my ( $from, $id ) = @_;
    die qq{Postid ungültig} unless $id =~ m/\A\d+\z/xms;
    check_user( $from );
    my $dbh = AltSimpleBoard::Data::dbh();
    my $sql = sprintf 'DELETE FROM '.$AltSimpleBoard::Data::Prefix.'posts WHERE %s=? and %s=? AND (%s IS NULL OR %s=%s);', map {$dbh->quote_identifier($_)} qw(id from to to from);
    $dbh->do( $sql, undef, $id, $from );
}
sub insert_post {
    my ( $f, $d, $c, $t ) = @_;
    check_user( $f, 'Sender des Beitrages unbekannt' );
    check_user( $t, 'Empfänger des Beitrages unbekannt' ) if $t;
    die qq{Beitrag ungültig, zu wenig Zeichen (min. 2)} if 2 >= length $d;
    my $cid = $c ? get_category_id($c) : undef;
    my $dbh = AltSimpleBoard::Data::dbh();
    my $sql = 'INSERT INTO '.$AltSimpleBoard::Data::Prefix.'posts ('.join(', ',map {$dbh->quote_identifier($_)} qw(from to text posted category)).') VALUES (?, ?, ?, current_timestamp, ?)';
    $dbh->do( $sql, undef, $f, $t, $d, $cid );
}

sub update_post {
    my ( $f, $d, $i, $t ) = @_;
    check_user( $f, 'Sender des Beitrages unbekannt' );
    check_user( $t, 'Empfänger des Beitrages unbekannt' ) if $t;
    die qq{Beitrag ungültig, zu wenig Zeichen (min. 2)} if 2 >= length $d;
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'posts p SET p.text=?, p.posted=current_timestamp, p.to=? WHERE p.id=? AND p.from=? AND (p.to IS NULL OR p.to=p.from);';
    AltSimpleBoard::Data::dbh()->do( $sql, undef, $d, $t, $i, $f );
}

sub _update_user_forum {
    my $userid = shift;
    check_user( $userid );
    my $category = $_[1];
    if ( $category ) {
        my $category = get_category_id($category);
        my $sql = 'SELECT COUNT(l.userid) FROM '.$AltSimpleBoard::Data::Prefix.'lastseenforum l WHERE l.userid=? AND l.category=?';
        my $dbh = AltSimpleBoard::Data::dbh();
        if ( ( $dbh->selectrow_array( $sql, undef, $userid, $category ) )[0] ) {
            $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'lastseenforum l SET l.lastseen=current_timestamp WHERE l.userid=? AND l.category=?';
        }
        else {
            $sql = 'INSERT INTO '.$AltSimpleBoard::Data::Prefix.'lastseenforum (lastseen, userid, category) VALUES (current_timestamp, ?, ?)';
        }
        $dbh->do( $sql, undef, $userid, $category );
    }
    else {
        my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'users u SET u.lastseenforum=current_timestamp WHERE u.id=?;';
        AltSimpleBoard::Data::dbh()->do( $sql, undef, $userid );
    }
}

sub _update_user_msgs {
    my $userid = shift;
    check_user( $userid );
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'users u SET u.lastseenmsgs=current_timestamp WHERE u.id=?;';
    AltSimpleBoard::Data::dbh()->do( $sql, undef, $userid );
}
sub update_user_stats {
    given ( $_[1] ) {
        when ( 'forum' ) { _update_user_forum( @_ ) }
        when ( 'msgs'  ) { _update_user_msgs(  @_ ) }
    }
}

sub get_notes { _get_stuff( @_[ 0 .. 6 ], 'p.from=? AND p.to=p.from', $_[0]) }
sub get_forum { _get_stuff( @_[ 0 .. 6 ], 'p.to IS NULL' ) }
sub get_msgs  {
    my @params = ( $_[0], $_[0] );
    my $where = '( p.from=? OR p.to=? ) AND p.from <> p.to';
    if ( $_[7] ) {
        $where .= ' AND ( p.from=? OR p.to=? )';
        push @params, $_[7], $_[7];
    }
    return _get_stuff( @_[ 0 .. 6 ], $where, @params );
}

sub get_post {
    my $postid = shift;
    die q{Ungültige ID für den Beitrag} unless $postid =~ m/\A\d+\z/xms;
    my $where = 'p.id=?';
    my $data = _get_stuff( @_[ 0 .. 6 ], $where, $postid );
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
    check_user( $userid );
    $page = 1 unless $page and $page =~ m/\A\d+\z/xms;
    my $q = $query ? q{AND p.text LIKE ?} : '';
    my $p = $AltSimpleBoard::Data::Prefix;
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
                text      => AltSimpleBoard::Data::Formats::format_text($d->[1], $c),
                start     => AltSimpleBoard::Data::Formats::format_text(do {(split /\n/, $d->[1])[0] // ''}, $c),
                raw       => $d->[1],
                active    => 0,
                newpost   => $d->[11],
                timestamp => AltSimpleBoard::Data::Formats::format_timestamp($d->[2]),
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
        } @{ AltSimpleBoard::Data::dbh()
          ->selectall_arrayref( $sql, undef, $userid, @params, ( $query ? "\%$query\%" : () ), $cat, $cat, $cat,
            $AltSimpleBoard::Data::Limit,
            ( ( $page - 1 ) * $AltSimpleBoard::Data::Limit ) ) } ];
}

1;

