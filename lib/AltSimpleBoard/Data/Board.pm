package AltSimpleBoard::Data::Board;

use 5.010;
use strict;
use warnings;
use utf8;
use AltSimpleBoard::Data;
use Mojo::Util;

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

sub newmsgs {
    my $userid = shift;
    die qq{Benutzer unbekannt} unless get_username($userid);
    my $sql = 'SELECT p.`from`, f.`name`, count(p.`id`) FROM '.$AltSimpleBoard::Data::Prefix.'posts p INNER JOIN '.$AltSimpleBoard::Data::Prefix.'users f ON p.`from`=f.`id` WHERE `to` IS NOT NULL AND `to`=? AND `from` <> `to` GROUP BY p.`from`';
    return AltSimpleBoard::Data::dbh()->selectall_arrayref($sql, undef, $userid);
}

sub newmsgscount {
    my $userid = shift;
    die qq{Benutzer unbekannt} unless get_username($userid);
    my $sql = 'SELECT count(`id`) FROM '.$AltSimpleBoard::Data::Prefix.'posts WHERE `to` IS NOT NULL AND `to`=? AND `from` <> `to`';
    return (AltSimpleBoard::Data::dbh()->selectrow_array($sql, undef, $userid))[0];
}

sub notecount {
    my $userid = shift;
    die qq{Benutzer unbekannt} unless get_username($userid);
    my $sql = 'SELECT count(`id`) FROM '.$AltSimpleBoard::Data::Prefix.'posts WHERE `from`=? AND `to`=`from`';
    return (AltSimpleBoard::Data::dbh()->selectrow_array($sql, undef, $userid))[0];
}

sub allcategories {
    my $sql = 'SELECT c.`name`, c.`short` FROM '.$AltSimpleBoard::Data::Prefix.'categories c ORDER BY c.`id`';
    return AltSimpleBoard::Data::dbh()->selectall_arrayref($sql);
}
sub categories {
    my $sql = 'SELECT c.`name`, c.`short`, COUNT(p.`id`) FROM '.$AltSimpleBoard::Data::Prefix.'posts p INNER JOIN '.$AltSimpleBoard::Data::Prefix.'categories c ON p.`category` = c.`id` WHERE p.`to` IS NULL GROUP BY c.`id` ORDER BY c.`id`';
    return { map {$_->[0] => $_} @{ AltSimpleBoard::Data::dbh()->selectall_arrayref($sql) } };
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

sub post {
    my $id = shift;
    die qq{Postid ungültig} unless $id =~ m/\A\d+\z/xms;
    my $sql = q{SELECT p.`text`, COALESCE(c.`short`,'') FROM }.$AltSimpleBoard::Data::Prefix.'posts p LEFT OUTER JOIN '.$AltSimpleBoard::Data::Prefix.'categories c ON c.`id`=p.`category` WHERE p.`id`=?';
    return AltSimpleBoard::Data::dbh()->selectrow_array($sql, undef, $id);
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
    die qq{Kategorie ungültig} if $c and not get_category_id($c);
    my $sql = 'INSERT INTO '.$AltSimpleBoard::Data::Prefix.'posts (`from`, `to`, `text`, `posted`, `category`) VALUES (?, ?, ?, current_timestamp, (SELECT `id` FROM '.$AltSimpleBoard::Data::Prefix.'categories WHERE `short`=? LIMIT 1))';
    AltSimpleBoard::Data::dbh()->do( $sql, undef, $f, $t, $d, $c );
}

sub update_post {
    my ( $f, $d, $c, $i, $t ) = @_;
    die qq{Bearbeiter ungültig} unless get_username($f);
    die qq{Empfänger ungültig} if $t and not get_username($t);
    die qq{Kategorie ungültig} if $c and not get_category_id($c);
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'posts SET `text`=?, `posted`=current_timestamp, `to`=?, `category`=(SELECT `id` FROM '.$AltSimpleBoard::Data::Prefix.'categories WHERE `short`=? LIMIT 1) WHERE `id`=? AND `from`=? AND (`to` IS NULL OR `to`=`from`);';
    AltSimpleBoard::Data::dbh()->do( $sql, undef, $d, $t, $c, $i, $f );
}

sub update_user_stats {
    my $userid = shift;
    die qq{Benutzerid ungültig} unless $userid =~ m/\A\d+\z/xms;
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'users SET `lastseen`=current_timestamp WHERE `id`=?;';
    AltSimpleBoard::Data::dbh()->do( $sql, undef, $userid );
}

sub get_notes {
    get_stuff( @_[ 0 .. 5 ], 'p.`from`=? AND p.`to`=p.`from`', $_[0] );
}
sub get_forum { get_stuff( @_[ 0 .. 5 ], 'p.`to` IS NULL' ) }

sub get_msgs {
    my @params = ( $_[0], $_[0] );
    my $where = '( p.`from`=? OR p.`to`=? ) AND p.`from` <> p.`to`';
    if ( $_[6] ) {
        $where .= ' AND ( p.`from`=? OR p.`to`=? )';
        push @params, $_[6], $_[6];
    }
    get_stuff( @_[ 0 .. 5 ], $where, @params );
}

sub get_stuff {
    my $userid = shift;
    my $page   = shift;
    my $lasts  = shift;
    my $query  = shift;
    my $cat    = shift;
    my $act    = shift;
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
      . q{ AND ( c.`short` = ? OR ? = '' OR ? IS NULL )}
      . q{ ORDER BY p.`posted` DESC LIMIT ? OFFSET ?};

    return [ map { my $d = $_;
            {
                text      => format_text($d->[1]),
                timestamp => format_timestamp($d->[2]),
                ownpost   => $d->[5] == $userid && $act ne 'notes' ? 1 : 0,
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
            }
        } @{ AltSimpleBoard::Data::dbh()
          ->selectall_arrayref( $sql, undef, @params, ( $query ? "%$query%" : () ), $cat, $cat, $cat,
            $AltSimpleBoard::Data::Limit,
            ( ( $page - 1 ) * $AltSimpleBoard::Data::Limit ) ) } ];
}

sub format_timestamp {
    my $t = shift;
    if ( $t =~ m/(\d\d\d\d)-(\d\d)-(\d\d)\s+(\d\d):(\d\d):(\d\d)/xmsi ) {
        $t = sprintf '%d.%d.%d, %02d:%02d', $3, $2, $1, $4, $5;
    }
    return $t;
}

sub format_text {
    my $s = shift;
    chomp $s;
    return '' unless $s;
    $s = Mojo::Util::xml_escape($s);
    $s = _links($s);
    $s = _bbcode($s);
    $s =~ s{\n[\n\s]*}{</p>\n<p>}gsm;
    $s = "<p>$s</p>";
    return $s;
}

sub _links {
    my $s = shift;
    $s =~
s{(?:\s|\A)(https?://\S+\.(jpg|jpeg|gif|bmp|png))(?:\s|\z)}{<a href="$1" title="Externes Bild" target="_blank"><img src="$1" class="extern" title="Externes Bild" /></a>}xmsig;
    $s =~
s{(\s|\A)(https?://\S+)(\s|\z)}{$1<a href="$2" title="Externe Webseite" target="_blank">$2</a>$3}xmsig;
    $s =~ s{_(\w+)_}{<u>$1</u>}xmsig;
    return $s;
}

sub _bbcode {
    my $s = shift;

    # zitate
    $s =~ s~
        \[quote
            (?:=(?:"|&quot;)(?<cite>.+?)(?:"|&quot;)|(?<cite>))
            (?<mark>(?:\:\w+?)?)
        \]
        (?<text>.+?)
        \[/quote\k{mark}\]
        ~<blockquote cite="$+{cite}">$+{text}</blockquote>~gmxis;

    # textmarkierungen
    for my $c (qw(u b i)) {
        $s =~ s~
            \[$c
                ((?:\:\w+?)?)
            \]
            (.+?)
            \[/$c\1\]
            ~<$c>$2</$c>~gxmis;
    }

    # Bilder und Smilies
    $s =~ s~
        \[img
            (?<mark>(?:\:\w+?)?)
        \]
        (?<src>.+?)
        \[/img\k{mark}\]
        ~<img src="$+{src}" />~gxmis;

    # Links
    $s =~ s~
        \[url
            (?:=(?:"|&quot;)?(?<url>.+?)(?:"|&quot;)?)
            (?<mark>(?:\:\w+?)?)
        \]
        (?<title>.+?)
        \[/url\k{mark}\]
        ~<a href="$+{url}">$+{title}</a>~gxmis;

    # Farben
    $s =~ s~
        \[color
            (?:=(?:"|&quot;)?(?<color>\#[0-9a-f]{3}(?:[0-9a-f]{3})?)(?:"|&quot;)?)
            (?<mark>(?:\:\w+?)?)
        \]
        (?<text>.+?)
        \[/color\k{mark}\]
        ~<span style="color:$+{color}">$+{text}</span>~gxims;
    return $s;
}

1;

