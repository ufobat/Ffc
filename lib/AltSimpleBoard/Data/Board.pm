package AltSimpleBoard::Data::Board;

use 5.010;
use strict;
use warnings;
use utf8;
use AltSimpleBoard::Data;

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

sub username {
    my $id = shift;
    my $sql = 'SELECT `name` FROM '.$AltSimpleBoard::Data::Prefix.'users WHERE `id`=?';
    return (AltSimpleBoard::Data::dbh()->selectrow_array($sql, undef, $id))[0];
}

sub post {
    my $id = shift;
    my $sql = 'SELECT `text` FROM '.$AltSimpleBoard::Data::Prefix.'posts WHERE `id`=?';
    return (AltSimpleBoard::Data::dbh()->selectrow_array($sql, undef, $id))[0];
}

sub delete {
    my ( $from, $id ) = @_;
    my $sql = 'DELETE FROM '.$AltSimpleBoard::Data::Prefix.'posts WHERE `id`=? and `from`=? AND (`to` IS NULL OR `to`=`from`);';
    AltSimpleBoard::Data::dbh()->do( $sql, undef, $id, $from );
}
sub insert {
    my ( $f, $d, $t ) = @_;
    my $sql = 'INSERT INTO '.$AltSimpleBoard::Data::Prefix.'posts (`from`, `to`, `text`, `posted`) VALUES (?, ?, ?, current_timestamp)';
    AltSimpleBoard::Data::dbh()->do( $sql, undef, $f, $t, $d );
}

sub update {
    my ( $f, $d, $i, $t ) = @_;
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'posts SET `text`=?, `posted`=current_timestamp, `to`=? WHERE `id`=? AND `from`=? AND (`to` IS NULL OR `to`=`from`);';
    AltSimpleBoard::Data::dbh()->do( $sql, undef, $d, $t, $i, $f );
}

sub update_user_stats {
    my $userid = shift;
    return unless $userid;
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'users SET `lastseen`=current_timestamp WHERE `id`=?;';
    AltSimpleBoard::Data::dbh()->do( $sql, undef, $userid );
}

sub get_notes {
    get_stuff( @_[ 0 .. 4 ], 'p.`from`=? AND p.`to`=p.`from`', $_[0] );
}
sub get_forum { get_stuff( @_[ 0 .. 4 ], 'p.`to` IS NULL' ) }

sub get_msgs {
    my @params = ( $_[0], $_[0] );
    my $where = '( p.`from`=? OR p.`to`=? ) AND p.`from` <> p.`to`';
    if ( $_[4] ) {
        $where .= ' AND ( p.`from`=? OR p.`to`=? )';
        push @params, $_[4], $_[4];
    }
    get_stuff( @_[ 0 .. 4 ], $where, @params );
}

sub get_stuff {
    my $userid = shift;
    my $page   = shift;
    my $lasts  = shift;
    my $query  = shift;
    my $cat    = shift;
    my $where  = shift;
    my @params = @_;
    return [] unless $userid;
    $page = 1 unless $page;
    my $sql =
        'SELECT p.`id`, p.`from`, f.`name`, p.`posted`, p.`text`, f.`active`, p.`to`, t.`name` FROM '
      . $AltSimpleBoard::Data::Prefix . 'posts p INNER JOIN '
      . $AltSimpleBoard::Data::Prefix . 'users f ON f.`id`=p.`from` LEFT OUTER JOIN '
      . $AltSimpleBoard::Data::Prefix . 'users t ON t.`id`=p.`to` '
      . ' WHERE ' . $where
      . ( $query ? ' AND p.`text` LIKE ?' : '' )
      . ' AND ( p.`category` = ? OR ? IS NULL )'
      . ' ORDER BY p.`posted` DESC LIMIT ? OFFSET ?';
    my $data =
      AltSimpleBoard::Data::dbh()
      ->selectall_arrayref( $sql, undef, @params, ( $query ? "%$query%" : () ), $cat, $cat,
        $AltSimpleBoard::Data::Limit,
        ( ( $page - 1 ) * $AltSimpleBoard::Data::Limit ) );

    for my $i ( 0 .. $#$data ) {
        given ( $data->[$i] ) {
            $_->[4] = format_text( $_->[4] );
            $_->[8] = format_timestamp( $_->[3] );
            $_->[9] = $_->[3] && $lasts && $_->[3] =~ m/\A\d+\z/xmsi && $lasts =~ m/\A\d+\z/xmsi && $_->[3] > $lasts; #FIXME
        }
    }
    return $data;
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
    return '' unless $s;
    $s = _bbcode($s);
    $s =~ s{\n+}{</p>\n<p>}gsm;
    $s = "<p>$s</p>";
    return $s;
}

sub _bbcode {
    my $s = shift;

    # zitate
    $s =~ s~
        \[quote
            (?:=(?:"|&quot;)(?<cite>.+?)(?:"|&quot;))?
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

