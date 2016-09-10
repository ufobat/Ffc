package Ffc::Plugin::Formats;
use 5.18.0;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Util 'xml_escape';

###############################################################################
# Smiley-Definitionen
my @Smilies = (
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
    [ yes        => ['(y)', '(Y)',  ':yes:',                      ] ],
    [ no         => ['(n)', '(N)',  ':no:',                       ] ],
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

###############################################################################
# Definitionen der HTML-Tag-Elemente für die Formatierungen
my $HTMLBlockRe    = qr~pre|blockquote~io;
my $HTMLSinglRe    = qr~h3~io;
my $HTMLListRe     = qr~li|ol|ul~io;
my $HTMLStyleRe    = qr~code|b|u|i|strike|q|em~io;
my $HTMLEmptyTagRe = qr~hr~io;
my %HTMLHandle = (
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

###############################################################################
# App-Helper registrieren
sub register {
    my ( $self, $app ) = @_;
    # Das Formatieren von Beiträgen und in reduzierter Form auch Chatnachrichten
    $app->helper( pre_format       => \&_pre_format_text  );
    # Zeitstempel auf Maß bringen (inkl. "jetzt" und so)
    $app->helper( format_timestamp => \&_format_timestamp ); 
    # Formatierung für Zusammenfassung der neuesten Beiträge für die Themenliste
    $app->helper( format_short     => \&_format_short     ); 
}

###############################################################################
# Vorbereitung der Definitionen für die Weiterverarbeitung

# Umwandlung in eine Hashmap zur besseren Verarbeitung
my %Smiley     = map { my ( $n, $l )= @$_; map { $_=>$n } @$l} @Smilies;
# Escapen der RegEx-Sonderzeichen in den Smiley-Definitionen aus der weiterverwendeten Hash-Map
my $SmileyRe   = join '|', map { s{([\;\&\^\>\<\-\.\:\\\/\(\)\=\|\,\$])}{\\$1}gxoms; $_ } keys %Smiley;
# Smiley-Math-Capture
my $SmileyHandleRe = qr~(?<smileymatch>$SmileyRe)~o;
# Diverse HTML-Tag-Handle-Captures
my $URLHandleRe = qr~(?<urlmatch>(?<url>https?://.+?))(?=,?(?:[\s<\)\]]|\z))~o;
my $HTMLBlockHandleRe = qr~(?<htmlmatch>(?:<(?<tag>(?<btag>$HTMLBlockRe))>(?<inner>.+?)</\g{btag}>))~ms;
my $HTMLListHandleRe = qr~(?<htmlmatch>(?:<(?<tag>(?<ltag>$HTMLListRe))>(?<inner>.+?)</\g{ltag}>))~ms;
my $HTMLSinglHandleRe = qr~(?<htmlmatch>(?:<(?<tag>(?<btag>$HTMLSinglRe))>(?<inner>.+?)</\g{btag}>))~ms;
my $HTMLStyleHandleRe = qr~(?<htmlmatch>(?:<(?<tag>(?<stag>$HTMLStyleRe))>(?<inner>.+?)</\g{stag}>))~;
my $HTMLEmptyHandleRe = qr~(?:(?:\A|\n)\s*(?<htmlmatch><(?<tag>(?<etag>$HTMLEmptyTagRe))\s+/>)\s*(?:\n|\z))~mo;
# Sammlung der Captures zur globalen Regex
my $HTMLHandleRe = qr~(?:$HTMLBlockHandleRe|$HTMLListHandleRe|$HTMLSinglHandleRe|$HTMLEmptyHandleRe|$HTMLStyleHandleRe)~;
my $BigMatch = qr~(?<completematch>$HTMLHandleRe|$URLHandleRe|$SmileyHandleRe)~;
my $NoInStyleRe = qr~(?:$HTMLBlockHandleRe|$HTMLListHandleRe|$HTMLSinglHandleRe|$HTMLEmptyHandleRe)~;

###############################################################################
# Zeitstempel zurecht formatieren
sub _format_timestamp {
    my $t = $_[1] // return '';
    my $oj = $_[2] ? 0 : 1;
    # Übliches Format (z.B. aus der Datenbank) auswerten
    if ( $t =~ m/(\d\d\d\d)-(\d\d)-(\d\d)\s+(\d\d):(\d\d)/xmso ) {
        # In die gewünschte Form bringen
        $t = sprintf '%02d.%02d.%04d, %02d:%02d', $3, $2, $1, $4, $5;
        # Sonderfälle behandeln
        return 'neu' if $t eq '00.00.0000, 00:00';
        my @time = localtime; $time[5] += 1900; $time[4]++; # Aktuellen Zeitpunkt raus holen
        my $time = sprintf '%02d.%02d.%04d', @time[3,4,5];  # Aktuellen Zeitpunkt auf Linie formatieren
        return 'jetzt' if $oj and $t eq sprintf "$time, \%02d:\%02d", @time[2,1]; # Jetzt ...
        return substr $t, 12, 5 if $t =~ m/\A$time/xmos;                          # ... oder heute
    }
    # Im Zweifelsfall einfach den String ohne Veränderung zurück liefern
    return $t;
}

###############################################################################
# Teil-Formatierung für iterativen Durchlauf des HTML-angelehnten Markup-Baumes
sub _pre_format_text_part {
#   controller, string, stacklevel, disable-p, disable-html, insert in newlines, no smileys, no blocks
    my ( $c, $ostr, $lvl, $dis_p, $dis_html, $set_n, $nosmil, $dis_block ) = @_;
    my $str = $ostr; # Ich arbeite hier auf einer Kopie

    # Leerstrings fallen von vorn herein raus, Zeilenumbrüche werden normalisiert
    $str =~ m/\A\s*\z/xmso and return '';
    $str =~ s~(?:\r?\n\r?)+~\n~gxmsio;
    # Ist HTML-Formatierung abgeschalten, wird der String lediglich XML-Escaped zurück gegeben, mehr passiert da nicht
    $dis_html and return xml_escape($str);
    
    # Schachtelungs-Level mitzählen
    $lvl ||= 0; $lvl++;

    # Ausgabe-String-Container vorbereiten 
    my $o = '';
    # Die Formatierung in diesem Teil der Abarbeitung beginnt an erster Stelle des übergebenen Strings, logisch
    my $start = 0;

    # Und wieder nur auf einer Kopie
    my $lstr = $str;
    while ( $lstr =~ m~$BigMatch~xmgs ) {
        my ( $end, $newstart ) = ( $-[0], $+[0] );
#warn "\nSTART=$start, END=$end, NEWSTART=$newstart\n";
        my %m = ( %+ );

#warn 'OBACHT: "' . ($str//'') . "\"\n";
#warn '     LEVEL: ' . $lvl . "\n";

        # Sonderfall, wenn der Start des Teilstrings über das Ende hinaus geht ... keine Ahnung, warum ich das brauche
        $start < $end and
#warn "    PLAIN\n";
#warn '    SUBSTR: "' .substr($str, $start, $end - $start). "\"\n";
            $o .= _format_plain_text( substr($lstr, $start, $end - $start), $dis_p );

        # Wenn die gesuchten "HTML-Tags" matchen, werden diese hier umgesetzt
        if ( $m{htmlmatch} ) {
#warn "     HTML!\n";
            my $dis_block ||= defined($m{tag}) && exists($HTMLHandle{$m{tag}}) && $HTMLHandle{$m{tag}}[4];
#warn '    BLOCKS: ' . ($dis_block ? 'no blocks' : 'blocks allowed') . "\n";
#warn '       TAG: "' . ($m{tag}//'') . "\"\n";
#warn '     INNER: "' . ($m{inner}//'') . "\"\n";
            $o .= _make_tag( $c, $m{tag}, $m{inner} // '', $lvl, $dis_p, $dis_html, $set_n, $dis_block );
        }
        # Ansonsten kann es sich um einen URL-Link handeln, der wieder speziell behandelt wird
        elsif ( $m{urlmatch} ) {
#warn "      URL!\n;";
#warn '     LINK: "' .($m{url}//''). "\"\n";
            $o .= _make_link( $c, $m{url} );
        }
        # Oder wir haben es mit einem Smiley zu tun, welches ebenfalls gesondert formatiert wird
        elsif ( $m{smileymatch} ) {
#warn "   SMILEY!\n;";
#warn '     FACE: "' .($m{smileymatch}//''). "\"\n";
#warn '   NOSMIL: ' .($nosmil ? 'true' : 'false'). "\n";
            $o .= _make_smiley( $c, $m{smileymatch}, $nosmil );
        }
#warn "\n";
        # Die Verarbeitung geht nach dem Match-Ende weiter
        $start = $newstart;
    }

    # Solange wir uns noch im String befinden, wird der String plain formatiert angefügt
    $start < length( $str ) and
        $o .= _format_plain_text(substr($str, $start, length($str) - $start), $dis_p );

    return $o;
}

###############################################################################
# Plain-Text-Formatierung, bei dem lediglich der Text XML-Escaped und zeilenweise,
# falls nicht explizit abgeschalten, in p-Tags eingeschlossen wird
sub _format_plain_text {
    my ( $str, $dis_p ) = @_;
    my $nstr = xml_escape( $str );
    # Sind p-Tags nicht unerwünscht (!), kommen die bei Zeilenumbrüchen mit rein
    $dis_p or $nstr =~ s~\n+~</p>\n<p>~gsmxo;
    # Sollen um den String ebenfalls
    return $nstr;
}

###############################################################################
# Hier wird der Text tatsächlich einer schier meisterhaften Formatierung unterzogen
sub _pre_format_text {
    my ( $c, $str, $nosmil ) = @_;

    # Hier wird durch die Formatierung durch iteriert
    my $o = _pre_format_text_part($c, $str, (undef) x 4, $nosmil );
    # Leere Rückgabestrings fallen generell raus
    return '' if $o =~ m/\A\s*\z/xmso;
    
    # HTML-Absatz-Formatierungen hinzufügen
    $o = "<p>$o</p>";
    
    # HTML-Absatz-Formatierungen entfernen, wo sie nicht hin gehören
    $o =~ s~</(blockquote|pre|h3|ul|ol)>\s*</p>~</$1>~gismx;
    $o =~ s~<blockquote>\s*</p>~<blockquote>~gsmiox;
    $o =~ s~<p>\s*<(blockquote|pre|h3|ul|ol)>~<$1>~gsimx;
    $o =~ s~<p>\s*</blockquote>~</blockquote>~gsiomx;
    $o =~ s~(?<!\A)<hr\s+/>(?!\z)~</p>\n<hr />\n<p>~gsiomx;
    $o =~ s~<($HTMLStyleRe)>\s*</p>\s*<hr\s+/>\s*<p>\s*</\1>~<$1>&lt;hr /&gt;</$1>~gsmio;

    $o =~ s~<p>\s*(&lt;\w+&gt;\s*&lt;/\w+&gt;\s*)*</p>~~gsmo;
    # Leerzeichen und Zeilenumbrüche zurecht stutzen und überflüssiges entfernen
    $o =~ s~\n\n+~\n~gsmxo;
    $o =~ s~\A\s+~~smxo;
    $o =~ s~\s+\z~~smxo;

    return $o;
}

###############################################################################
# HTML-ähnliche Tags aus der Formatierung passend ersetzen
sub _make_tag {
    my ( $c, $tag, $inner, $lvl, $dis_p, $dis_html, $set_n, $dis_block ) = @_;

    # Sonderfall Leertags (wie z.B. <hr />)
    not $inner and $tag =~ $HTMLEmptyTagRe and return "<$tag />";
    # Sonderfall "Nüscht"
    $inner or return '';
        
    # Übergabewerte durch Defaults ersetzen, falls diese nicht vorhanden sind
    if ( exists $HTMLHandle{$tag} ) {
        $dis_p       ||= $HTMLHandle{$tag}[0];
        $dis_html    ||= $HTMLHandle{$tag}[1];
        $set_n       ||= $HTMLHandle{$tag}[2];
        $dis_block   ||= $HTMLHandle{$tag}[4];
    }

    # Formatierungen innerhalb des Tags
    my $in = _pre_format_text_part($c, $inner, $lvl, $dis_p, $dis_html, undef, undef, $dis_block );

    # Ausgabe bei Bedarf mit Leerzeilen
    return $set_n
        ? "\n<$tag>" . $in .  "</$tag>\n"
        :   "<$tag>" . $in .  "</$tag>";
}

###############################################################################
# Einen Link formatieren
sub _make_link {
    my ( $c, $url ) = @_;
    # Quotes URL-kompatibel machen
    $url =~ s/"/\%22/xmso;
    # XML-Escape für die HTML-Anzeige 
    my $url_xmlencode = xml_escape($url);
    return qq~<a href="$url" title="Externe Webseite: $url_xmlencode" target="_blank">~ 
        . _stripped_url($c, $url_xmlencode) . qq~</a>~;
}

###############################################################################
# Eine URL für die Anzeige im Text zusammenkürzen ... damit das nicht so ausufernd aussieht
sub _stripped_url {
    return '' unless $_[1]; # Nüx gibt nüx

    # Optional in der Mitte was raus schneiden, damit die URL-Anzeige im Text nicht zu lang wird
    my $u = $_[0]->configdata->{urlshorten};
    if ( $u and $u < ( my $l = length $_[1] ) ) {
        my $d = int( ( $l - $u ) / 2 );
        my $h = int(   $l        / 2 );
        return substr($_[1], 0, $h - $d) . '…' . substr($_[1], $h + $d);
    }

    # Wenn die URL kürzer ist, dann wird die natürlich komplett zurück geliefert
    return $_[1];
}

###############################################################################
# Smiley-Code (HTML-Bild) erzeugen
sub _make_smiley {
    $_[2] and return $_[1] // ''; # Wenn keine Smiley gewollt sind ...
    $_[1] or exists $Smiley{$_[1]} or return ''; # Oder wenn es nix gibt oder kein passendes Smiley zum übergebenen Textstück
    # HTML-Image-Tag zusammenbauen
    return qq~<img class="smiley" src="~
        . $_[0]->url_for("/theme/img/smileys/$Smiley{$_[1]}.png")
        . qq~" alt="$_[1]" title="$_[1]" />~;
}

###############################################################################
# Formatierung für die Zusammenfassungen in der Themenliste
sub _format_short {
    $_[1] or return ''; # Nüx gibt nüx

    # Normales Formatieren ohne Tag-Ersetzung und Smiley-Ersetzung
    my $str = _pre_format_text_part($_[0], substr($_[1],0,255), 1, 1, 1, 1);
    
    # Bestimmte Sachen rausschneiden, die wir in der Zusammenfassung nicht sehen wollen 
    # (bissel unschön, aber passt so)
    $str =~ s~</?["\s\w]+(?:>|\z)~~gxmso;
    $str =~ s~&lt;/?["\s\w]+(?:&gt;|\z)~~gxmso;
    
    # Überflüssigen Rest abschneiden und raus damit
    chomp $str; return $str;
}

1;
