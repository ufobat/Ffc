package AltSimpleBoard::Data::Formats;

use 5.010;
use strict;
use warnings;
use utf8;
use Mojo::Util;
use Mojolicious::Plugin::DefaultHelpers;

sub format_timestamp {
    my $t = shift;
    if ( $t =~ m/(\d\d\d\d)-(\d\d)-(\d\d)\s+(\d\d):(\d\d):(\d\d)/xmsi ) {
        $t = sprintf '%d.%d.%d, %02d:%02d', $3, $2, $1, $4, $5;
    }
    return $t;
}

sub _xml_escape {
    my $s = shift;
    $s =~ s/\&/\&amp;/xmsg;
    $s =~ s/\<(?=\w)/\&lt;/xmgs;
    $s =~ s/(?<=\w)\>/\&gt;/xmgs;
    $s =~ s/"/\&quote;/xgms;
    return $s;
}
sub format_text {
    my $s = shift;
    my $c = shift;
    chomp $s;
    return '' unless $s;
    $s = _xml_escape($s);
    $s = _format_links($s);
    $s = _format_goodies($s);
    $s = _format_smilies($s, $c);
    $s =~ s{\n[\n\s]*}{</p>\n<p>}gsm;
    $s = "<p>$s</p>";
    return $s;
}

our %Goodies = qw( _ underline - linethrough + bold / italic ! alert);
sub _make_goody {
    my ( $marker, $string ) = @_;
    my $rem = "\\$marker";
    $string =~ s/$rem/ /gms;
    $string .= ' !!!' if $marker eq '!';
    return qq~<span class="$Goodies{$marker}">$string</span>~;
}
sub _format_goodies {
    my $s = shift;
    $s =~ s~([\_\-\+\/\!])([\_\-\+\/\!\w]+)\g1~_make_goody($1, $2)~xmsieg;
    return $s;
}

sub _make_link {
    my ( $start, $url, $end ) = @_;
    if ( $url =~ m(jpe?g|gif|bmp|png\z)xmsi ) {
        return qq~$start<a href="$url" title="Externes Bild" target="_blank"><img src="$url" class="extern" title="Externes Bild" /></a>$end~;
    }
    else {
        return qq~$end<a href="$url" title="Externe Webseite" target="_blank">$url</a>$end~;
    }
}

sub _format_links {
    my $s = shift;
    $s =~ s{([\(\s]|\A)(https?://[^\)\s]+)([\)\s]|\z)}{_make_link($1,$2,$3, @+)}xmseig;
    return $s;
}

our @Smilies = (
    [ smile      => [':)',  ':-)',  '=)',                         ] ],
    [ sad        => [':(',  ':-(',  '=(',                         ] ],
    [ crying     => [':,(',                                       ] ],
    [ sunny      => ['B)',  '8)',   'B-)',  '8-)',                ] ],
    [ twinkling  => [';)',  ';-)',                                ] ],
    [ laughting  => [':D',  '=D',   ':-D',  'LOL',                ] ],
    [ rofl       => ['XD',  'X-D',  'ROFL',                       ] ],
    [ unsure     => [':|',  ':-|',  '=|',                         ] ],
    [ yes        => ['(y)', '(Y)'                                 ] ],
    [ no         => ['(n)', '(N)',                                ] ],
    [ down       => ['-.-',                                       ] ],
    [ cats       => ['^^',                                        ] ],
    [ devilsmile => ['>:)', '>=)',  '>:-)',                       ] ],
    [ angry      => ['>:(', '>=(',  '>:-(',                       ] ],
    [ nope       => [':/',  ':-/',  '=/',   ':\\', ':-\\', '=\\', ] ],
);
our %Smiley = map {my ($n,$l)=($_->[0],$_->[1]); map {$_=>$n} @$l} @Smilies;
our $SmileyRe = join '|', map {s{([\^\<\-\.\:\\\/\(\)\=\|\,])}{\\$1}gxms; $_} keys %Smiley;
sub _make_smiley {
    my ( $c, $s, $x, $e ) = @_;
    my $y = $x;
    $y =~ s/\&/&lt;/xmsg;
    $y =~ s/\>/&gt;/xmsg;
    $y =~ s/\</&lt;/xmsg;
    return qq~$s<img class="smiley" src="~
        .$c->url_for("$AltSimpleBoard::Data::Theme/img/smileys/$Smiley{$x}.png")
        .qq~" alt="$y" />$e~;
}
sub _format_smilies {
    my $s = shift;
    my $c = shift;
    $s =~ s/(\s|\A)($SmileyRe)/_make_smiley($c, $1, $2, $3)/gmsxe;
    return $s;
}

1;

