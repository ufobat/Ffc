package AltSimpleBoard::Data::Board;

use 5.010;
use strict;
use warnings;
use utf8;
use AltSimpleBoard::Data;
use Mojo::Util;

sub newmsgs {
    my $userid = shift;
    my $sql = 'SELECT p.`from`, f.`name`, count(p.`id`) FROM '.$AltSimpleBoard::Data::Prefix.'posts p INNER JOIN '.$AltSimpleBoard::Data::Prefix.'users f ON p.`from`=f.`id` WHERE `to` IS NOT NULL AND `to`=? AND `from` <> `to` GROUP BY p.`from`';
    return AltSimpleBoard::Data::dbh()->selectall_arrayref($sql, undef, $userid);
}

sub newmsgscount {
    my $userid = shift;
    my $sql = 'SELECT count(`id`) FROM '.$AltSimpleBoard::Data::Prefix.'posts WHERE `to` IS NOT NULL AND `to`=? AND `from` <> `to`';
    return (AltSimpleBoard::Data::dbh()->selectrow_array($sql, undef, $userid))[0];
}

sub notecount {
    my $userid = shift;
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
sub _get_category_id {
    my $c = shift;
    my $sql = '';
    my $cats = AltSimpleBoard::Data::dbh()->selectall_arrayref($sql, undef, $c);
    return unless @$cats;
    return $cats->[0]->[0];
}

sub username {
    my $id = shift;
    my $sql = 'SELECT `name` FROM '.$AltSimpleBoard::Data::Prefix.'users WHERE `id`=?';
    return (AltSimpleBoard::Data::dbh()->selectrow_array($sql, undef, $id))[0];
}

sub post {
    my $id = shift;
    my $sql = q{SELECT p.`text`, COALESCE(c.`short`,'') FROM }.$AltSimpleBoard::Data::Prefix.'posts p LEFT OUTER JOIN '.$AltSimpleBoard::Data::Prefix.'categories c ON c.`id`=p.`category` WHERE p.`id`=?';
    return AltSimpleBoard::Data::dbh()->selectrow_array($sql, undef, $id);
}

sub delete {
    my ( $from, $id ) = @_;
    my $sql = 'DELETE FROM '.$AltSimpleBoard::Data::Prefix.'posts WHERE `id`=? and `from`=? AND (`to` IS NULL OR `to`=`from`);';
    AltSimpleBoard::Data::dbh()->do( $sql, undef, $id, $from );
}
sub insert {
    my ( $f, $d, $c, $t ) = @_;
    my $sql = 'INSERT INTO '.$AltSimpleBoard::Data::Prefix.'posts (`from`, `to`, `text`, `posted`, `category`) VALUES (?, ?, ?, current_timestamp, (SELECT `id` FROM '.$AltSimpleBoard::Data::Prefix.'categories WHERE `short`=? LIMIT 1))';
    AltSimpleBoard::Data::dbh()->do( $sql, undef, $f, $t, $d, $c );
}

sub update {
    my ( $f, $d, $c, $i, $t ) = @_;
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'posts SET `text`=?, `posted`=current_timestamp, `to`=?, `category`=(SELECT `id` FROM '.$AltSimpleBoard::Data::Prefix.'categories WHERE `short`=? LIMIT 1) WHERE `id`=? AND `from`=? AND (`to` IS NULL OR `to`=`from`);';
    AltSimpleBoard::Data::dbh()->do( $sql, undef, $d, $t, $c, $i, $f );
}

sub update_user_stats {
    my $userid = shift;
    return unless $userid;
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
    $page = 1 unless $page;
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

