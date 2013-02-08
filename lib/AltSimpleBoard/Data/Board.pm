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
    die qq{Benutzer unbekannt} unless get_username($userid);
    die qq{Neue Emailadresse ist zu lang (<=1024)} unless 1024 >= length $email;
    die qq(Neue Emailadresse schaut komisch aus) unless $email =~ m/\A[-.\w]+\@[-.\w]+\.\w+\z/xmsi;
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'users SET `email`=? WHERE `id`=? AND `active`=1';
    AltSimpleBoard::Data::dbh()->do($sql, undef, $email, $userid);
}

sub update_password {
    my ( $userid, $oldpw, $newpw1, $newpw2 ) = @_;
    die qq{Benutzer unbekannt} unless get_username($userid);
    for ( ['Altes Passwort' => $oldpw], ['Neues Passwort' => $newpw1], ['Passwortwiederholung' => $newpw2] ) {
        die qq{$_->[0] entspricht nicht der Norm (4-16 Zeichen)} unless $_->[1] =~ m/\A.{4,16}\z/xms;
    }
    die qq{Das alte Passwort ist falsch} unless AltSimpleBoard::Data::Auth::check_password($userid, $oldpw);
    die qq{Das neue Passwort und dessen Wiederholung stimmen nicht überein} unless $newpw1 eq $newpw2;
    AltSimpleBoard::Data::Auth::set_password($userid, $newpw1);
}

sub update_show_images {
    my $s = shift;
    my $x = shift;
    die qq{show_images muss 0 oder 1 sein} unless $x =~ m/\A[01]\z/xms;
    $s->{show_images} = $x;
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'users SET `show_images`=? WHERE `id`=?';
    AltSimpleBoard::Data::dbh()->do($sql, undef, $x, $s->{userid});
}

sub update_theme {
    my $s = shift;
    my $t = shift;
    die qq{Themenname zu lang (64 Zeichen maximal)} if 64 < length $t;
    die qq{Thema ungültig: $t} unless $t ~~ @AltSimpleBoard::Data::Themes; 
    $s->{theme} = $t;
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'users SET `theme`=? WHERE `id`=?';
    AltSimpleBoard::Data::dbh()->do($sql, undef, $t, $s->{userid});
}

sub count_newmsgs {
    my $userid = shift;
    die qq{Benutzer unbekannt} unless get_username($userid);
    my $sql = 'SELECT count(`id`) FROM '.$AltSimpleBoard::Data::Prefix.'posts WHERE `to` IS NOT NULL AND `to`=? AND `from` <> `to`';
    return (AltSimpleBoard::Data::dbh()->selectrow_array($sql, undef, $userid))[0];
}

sub count_newpost {
    my $userid = shift;
    die qq{Benutzer unbekannt} unless get_username($userid);
    my $sql = 'SELECT count(`id`) FROM '.$AltSimpleBoard::Data::Prefix.'posts WHERE `to` IS NULL';
    return (AltSimpleBoard::Data::dbh()->selectrow_array($sql))[0];
}

sub count_notes {
    my $userid = shift;
    die qq{Benutzer unbekannt} unless get_username($userid);
    my $sql = 'SELECT count(`id`) FROM '.$AltSimpleBoard::Data::Prefix.'posts WHERE `from`=? AND `to`=`from`';
    return (AltSimpleBoard::Data::dbh()->selectrow_array($sql, undef, $userid))[0];
}

sub get_categories {
    my $sql 
     = q{SELECT c.`name` AS `name`, c.`short` AS `short`, COUNT(p.`id`) AS `cnt`, 1 AS `sort` FROM }
     . $AltSimpleBoard::Data::Prefix
     . q{categories c LEFT OUTER JOIN }
     . $AltSimpleBoard::Data::Prefix
     . q{posts p ON p.`category`=c.`id` GROUP BY c.`id` UNION }
     . q{SELECT 'Allgemein' AS `name`, '' AS `short`, COUNT(p.`id`) AS `cnt`, 0 AS `sort` FROM }
     . $AltSimpleBoard::Data::Prefix
     . q{posts p WHERE p.`category` IS NULL }
     . q{ORDER BY `sort`, `name`};
    return AltSimpleBoard::Data::dbh()->selectall_arrayref($sql);
}
sub get_category {
    my $id = shift;
    die qq{Kategorie-ID ist ungültig} unless $id =~ m/\A\d+\z/xms;
    my $sql = 'SELECT `short` FROM '.$AltSimpleBoard::Data::Prefix.'categories WHERE `id`=? LIMIT 1';
    ( AltSimpleBoard::Data::dbh()->selectrow_array($sql, undef, $id) )[0];
}
sub get_category_id {
    my $c = shift;
    die qq{Kategoriekürzel ungültig} unless $c =~ m/\A\w+\z/xms;
    my $sql = 'SELECT `id` FROM '.$AltSimpleBoard::Data::Prefix.'categories WHERE `short`=?';
    my $cats = AltSimpleBoard::Data::dbh()->selectall_arrayref($sql, undef, $c);
    die qq{Kategorie ungültig} unless @$cats;
    return $cats->[0]->[0];
}

sub get_username {
    my $id = shift;
    die qq{Benutzerid ungültig} unless $id =~ m/\A\d+\z/xms;
    my $sql = 'SELECT `name` FROM '.$AltSimpleBoard::Data::Prefix.'users WHERE `id`=? AND `active`=1';
    return (AltSimpleBoard::Data::dbh()->selectrow_array($sql, undef, $id))[0];
}

sub get_useremail {
    my $id = shift;
    die qq{Benutzerid ungültig} unless $id =~ m/\A\d+\z/xms;
    my $sql = 'SELECT `email` FROM '.$AltSimpleBoard::Data::Prefix.'users WHERE `id`=? AND `active`=1';
    return (AltSimpleBoard::Data::dbh()->selectrow_array($sql, undef, $id))[0];
}

sub get_userlist {
    my $sql = 'SELECT `id`, `name`, `active`, `admin` FROM '.$AltSimpleBoard::Data::Prefix.'users ORDER BY `active` DESC, `name` ASC';
    return AltSimpleBoard::Data::dbh()->selectall_arrayref($sql);
}

sub delete_post {
    my ( $from, $id ) = @_;
    die qq{Postid ungültig} unless $id =~ m/\A\d+\z/xms;
    die qq{Benutzer ungültig} unless get_username($from);
    my $sql = 'DELETE FROM '.$AltSimpleBoard::Data::Prefix.'posts WHERE `id`=? and `from`=? AND (`to` IS NULL OR `to`=`from`);';
    AltSimpleBoard::Data::dbh()->do( $sql, undef, $id, $from );
}
sub insert_post {
    my ( $f, $d, $c, $t ) = @_;
    die qq{Ersteller ungültig} unless get_username($f);
    die qq{Empfänger ungültig} if $t and not get_username($t);
    my $cid = $c ? get_category_id($c) : undef;
    my $sql = 'INSERT INTO '.$AltSimpleBoard::Data::Prefix.'posts (`from`, `to`, `text`, `posted`, `category`) VALUES (?, ?, ?, current_timestamp, ?)';
    AltSimpleBoard::Data::dbh()->do( $sql, undef, $f, $t, $d, $cid );
}

sub update_post {
    my ( $f, $d, $i, $t ) = @_;
    die qq{Bearbeiter ungültig} unless get_username($f);
    die qq{Empfänger ungültig} if $t and not get_username($t);
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'posts SET `text`=?, `posted`=current_timestamp, `to`=? WHERE `id`=? AND `from`=? AND (`to` IS NULL OR `to`=`from`);';
    AltSimpleBoard::Data::dbh()->do( $sql, undef, $d, $t, $i, $f );
}

sub update_user_stats {
    my $userid = shift;
    die qq{Benutzerid ungültig} unless $userid =~ m/\A\d+\z/xms;
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'users SET `lastseen`=current_timestamp WHERE `id`=?;';
    AltSimpleBoard::Data::dbh()->do( $sql, undef, $userid );
}

sub get_notes { _get_stuff( @_[ 0 .. 6 ], 'p.`from`=? AND p.`to`=p.`from`', $_[0]) }
sub get_forum { _get_stuff( @_[ 0 .. 6 ], 'p.`to` IS NULL' ) }
sub get_msgs  {
    my @params = ( $_[0], $_[0] );
    my $where = '( p.`from`=? OR p.`to`=? ) AND p.`from` <> p.`to`';
    if ( $_[7] ) {
        $where .= ' AND ( p.`from`=? OR p.`to`=? )';
        push @params, $_[7], $_[7];
    }
    return _get_stuff( @_[ 0 .. 6 ], $where, @params );
}

sub get_post {
    my $postid = shift;
    die q{Ungültige ID für den Beitrag} unless $postid =~ m/\A\d+\z/xms;
    my $where = 'p.`id`=?';
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
    return [] unless $userid;
    $page = 1 unless $page and $page =~ m/\A\d+\z/xms;
    my $sql =
        q{SELECT}
      . q{ p.`id`, p.`text`, p.`posted`,}
      . q{ c.`name`, COALESCE(c.`short`,''),}
      . q{ f.`id`, f.`name`, f.`active`,}
      . q{ t.`id`, t.`name`, t.`active`}
      . q{ FROM }            . $AltSimpleBoard::Data::Prefix . q{posts p}
      . q{ INNER JOIN }      . $AltSimpleBoard::Data::Prefix . q{users f ON f.`id`=p.`from`}
      . q{ LEFT OUTER JOIN } . $AltSimpleBoard::Data::Prefix . q{users t ON t.`id`=p.`to`}
      . q{ LEFT OUTER JOIN } . $AltSimpleBoard::Data::Prefix . q{categories c ON c.`id`=p.`category`}
      . q{ WHERE } . $where
      . ( $query ? q{ AND p.`text` LIKE ? } : '' )
      . q{ AND ( c.`short` = ? OR ( ( ? = '' OR ? IS NULL ) AND p.`category` IS NULL) )}
      . q{ ORDER BY p.`posted` DESC LIMIT ? OFFSET ?};

    return [ map { my $d = $_;
            $d = {
                text      => AltSimpleBoard::Data::Formats::format_text($d->[1], $c),
                start     => AltSimpleBoard::Data::Formats::format_text(do {(split /\n/, $d->[1])[0] // ''}, $c),
                raw       => $d->[1],
                active    => 0,
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
          ->selectall_arrayref( $sql, undef, @params, ( $query ? "%$query%" : () ), $cat, $cat, $cat,
            $AltSimpleBoard::Data::Limit,
            ( ( $page - 1 ) * $AltSimpleBoard::Data::Limit ) ) } ];
}

1;

