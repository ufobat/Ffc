package AltSimpleBoard::Data::Board;

use 5.010;
use strict;
use warnings;
use utf8;
use AltSimpleBoard::Data;

sub get_posts {
    my $data = AltSimpleBoard::Data::dbh()
      ->selectall_arrayref( 'SELECT id, user, time, text, parent FROM '.$AltSimpleBoard::Data::Prefix.'posts ORDER BY time asc'
        , undef );
    my %parents;
    my $pid = 1;
    for my $p ( @$data ) {
        my @t = localtime $p->[2];
        $t[5] += 1900; $t[4]++;
        $p->[2] = sprintf '%d.%d.%d, %d:%02d', @t[3,4,5,2,1];
        $p->[3] = format_text($p->[3]);
        $parents{$p->[4]} = $pid++ unless exists $parents{$p->[4]};
        $p->[4] = sprintf 'c%02d', $parents{$p->[4]};
    }
    $data->[-1]->[5] = 'new';
    return $data;
}

sub format_text {
    my $s = shift;
    return '' unless $s;
    $s = _bbcode($s);
    $s =~ s{\n}{</p>\n<p>}gsm;
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
    for my $c ( qw(u b i) ) {
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
    $s =~ s~\{SMILIES_PATH\}~$AltSimpleBoard::Data::PhpBBURL$AltSimpleBoard::Data::SmiliePath~gxmis;

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

