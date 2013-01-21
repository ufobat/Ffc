package AltSimpleBoard::Data::Formats;

use 5.010;
use strict;
use warnings;
use utf8;
use Mojo::Util;

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
    $s = _format_links($s);
    $s = _format_bbcode($s);
    $s =~ s{\n[\n\s]*}{</p>\n<p>}gsm;
    $s = "<p>$s</p>";
    return $s;
}

sub _format_links {
    my $s = shift;
    $s =~
s{(?:\s|\A)(https?://\S+\.(jpg|jpeg|gif|bmp|png))(?:\s|\z)}{<a href="$1" title="Externes Bild" target="_blank"><img src="$1" class="extern" title="Externes Bild" /></a>}xmsig;
    $s =~
s{([\(\s]|\A)(https?://\S+)([\(\s]|\z)}{$1<a href="$2" title="Externe Webseite" target="_blank">$2</a>$3}xmsig;
    $s =~ s{_(\w+)_}{<u>$1</u>}xmsig;
    return $s;
}

sub _format_bbcode {
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

