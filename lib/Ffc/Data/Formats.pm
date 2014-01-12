package Ffc::Data::Formats;

use 5.010;
use strict;
use warnings;
use utf8;

use Carp;

use Ffc::Data;

our @Smilies = (
    [ look       => ['O.O', '0.0',                                ] ],
    [ what       => ['o.O', 'O.o',  'O.ò',  'ó.O',                ] ],
    [ smile      => [':)',  ':-)',  '=)',                         ] ],
    [ tongue     => [':P',  ':-P',  '=P',   ':p',  ':-p',  '=p',  ] ],
    [ ooo        => [':O',  ':-O',  '=O',   ':o',  ':-o',  '=o',  ] ],
    [ sad        => [':(',  ':-(',  '=(',                         ] ],
    [ crying     => [':,(', ':\'(',                               ] ],
    [ sunny      => ['B)',  '8)',   'B-)',  '8-)',                ] ],
    [ twinkling  => [';)',  ';-)',                                ] ],
    [ laughting  => [':D',  '=D',   ':-D',  'LOL',                ] ],
    [ rofl       => ['XD',  'X-D',  'ROFL',                       ] ],
    [ unsure     => [':|',  ':-|',  '=|',                         ] ],
    [ yes        => ['(y)', '(Y)',                                ] ],
    [ no         => ['(n)', '(N)',                                ] ],
    [ down       => ['-.-',                                       ] ],
    [ cats       => ['^^',                                        ] ],
    [ love       => ['<3',                                        ] ],
    [ devilsmile => ['>:)', '>=)',  '>:-)',                       ] ],
    [ angry      => ['>:(', '>=(',  '>:-(',                       ] ],
    [ evilgrin   => ['>:D', '>=D',  '>:-D',                       ] ],
    [ nope       => [':/',  ':-/',  '=/',   ':\\', ':-\\', '=\\', ] ],
    [ facepalm   => ['m(',                                        ] ],
);
our %Smiley     = map {my ($n,$l)=($_->[0],$_->[1]); map {$_=>$n} @$l} @Smilies;
our $SmileyRe   = join '|', map {s{([\^\<\-\.\:\\\/\(\)\=\|\,])}{\\$1}gxoms; $_} keys %Smiley;
our %Goodies    = qw( _ underline - linethrough + bold ~ italic ! alert * emotion);

sub format_timestamp {
    my $t = shift // return '';
    if ( $t =~ m/(\d\d\d\d)-(\d\d)-(\d\d)\s+(\d\d):(\d\d):(\d\d)/xmso ) {
        $t = sprintf '%02d.%02d.%04d, %02d:%02d', $3, $2, $1, $4, $5;
        return 'neu' if $t eq '00.00.0000, 00:00';
        my @time = localtime; $time[5] += 1900; $time[4]++;
#        $time[3]-- if $time[2] < 2;$time[2] -= 2; # FIXME Zeitzonenzeuch
        my $time = sprintf '%02d.%02d.%04d', @time[3,4,5];
        return 'jetzt' if $t eq sprintf "$time, \%02d:\%02d", @time[2,1];
        return substr $t, 12, 5 if $t =~ m/\A$time/xmos;
    }
    return $t;
}

sub _xml_escape {
    $_[0] =~ s/\&/\&amp;/gxmo;
    $_[0] =~ s/\<(?=[^3])/\&lt;/gxom;
    $_[0] =~ s/\>(?=[^\:\=])/\&gt;/goxm;
}
sub format_text {
    my $s = shift // '';
    my $c = shift;
    croak('Controller ungültig') unless $c;
    my $u = $c->session()->{user} // '';
    $s =~ s/\A\s+//gxmso;
    $s =~ s/\s+\z//gxmso;
    return '' unless $s;
    _xml_escape($s);
    $s =~ s{(\A|\s)"(\S.*?\S|\S)"(\W|\z)}{$1„<span class="quote">$2</span>“$3}gxom;
    $s =~ s{(?<!\S)(\@)?$u}{_make_username_mark($u, $1)}xgmsieo if $u;
    $s =~ s{(?<!\w)([\_\-\+\~\!\*])([\_\-\+\~\!\w\*]+)\g1(?!\w)}{_make_goody($1,$2)}gxmoes;
    $s =~ s{((?:[\(\s]|\A)?)(https?://[^\)\s]+?)(\)|,?\s|\z)}{_make_link($1,$2,$3,$c)}gxmeois;
    $s =~ s/(\(|\s|\A)($SmileyRe)/_make_smiley($1,$2,$c)/gmxeos;
    $s =~ s{\n[\n\s]*}{</p>\n<p>}xgmos;
    return "<p>$s</p>";
}

sub _make_username_mark {
    $_[1]
        ? qq(<span class="username"><span class="alert">$_[1]</span>$_[0]</span>)
        : qq(<span class="username">$_[0]</span>);

}

sub _make_goody {
    my ( $marker, $string ) = @_;
    my $rem = "\\$marker";
    $string =~ s/$rem/ /gms;
    $string .= ' !!!' if $marker eq '!';
    if ( exists $Goodies{$marker} ) {
        return qq~<span class="$Goodies{$marker}">$string</span>~;
    }
    else {
        return "$marker$string$marker";
    }
}

sub _make_link {
    my ( $start, $url, $end, $c ) = @_;
    $url =~ s/"/\%22/xmso;
    if ( $url =~ m(jpe?g|gif|bmp|png\z)xmsio ) {
        if ( $c->session()->{show_images} ) {
            return qq~$start<a href="$url" title="Externes Bild" target="_blank"><img src="$url" class="extern" title="Externes Bild" /></a>$end~;
        }
        else {
            my $url_xmlencode = $url;
            _xml_escape($url_xmlencode);
            my $url_show = $url_xmlencode;
            _stripped_url($url_xmlencode);
            return qq~$start<a href="$url" title="Externes Bild: $url_show" target="_blank">$url_xmlencode</a>$end~;
        }
    }
    else {
        my $url_xmlencode = $url;
        _xml_escape($url_xmlencode);
            my $url_show = $url_xmlencode;
        _stripped_url($url_xmlencode);
        return qq~$start<a href="$url" title="Externe Webseite: $url_show" target="_blank">$url_xmlencode</a>$end~;
    }
}

sub _stripped_url {
    if ( $Ffc::Data::URLShorten < length $_[0] ) {
        my $d = int( ( length($_[0]) - $Ffc::Data::URLShorten ) / 2 );
        my $h = int( length($_[0]) / 2 );
        $_[0] = substr($_[0], 0, $h - $d) . '…' . substr($_[0], $h + $d);
    }
    return $_[0];
}

sub _make_smiley {
    my $s = shift // '';
    my $y = my $x = shift // return '';
    my $c = shift;
    return "$s$x" unless $c->session()->{show_images};
    $y =~ s/\&/&lt;/xmsgo;
    $y =~ s/\>/&gt;/xmsgo;
    $y =~ s/\</&lt;/xmsgo;
#    $ext = 'svg' if $Smiley{$x} eq 'smile';
    return qq~$s<img class="smiley" src="~
        . $c->url_for("/$Ffc::Data::Themedir/".$c->session()->{theme}."/img/smileys/$Smiley{$x}.png")
        . qq~" alt="$y" />~;
}

1;

