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
    $s =~ s/\A\s+(?:\r?\n\r?)+//gxmso;
    $s =~ s/\s+\z//gxmso;
    _xml_escape($s);
    my $o = '';
    my ( $ul, $ol, $q, $pre, $bq ) = ( 0, 0, 0, 0, 0 );
    for my $s ( split /(?:\r?\n\r?)+/, $s ) {
        # normal text
        next if $s =~ m/\A\s*\z/xmso;
        
        my $mqs = 0;
        my $h3 = 0;

        unless ( $pre ) { # normal text gets formatted

            # multiline quote
            if ( !$q and $s =~ s~\A([^"]*)"([^"\s][^"]*)\z~$1„<span class="quote">$2~gxmso ) {
                $q = 1;
                $mqs = 1;
            }
            elsif ( !$mqs and $q and $s =~ s~(\A[^"]*[^"\s])"([^"]*)~<span class="quote">$1</span>“$2~gxmso ) {
                $q = 0;
            }

            # normal inline quoting and backticked codesnippets
            for my $w ( [q{"}, q{"}, 'quote', q{„}, q{“} ],
                        [q{`}, q{`}, 'code',  q{`}, q{`} ],
            ) {
                $s =~ s{(\A|\s)$w->[0](\S|\S.*?\S)$w->[1](\W|\z)}{$1$w->[3]<span class="$w->[2]">$2</span>$w->[4]$3}gxms;
            }
            
            # normal text
            $h3 = 1 if $s =~ s{\A=\s*([^\n]+)\z}{<h3>$1</h3>}gxoms;

            $s =~ s{(?<!\w)([\_\-\+\~\!\*])([\_\-\+\~\!\w\*]+)\g1(?!\w)}{_make_goody($1,$2)}gxmoes;
            $s =~ s{((?:[\(\s]|\A)?)(https?://[^\)\s]+?)(\)|,?\s|\z)}{_make_link($1,$2,$3,$c)}gxmeios;
            $s =~ s/(\(|\s|\A)($SmileyRe)/_make_smiley($1,$2,$c)/gmxeos;

            # unordered lists
            if ( $s =~ m/\A\s*-\s*(.+)\z/xmso ) {
                unless ( $ul ) {
                    $ul = 1;
                    $o .= "<ul>\n";
                }
                $o .= "<li>$1</li>";
            }
            elsif ( $ul ) {
                $o .= "</ul>\n";
                $ul = 0;
            }

            # ordered lists
            if ( $s =~ m/\A\s*\#\s*(.+)\z/xmso ) {
                unless ( $ol ) {
                    $ol = 1;
                    $o .= "<ol>\n";
                }
                $o .= "<li>$1</li>";
            }
            elsif ( $ol ) {
                $o .= "</ol>\n";
                $ol = 0;
            }

            # blockquotes
            if ( $s =~ m/\A\s*\|\s*(.+)\z/xmso ) {
                unless ( $bq ) {
                    $bq = 1;
                    $o .= "<blockquote>\n";
                }
                $o .= "<p>$1";
            }
            elsif ( $bq ) {
                $o .= "</blockquote>\n";
                $bq = 0;
            }

        } # end of normal text (no pre)
        
        # preformatted text
        if ( $s =~ m/\A\s(.+?)\s*\z/xmso ) {
            unless ( $pre ) {
                $pre = 1;
                $o .= "<pre>\n";
            }
            $o .= $1;
        }
        elsif ( $pre ) {
            $o .= "</pre>\n";
            $pre = 0;
        }
        
        # normal text
        unless ( $ul or $ol or $bq or $h3 or $pre ) {
            $o .= '<p>';
        }
        # multiline quoting beginnen
        if ( $q and not $mqs ) {
            $o .= qq~<span class="quote">~;
        }
        # normal text
        unless ( $ul or $ol or $bq or $pre ) {
            $o .= $s;
        }
        # multiline quoting abschliessen
        if ( $q ) {
            $o .= qq~</span>~;
        }
        # normal text
        unless ( $ul or $ol or $h3 or $pre ) {
            $o .= '</p>';
        }
        $o .= "\n";
    }
    $o .= '</ul>' if $ul;
    $o .= '</ol>' if $ol;
    $o .= '</pre>' if $pre;
    $o .= '</blockquote>' if $bq;
    chomp $o;
    return $o;
}

sub _xml_escape {
    $_[0] =~ s/\&/\&amp;/gxmo;
    $_[0] =~ s/\<(?=[^3])/\&lt;/gxom;
    $_[0] =~ s/\>(?=[^\:\=])/\&gt;/goxm;
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
    my $url_xmlencode = $url;
    _xml_escape($url_xmlencode);
        my $url_show = $url_xmlencode;
    _stripped_url($c, $url_xmlencode);
    return qq~$start<a href="$url" title="Externe Webseite: $url_show" target="_blank">$url_xmlencode</a>$end~;
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
        . qq~" alt="$y" title="$y" />~;
}

1;

