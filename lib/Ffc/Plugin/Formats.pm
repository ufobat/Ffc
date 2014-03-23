package Ffc::Plugin::Formats;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Plugin';

use 5.010;
use strict;
use warnings;
use utf8;

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

sub register {
    my ( $self, $app ) = @_;
    $app->helper( pre_format       => \&_pre_format_text  );
    $app->helper( post_format      => \&_post_format_text );
    $app->helper( format_timestamp => \&_format_timestamp );
}

sub _format_timestamp {
    my $t = $_[1] || return '';
    if ( $t =~ m/(\d\d\d\d)-(\d\d)-(\d\d)\s+(\d\d):(\d\d)/xmso ) {
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

sub _post_format_text {
    my ( $c, $s ) = @_;
    my $u = my $xu = $c->session()->{user} // '';
    return $s unless $u;
    _xml_escape($xu);
    $s =~ s{(?<!\S)(\@)?$u}{_make_username_mark($xu, $1)}xgmsie;
    return $s;
}

sub _pre_format_text {
    my ( $c, $s ) = @_;
    return '' if !$s or $s =~ m/\A\s*\z/xmso;
    $s =~ s/\A\s+//gxmso;
    $s =~ s/\s+\z//gxmso;
    _xml_escape($s);
    $s =~ s{(\A|\n)=\s*([^\n]+)(\z|\n)}{_make_heading($1, $2, $3)}gxomes;
    $s =~ s{(\A|\s)"(\S|\S.*?\S)"(\W|\z)}{_make_quote($1, $2, $3)}gxomes;
    $s =~ s{(?<!\w)([\_\-\+\~\!\*])([\_\-\+\~\!\w\*]+)\g1(?!\w)}{_make_goody($1,$2)}gxmoes;
    $s =~ s{((?:[\(\s]|\A)?)(https?://[^\)\s]+?)(\)|,?\s|\z)}{_make_link($1,$2,$3,$c)}gxmeis;
    $s =~ s/(\(|\s|\A)($SmileyRe)/_make_smiley($1,$2,$c)/gmxes;
    $s =~ s{\n[\n\s]*}{</p>\n<p>}xgmos;
    return "<p>$s</p>";
}

sub _xml_escape {
    $_[0] =~ s/\&/\&amp;/gxmo;
    $_[0] =~ s/\<(?=[^3])/\&lt;/gxom;
    $_[0] =~ s/\>(?=[^\:\=])/\&gt;/goxm;
}

sub _make_heading {
    my ( $s, $t, $e ) = @_;
    return "$s<h2>$t</h2>$e";
}

sub _make_quote {
    my ( $p, $q, $f ) = @_;
    $q =~ s{\n+}{</span>\n<span class="quote">}gxmso;
    return qq($p„<span class="quote">$q</span>“$f);
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
        return qq~$start<a href="$url" title="Externes Bild" target="_blank"><img src="$url" class="extern" title="Externes Bild" /></a>$end~;
    }
    else {
        my $url_xmlencode = $url;
        _xml_escape($url_xmlencode);
            my $url_show = $url_xmlencode;
        _stripped_url($c, $url_xmlencode);
        return qq~$start<a href="$url" title="Externe Webseite: $url_show" target="_blank">$url_xmlencode</a>$end~;
    }
}

sub _stripped_url {
    my $u = $_[0]->configdata->{urlshorten};
    if ( $u and $u < length $_[1] ) {
        my $d = int( ( length($_[1]) - $u ) / 2 );
        my $h = int( length($_[1]) / 2 );
        $_[1] = substr($_[1], 0, $h - $d) . '…' . substr($_[1], $h + $d);
    }
    return $_[1];
}

sub _make_smiley {
    my $s = shift // '';
    my $y = my $x = shift // return '';
    my $c = shift;
    $y =~ s/\&/&lt;/xmsgo;
    $y =~ s/\>/&gt;/xmsgo;
    $y =~ s/\</&lt;/xmsgo;
#    $ext = 'svg' if $Smiley{$x} eq 'smile';
    return qq~$s<img class="smiley" src="~
        . $c->url_for("/theme/img/smileys/$Smiley{$x}.png")
        . qq~" alt="$y" />~;
}

1;

