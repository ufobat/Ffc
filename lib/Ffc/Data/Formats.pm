package Ffc::Data::Formats;

use 5.010;
use strict;
use warnings;
use utf8;

use Carp;

use Ffc::Data;

our @Smilies = (
    [ look       => ['O.O', '0.0'                                 ] ],
    [ what       => ['o.O', 'O.o',  'O.ò',  'ó.O'                 ] ],
    [ smile      => [':)',  ':-)',  '=)',                         ] ],
    [ tongue     => [':P',  ':-P',  '=P',   ':p',  ':-p',  '=p'   ] ],
    [ ooo        => [':O',  ':-O',  '=O',   ':o',  ':-o',  '=o'   ] ],
    [ sad        => [':(',  ':-(',  '=(',                         ] ],
    [ crying     => [':,(', ':\'('                                ] ],
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
    my $t = shift // return '';
    if ( $t =~ m/(\d\d\d\d)-(\d\d)-(\d\d)\s+(\d\d):(\d\d):(\d\d)/xmsi ) {
        $t = sprintf '%02d.%02d.%04d, %02d:%02d', $3, $2, $1, $4, $5;
        return 'neu' if $t eq '00.00.0000, 00:00';
        my @time = localtime; $time[5] += 1900; $time[4]++;
        my $time = sprintf '%02d.%02d.%04d', @time[3,4,5];
        return 'jetzt' if $t eq sprintf "$time, \%02d:\%02d", @time[2,1];
        return substr $t, 12, 5 if $t =~ m/\A$time/xms;
    }
    return $t;
}

sub _xml_escape {
    $_[0] =~ s/\&/\&amp;/gxm;
    $_[0] =~ s/\<(?=[^3])/\&lt;/gxm;
    $_[0] =~ s/\>(?=[^\:\=])/\&gt;/gxm;
    $_[0] =~ s{(\A|\s)"(\S.*?\S|\S)"(\W|\z)}{$1„<span class="quote">$2</span>“$3}gxm;
}
sub format_text {
    my $s = shift // '';
    my $c = shift;
    croak('Controller ungültig') unless $c;
    my $u = $c->session()->{user} // '';
    $s =~ s/\A\s+//gxmsi;
    $s =~ s/\s+\z//gxmsi;
    return '' unless $s;
    _xml_escape($s);
    $s =~ s{$u}{<span class="username">$u</span>}xmsi if $u;
    $s =~ s{(?<!\w)([\_\-\+\~\!])([\_\-\+\~\!\w]+)\g1(?!\w)}{_make_goody($1,$2)}gxmies;
    $s =~ s{(\(|\s|\A)(https?://[^\)\s]+)([\)\s]|\z)}{_make_link($1,$2,$3,$c)}gxmeis;
    $s =~ s/(\(|\s|\A)($SmileyRe)/_make_smiley($1,$2,$c)/gmxes;
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
    $url =~ s/"/\%22/xms;
    if ( $url =~ m(jpe?g|gif|bmp|png\z)xmsi ) {
        if ( $c->session()->{show_images} ) {
            return qq~$start<a href="$url" title="Externes Bild" target="_blank"><img src="$url" class="extern" title="Externes Bild" /></a>$end~;
        }
        else {
            my $url_xmlencode = $url;
            _xml_escape($url_xmlencode);
            return qq~$start<a href="$url" title="Externes Bild" target="_blank">$url_xmlencode</a>$end~;
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
    return "$s$x" unless $c->session()->{show_images};
    $y =~ s/\&/&lt;/xmsg;
    $y =~ s/\>/&gt;/xmsg;
    $y =~ s/\</&lt;/xmsg;
    my $ext = 'png';
#    $ext = 'svg' if $Smiley{$x} eq 'smile';
    return qq~$s<img class="smiley" src="~
        . $c->url_for("$Ffc::Data::Themedir/".$c->session()->{theme}."/img/smileys/$Smiley{$x}.$ext")
        . qq~" alt="$y" />~;
}

1;

