package Ffc::Plugin::Formats;
use 5.010;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Plugin';

our @Smilies = (
    [ look       => ['O.O', '0.0',  'O_O',  '0_0',                ] ],
    [ what       => ['o.O', 'O.o',  'O.ò',  'ó.O',                ] ],
    [ smile      => [':)',  ':-)',  '=)',                         ] ],
    [ tongue     => [':P',  ':-P',  '=P',   ':p',  ':-p',  '=p',  ] ],
    [ ooo        => [':O',  ':-O',  '=O',   ':o',  ':-o',  '=o',  ] ],
    [ sad        => [':(',  ':-(',  '=(',                         ] ],
    [ crying     => [':,(', ':\'(',                               ] ],
    [ sunny      => ['8)',  'B-)',  '8-)',                        ] ],
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
#    [ yeah       => ['\o/', '\O/',  '\0/',                        ] ],
    [ shock      => [':$',  ':-$',  '=$',                         ] ],
    [ ironie     => ['</ironie>', '</irony>',                     ] ],
);
our %Smiley     = map {my ($n,$l)=($_->[0],$_->[1]); map {
    s~<~&lt;~gxmos; s~>~&gt;~gxmso; 
    $_=>$n
} @$l} @Smilies;
our $SmileyRe   = join '|', map {
    s{([\;\&\^\>\<\-\.\:\\\/\(\)\=\|\,\$])}{\\$1}gxoms;
    $_
} keys %Smiley;
our $HTMLRe = qr~ul|ol|pre|code|b|u|i|strike|h3|quote|li|em~;
our %HTMLHandle = (
#   tag => [ disable-p, disable-html ],
    ul   => [ 1, 0 ],
    ol   => [ 1, 0 ],
    pre  => [ 1, 1 ],
    code => [ 1, 1 ],
    h1   => [ 1, 0 ],
);

sub register {
    my ( $self, $app ) = @_;
    $app->helper( pre_format       => \&_pre_format_text  );
    $app->helper( username_format  => \&_username_format_text );
    $app->helper( format_timestamp => \&_format_timestamp );
}

sub _format_timestamp {
    my $t = $_[1] || return '';
    my $oj = $_[2] ? 0 : 1;
    if ( $t =~ m/(\d\d\d\d)-(\d\d)-(\d\d)\s+(\d\d):(\d\d)/xmso ) {
        $t = sprintf '%02d.%02d.%04d, %02d:%02d', $3, $2, $1, $4, $5;
        return 'neu' if $t eq '00.00.0000, 00:00';
        my @time = localtime; $time[5] += 1900; $time[4]++;
#        $time[3]-- if $time[2] < 2;$time[2] -= 2; # FIXME Zeitzonenzeuch
        my $time = sprintf '%02d.%02d.%04d', @time[3,4,5];
        return 'jetzt' if $oj and $t eq sprintf "$time, \%02d:\%02d", @time[2,1];
        return substr $t, 12, 5 if $t =~ m/\A$time/xmos;
    }
    return $t;
}

sub _username_format_text {
    my ( $c, $s ) = @_;
    my $u = my $xu = $c->session()->{user} // '';
    _xml_escape($xu);
    $s =~ s{(\s|\A)(\@?)$u}{_make_username_mark($xu, $1, $2)}xgmsie;
    return $s;
}

sub _pre_format_text_part {
#   controller, string, disable-p, disable-html
    my ( $c, $str, $dis_p, $dis_html ) = @_;
    return '' if $str =~ m/\A\s*\z/xmso;
    $str =~ s~(?:\r?\n\r?)+~\n~gxmsio;
    my $o = '';
    my $start = 0;
    unless ( $dis_html ) {
        while ( $str =~ m~<($HTMLRe)>(.+?)</\g1>~gxmsi ) {
            my ( $tag, $inner, $end, $newstart ) = ( $1, $2, $-[0], $+[0] );

            my ( $dis_p, $dis_html ) = ( $dis_p, $dis_html );
            if ( exists $HTMLHandle{$tag} ) {
                $dis_p    ||= $HTMLHandle{$tag}[0];
                $dis_html ||= $HTMLHandle{$tag}[1];
            }

            if ( $start < $end and not $dis_p ) {
                my $pre = substr($str, $start, $end - $start);
                _xml_escape($pre);
                if ( $pre =~ s~\n+~</p>\n<p>~gxmsio ) {
                    $pre = "<p>$pre</p>";
                }
                $o .= $pre;
            }

            $o .= "<$tag>" 
               .  _pre_format_text_part($c, $inner, $dis_p, $dis_html)
               .  "</$tag>";

            $start = $newstart;
        }
    }
    if ( $start < length $str ) {
        my $left;
        if ( $o ) {
            $left = substr( $str, $start, length($str) - $start );
        }
        else {
            $left = $str;
        }
        if ( $left  ) {
            _xml_escape($left);
            unless ( $dis_p ) {
                if ( $left =~ s~\n+~</p>\n<p>~gxmsio ) {
                    $left = "<p>$left</p>";
                }
            }
        }
        $o .= $left;
    }
    return $o;
}

sub _pre_format_text {
    my ( $c, $str ) = @_;
    my $o = _pre_format_text_part($c, $str);
    $o =~ s~<p>\s*</p>~~gxmso;
    $o =~ s~\b(?<url>https?://.+?)(?=\)|\s|\z|<)|(?<smile>$SmileyRe)~_make_sth($+{url}, $+{smile},$c)~gxmeios;
    #$o =~ s{($SmileyRe)}{_make_smiley($1,$2,$3,$c)}gmxeos;
    return $o;
}

sub _make_sth {
    my ( $url, $smile, $c ) = @_;
    if    ( $url   ) { return _make_link(   $url,   $c ) }
    elsif ( $smile ) { return _make_smiley( $smile, $c ) }
    else             { return ''                         }
}

sub _xml_escape {
    $_[0] =~ s/\&/\&amp;/gxmo;
    $_[0] =~ s/\</\&lt;/gxom;
    $_[0] =~ s/\>/\&gt;/goxm;
}

sub _make_username_mark {
    $_[2]
        ? qq($_[1]<span class="username"><span class="alert">$_[2]</span>$_[0]</span>)
        : qq($_[1]<span class="username">$_[0]</span>);

}

sub _make_link {
    my ( $url, $c ) = @_;
    $url =~ s/"/\%22/xmso;
    my $url_xmlencode = $url;
    _xml_escape($url_xmlencode);
    my $url_show = $url_xmlencode;
    _stripped_url($c, $url_xmlencode);
    return qq~<a href="$url" title="Externe Webseite: $url_show" target="_blank">$url_xmlencode</a>~;
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
    my ( $str, $c ) = @_;
    my $orig = $str;
    return qq~<img class="smiley" src="~
        . $c->url_for("/theme/img/smileys/$Smiley{$orig}.png")
        . qq~" alt="$str" title="$str" />~;
}

1;

