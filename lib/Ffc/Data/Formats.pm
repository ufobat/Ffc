package Ffc::Data::Formats;

use 5.010;
use strict;
use warnings;
use utf8;
use Ffc::Data;

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
    [ love       => ['<3',                                        ] ],
    [ devilsmile => ['>:)', '>=)',  '>:-)',                       ] ],
    [ angry      => ['>:(', '>=(',  '>:-(',                       ] ],
    [ evilgrin   => ['>:D', '>=D',  '>:-D',                       ] ],
    [ nope       => [':/',  ':-/',  '=/',   ':\\', ':-\\', '=\\', ] ],
);
our %Smiley           = map {my ($n,$l)=($_->[0],$_->[1]); map {$_=>$n} @$l} @Smilies;
our $SmileyRe         = join '|', map {s{([\^\<\-\.\:\\\/\(\)\=\|\,])}{\\$1}gxms; $_} keys %Smiley;
our %Goodies          = qw( _ underline - linethrough + bold ~ italic ! alert);

sub format_timestamp {
    my $t = shift;
    if ( $t =~ m/(\d\d\d\d)-(\d\d)-(\d\d)\s+(\d\d):(\d\d):(\d\d)/xmsi ) {
        $t = sprintf '%d.%d.%d, %02d:%02d', $3, $2, $1, $4, $5;
    }
    return $t;
}

sub _xml_escape {
    $_[0] =~ s/\&/\&amp;/gxm;
    $_[0] =~ s/\<(?=[^3])/\&lt;/gxm;
    $_[0] =~ s/\>(?=[^\:\=])/\&gt;/gxm;
    $_[0] =~ s/"/\&quot;/gxm;
}
sub format_text {
    my $s = shift;
    my $c = shift;
    $s =~ s/\A\s+//gxmsi;
    $s =~ s/\s+\z//gxmsi;
    return '' unless $s;
    _xml_escape($s);
    $s =~ s{(?<!\w)([\_\-\+\~\!])([\_\-\+\~\!\w]+)\g1(?!\w)}{_make_goody($1,$2)}gxmies;
    $s =~ s{([\(\s]|\A)(https?://[^\)\s]+)([\)\s]|\z)}{_make_link($1,$2,$3,$c)}gxmeis;
    $s =~ s/([\(\s]|\A)($SmileyRe)/_make_smiley($1,$2,$c)/gmxes;
    $s =~ s{\n[\n\s]*}{</p>\n<p>}xgms;
    $s = "<p>$s</p>";
    return $s;
}

sub _make_goody {
    my ( $marker, $string ) = @_;
    my $rem = "\\$marker";
    $string =~ s/$rem/ /gms;
    $string .= ' !!!' if $marker eq '!';
    return qq~<span class="$Goodies{$marker}">$string</span>~;
}

sub _make_link {
    my ( $start, $url, $end, $c ) = @_;
    my $t = $Ffc::Data::Themedir.$c->session()->{theme};
    if ( $url =~ m(jpe?g|gif|bmp|png\z)xmsi ) {
        if ( $c->session()->{show_images} ) {
            return qq~$start<a href="$url" title="Externes Bild" target="_blank"><img src="$url" class="extern" title="Externes Bild" /></a>$end~;
        }
        else {
            my $url_xmlencode = $url;
            _xml_escape($url_xmlencode);
            return qq~$start<a href="$url" title="Externes Bild" target="_blank"><img class="icon" src="~.$c->url_for("$t/img/icons/img.png").qq~" class="extern" title="Externes Bild" /> $url_xmlencode</a>$end~;
        }
    }
    else {
        my $url_xmlencode = $url;
        _xml_escape($url_xmlencode);
        return qq~$start<a href="$url" title="Externe Webseite" target="_blank">$url_xmlencode</a>$end~;
    }
}

sub _make_smiley {
    my $s = shift // '';
    my $y = my $x = shift // return '';
    my $c = shift;
    return "$x" unless $c->session()->{show_images};
    $y =~ s/\&/&lt;/xmsg;
    $y =~ s/\>/&gt;/xmsg;
    $y =~ s/\</&lt;/xmsg;
    return qq~$s<img class="smiley" src="~
        . $c->url_for("$Ffc::Data::Themedir/".$c->session()->{theme}."/img/smileys/$Smiley{$x}.png")
        . qq~" alt="$y" />~;
}

1;

