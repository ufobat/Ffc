package AltSimpleBoard::Data::Board;

use 5.010;
use strict;
use warnings;
use utf8;
use AltSimpleBoard::Data;

sub get_msgs { get_stuff( @_[0,1], 'p."to"=?' ) }

sub get_posts { get_stuff( @_[0,1], 'p."to" IS NULL OR p."to"=?' ) }

sub get_stuff {
    my ( $userid, $page, $where ) = @_;
    return [] unless $userid;
    $page = 1 unless $page;
    my $data = AltSimpleBoard::Data::dbh()->selectall_arrayref(
        'SELECT p."id", p."from", u."name", p."posted", p."text" FROM'
          . ' '.$AltSimpleBoard::Data::Prefix.'posts p INNER JOIN'
          . ' '.$AltSimpleBoard::Data::Prefix.'users u ON u."id"=p."from"'
          . ' WHERE '.$where 
          . ' ORDER BY p."posted" DESC'
          . ' LIMIT ? OFFSET ?',
        undef, $userid, $AltSimpleBoard::Data::Limit, ( ( $page - 1 ) * $AltSimpleBoard::Data::Limit )
    );
    for my $i ( 0 .. $#$data ) {
        given ( $data->[$i] ) {
            $_->[4] = format_text( $_->[4] );
            $_->[5] = format_timestamp( $_->[3] );
        }
    }
    return $data;
}

sub format_timestamp {
    my @t = localtime shift;
    $t[5] += 1900;
    $t[4]++;
    return sprintf '%d.%d.%d, %d:%02d', @t[ 3, 4, 5, 2, 1 ];
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
    $s =~
s~\{SMILIES_PATH\}~$AltSimpleBoard::Data::PhpBBURL$AltSimpleBoard::Data::SmiliePath~gxmis;

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

