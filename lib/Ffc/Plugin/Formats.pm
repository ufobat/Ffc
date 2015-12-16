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
    [ yeah       => ['\o/', '\O/',  '\0/',                        ] ],
    [ shock      => [':$',  ':-$',  '=$',                         ] ],
    [ ironie     => ['</ironie>', '</irony>',                     ] ],
    [ sarcasm    => ['</sarcasm>',                                ] ],
    [ attention  => ['!!!',                                       ] ],
    [ joke       => ['!joke',                                     ] ],
    [ headbange  => ['\m/',                                       ] ],
);
our %Smiley     = map {my ($n,$l)=($_->[0],$_->[1]); map {
    #s~<~&lt;~gxmos; s~>~&gt;~gxmso; 
    $_=>$n
} @$l} @Smilies;
our $SmileyRe   = join '|', map {
    s{([\;\&\^\>\<\-\.\:\\\/\(\)\=\|\,\$])}{\\$1}gxoms;
    $_
} keys %Smiley;
our $HTMLBlockRe    = qr~pre|blockquote~io;
our $HTMLSinglRe    = qr~h3~io;
our $HTMLListRe     = qr~li|ol|ul~io;
our $HTMLStyleRe    = qr~code|b|u|i|strike|q|em~io;
our $HTMLEmptyTagRe = qr~hr~io;
our %HTMLHandle = (
#   tag        => [ disable-p, disable-html, set_n, disable-outer-p, disable-inner-blocks ],
    ul         => [ 1, 0, 1, 1, 0 ],
    ol         => [ 1, 0, 1, 1, 0 ],
    li         => [ 1, 0, 0, 1, 0 ],
    pre        => [ 1, 1, 1, 1, 0 ],
    code       => [ 1, 1, 0, 0, 0 ],
    blockquote => [ 0, 0, 1, 1, 0 ],
    h3         => [ 1, 0, 1, 1, 0 ],
    map({;$_   => [0,0,0,0,1]} qw(b u i strike q em)),
);

our $SmileyHandleRe = qr~(?<smileymatch>$SmileyRe)~o;
our $URLHandleRe = qr~(?<urlmatch>(?<url>https?://.+?))(?=,?(?:[\s<\)]|\z))~;
our $HTMLBlockHandleRe = qr~(?<htmlmatch>(?:<(?<tag>(?<btag>$HTMLBlockRe))>(?<inner>.+?)</\g{btag}>))~ms;
our $HTMLListHandleRe = qr~(?<htmlmatch>(?:<(?<tag>(?<ltag>$HTMLListRe))>(?<inner>.+?)</\g{ltag}>))~ms;
our $HTMLSinglHandleRe = qr~(?<htmlmatch>(?:<(?<tag>(?<btag>$HTMLSinglRe))>(?<inner>.+?)</\g{btag}>))~ms;
our $HTMLStyleHandleRe = qr~(?<htmlmatch>(?:<(?<tag>(?<stag>$HTMLStyleRe))>(?<inner>.+?)</\g{stag}>))~;
our $HTMLEmptyHandleRe = qr~(?:(?:\A|\n)\s*(?<htmlmatch><(?<tag>(?<etag>$HTMLEmptyTagRe))\s+/>)\s*(?:\n|\z))~m;
our $HTMLHandleRe = qr~(?:$HTMLBlockHandleRe|$HTMLListHandleRe|$HTMLSinglHandleRe|$HTMLEmptyHandleRe|$HTMLStyleHandleRe)~;
our $BigMatch = qr~(?<completematch>$HTMLHandleRe|$URLHandleRe|$SmileyHandleRe)~;
our $BigMatchWOBlock = qr~(?<completematch>(?:$HTMLStyleHandleRe)|$URLHandleRe|$SmileyHandleRe)~;
our $NoInStyleRe = qr~(?:$HTMLBlockHandleRe|$HTMLListHandleRe|$HTMLSinglHandleRe|$HTMLEmptyHandleRe)~;

sub register {
    my ( $self, $app ) = @_;
    $app->helper( pre_format       => \&_pre_format_text  );
    $app->helper( format_timestamp => \&_format_timestamp );
    $app->helper( format_short     => \&_format_short     );
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

sub _pre_format_text_part {
#   controller, string, disable-p, disable-html, insert in newlines, disable outer p, no smileys, no blocks
    my ( $c, $ostr, $lvl, $dis_p, $dis_html, $set_n, $dis_outer_p, $nosmil, $dis_block ) = @_;
    my $str = $ostr;
    if ( $str =~ m/\A\s*\z/xmso ) {
        return '';
    }
    $lvl ||= 0;
    $lvl++;
    $str =~ s~(?:\r?\n\r?)+~\n~gxmsio;
    my $o = '';
    my $start = 0;
    if ( $dis_html ) {
        my $nstr = _xml_escape($str);
        return $nstr;
    }
    else {
        my $str = $str;
        my $re = $dis_block ? $BigMatchWOBlock : $BigMatch;
        while ( $str =~ m~$BigMatch~xmgs ) {
            my ( $end, $newstart ) = ( $-[0], $+[0] );
#warn "\nSTART=$start, END=$end, NEWSTART=$newstart\n";
            my %m = ( %+ );

#warn 'OBACHT: "' . ($str//'') . "\"\n";
#warn '     LEVEL: ' . $lvl . "\n";

            if ( $start < $end )  {
#warn "    PLAIN\n";
#warn '    SUBSTR: "' .substr($str, $start, $end - $start). "\"\n";
                $o .= _format_plain_text( substr($str, $start, $end - $start), $dis_p, $dis_outer_p );
            }

            if ( $m{htmlmatch} ) {
#warn "     HTML!\n";
                my $dis_block ||= defined($m{tag}) && exists($HTMLHandle{$m{tag}}) && $HTMLHandle{$m{tag}}[4];
#warn '    BLOCKS: ' . ($dis_block ? 'no blocks' : 'blocks allowed') . "\n";
#warn '       TAG: "' . ($m{tag}//'') . "\"\n";
#warn '     INNER: "' . ($m{inner}//'') . "\"\n";
                $o .= _make_tag( $c, $m{tag}, $m{inner} // '', $lvl, $dis_p, $dis_html, $set_n, $dis_outer_p, $dis_block );
            }
            elsif ( $m{urlmatch} ) {
#warn "      URL!\n;";
#warn '     LINK: "' .($m{url}//''). "\"\n";
                $o .= _make_link( $c, $m{url} );
            }
            elsif ( $m{smileymatch} ) {
#warn "   SMILEY!\n;";
#warn '     FACE: "' .($m{smileymatch}//''). "\"\n";
#warn '   NOSMIL: ' .($nosmil ? 'true' : 'false'). "\n";
                $o .= _make_smiley( $c, $m{smileymatch}, $nosmil );
            }
#warn "\n";
            $start = $newstart;
        }
    }
    if ( $start < length( $str ) ) 
        { $o .= _format_plain_text(substr($str, $start, length($str) - $start), $dis_p ) }

    return $o;
}

sub _format_plain_text {
    my $str = shift;
    my $dis_p = shift;
    my $dis_outer_p = shift;
    my $nstr = _xml_escape( $str );
    unless ( $dis_p )
        { $nstr =~ s~\n+~</p>\n<p>~gsmxo }
    if ( $dis_outer_p ) {
        $nstr =~ s~\A\s*<p>~~gsmxo;
        $nstr =~ s~</p>\s*\z~~gsmxo;
    }
    return $nstr;
}

sub _pre_format_text {
    my $c = shift;
    my $str = shift;
    my $nosmil = shift;
    my $o = _pre_format_text_part($c, $str, (undef) x 5, $nosmil );
    return '' if $o =~ m/\A\s*\z/xmso;
    $o = "<p>$o</p>";
    $o =~ s~<p>\s*</p>~~gsimxo;
    return '' if $o =~ m/\A\s*\z/xmso;
    $o =~ s~</(blockquote|pre|h3|ul|ol)>\s*</p>~</$1>~gismx;
    $o =~ s~<blockquote>\s*</p>~<blockquote>~gsmiox;
    $o =~ s~<p>\s*<(blockquote|pre|h3|ul|ol)>~<$1>~gsimx;
    $o =~ s~<p>\s*</blockquote>~</blockquote>~gsiomx;
    $o =~ s~(?<!\A)<hr\s+/>(?!\z)~</p>\n<hr />\n<p>~gsiomx;
    $o =~ s~<($HTMLStyleRe)>\s*</p>\s*<hr\s+/>\s*<p>\s*</\1>~<$1>&lt;hr /&gt;</$1>~gsmio;
    $o =~ s~<p>\s*(&lt;\w+&gt;\s*&lt;/\w+&gt;\s*)*</p>~~gsmo;
    #$o =~ s~<p>\s*</p>~~gsimxo;
    $o =~ s~\n\n+~\n~gsmxo;
    $o =~ s~\A\s+~~smxo;
    $o =~ s~\s+\z~~smxo;
    chomp $o;
    return $o;
}

sub _make_tag {
    my ( $c, $tag, $inner, $lvl, $dis_p, $dis_html, $set_n, $dis_outer_p, $dis_block ) = @_;

    if ( exists $HTMLHandle{$tag} ) {
        $dis_p       ||= $HTMLHandle{$tag}[0];
        $dis_html    ||= $HTMLHandle{$tag}[1];
        $set_n       ||= $HTMLHandle{$tag}[2];
        $dis_outer_p ||= $HTMLHandle{$tag}[3];
        $dis_block   ||= $HTMLHandle{$tag}[4];
    }
    if ( $inner ) {
        if ( $dis_block ) {
            $inner =~ s~<(?<startofthetag>$NoInStyleRe)(?<insidethetag>(?:\s+/)?)>~\&lt;$+{startofthetag}$+{insidethetag}&gt;~gxms;
        }
        my $in = _pre_format_text_part($c, $inner, $lvl, $dis_p, $dis_html, undef, $dis_outer_p, undef, $dis_block );
        return '' if $in =~ m/\A\s+\z/xmso;
        return 
             ( $set_n ? "\n" : '' )
           . "<$tag>" . $in .  "</$tag>"
           . ( $set_n ? "\n" : '' );
    }
    elsif ( $tag =~ $HTMLEmptyTagRe ) {
        return "<$tag />";
    }
    else {
        return '';
    }
}

sub _xml_escape {
    my $str = shift;
    $str =~ s/\&/\&amp;/gxmo;
    $str =~ s/\</\&lt;/gxom;
    $str =~ s/\>/\&gt;/goxm;
    return $str;
}

sub _make_username_mark {
    $_[2]
        ? qq($_[1]<span class="username"><span class="alert">$_[2]</span>$_[0]</span>)
        : qq($_[1]<span class="username">$_[0]</span>);

}

sub _make_link {
    my ( $c, $url ) = @_;
    $url =~ s/"/\%22/xmso;
    my $url_xmlencode = $url;
    $url_xmlencode = _xml_escape($url_xmlencode);
    my $url_show = $url_xmlencode;
    $url_xmlencode = _stripped_url($c, $url_xmlencode);
    return qq~<a href="$url" title="Externe Webseite: $url_show" target="_blank">$url_xmlencode</a>~;
}

sub _stripped_url {
    return '' unless $_[1];
    my $u = $_[0]->configdata->{urlshorten};
    if ( $u and $u < length $_[1] ) {
        my $d = int( ( length($_[1]) - $u ) / 2 );
        my $h = int( length($_[1]) / 2 );
        return substr($_[1], 0, $h - $d) . '…' . substr($_[1], $h + $d);
    }
    return $_[1];
}

sub _make_smiley {
    my ( $c, $str, $nosmil ) = @_;
    return $str if $nosmil;
    my $orig = $str;
    return qq~<img class="smiley" src="~
        . $c->url_for("/theme/img/smileys/$Smiley{$orig}.png")
        . qq~" alt="$str" title="$str" />~;
}

sub _format_short {
    my ( $c, $str ) = @_;
    return '' unless $str;
    $str = substr($str,0,255);
    $str = _pre_format_text_part($c, $str, 1, 1, 1, 1);
    $str =~ s~</?["\s\w]+>~~gxmso;
    $str =~ s~</?["\s\w]*\z~~gxmso;
    $str =~ s~&lt;/?["\s\w]+&gt;~~gxmso;
    $str =~ s~&lt;/?["\s\w]*\z~~gxmso;
    chomp $str;
    return $str;
}

1;

