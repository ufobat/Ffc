use strict;
use warnings;
use 5.010;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Mock::Controller;
srand;

use Test::More tests => 7;

use_ok('Ffc::Data::Formats');

{
    note('checking format_timestamp( $timestring )');
    my @timeok = ( int( rand 10000 ), map { int rand 100 } 0 .. 4 );
    my $timeok_teststring =
        sprintf '%04d-%02d-%02d'
      . ( ' ' x ( 3 + int rand 8 ) )
      . '%02d:%02d:%02d', @timeok;
    my $timeok_checkstring = sprintf '%d.%d.%d, %02d:%02d',
      @timeok[ 2, 1, 0, 3, 4 ];
    my $timebad = ">>> " . int( rand 1000000 ) . " <<<";
    is( Ffc::Data::Formats::format_timestamp($timebad),
        $timebad, 'bad time string just returned unaltered' );
    is( Ffc::Data::Formats::format_timestamp($timeok_teststring),
        $timeok_checkstring, 'good timestring returned like expected' );
}
{
    my @chars = ('a'..'z', 0..9, '_', '-', '.');
    my $zs = sub { join '', map({;$chars[int rand scalar @chars]} 0 .. 4 + int rand 8) };
    my $tu = sub { 'http://www.'.$zs->().'.de' };
    my $testurl = $tu->().'/'.$zs->().'.html';
    my $testimage = $tu->().'/'.$zs->().'.png';

    note('checking format_text');
    my $c = Mock::Controller->new();
    $c->session()->{theme} = my $theme = $zs->();
    $c->{url} = my $url = $tu->();
    note('checking format_text with images');
    $c->session()->{show_images} = 1;

    is( Ffc::Data::Formats::format_text(' ' x ( 3 + int rand 1000 ), $c), '', 'empty (lots of spaces) string returned empty - like in nothing');

    my $teststring = << "EOSTRING";
MarkupTests:

Notiz am Rande: !BBCodes! können mich mal kreuzweise am Arsch lecken, bin fertig mit den sinnlosen Drecksdingern. Die kommen hier nie, nie nie rein!

($testurl), $testimage

_test1_, +test2+, -test3-, ~test4~, !test5!

_test_1_, +test+2+, -test-3-, ~test~4~, !test!5!

smile: :) :-) =),
sad: :( :-( =(,
crying: :,(,
twinkling: ;) ;-),
laughting: :D =D :-D LOL,
rofl: XD X-D ROFL,
unsure: :| :-| =|,
yes: (y) (Y),
no: (n) (N),
down: -.-,
nope: :/ :-/ :\\ :-\\ =/ =\\,
sunny: B) B-) 8) 8-),
cats: ^^,
 love: <3,
devilsmile: >:) >:-) >=),
evilgrin: >:D >:-D >=D,
angry: >:( >:-( >=(
EOSTRING

    my $controlstring_withimages = << "EOSTRING";
<p>MarkupTests:</p>
<p>Notiz am Rande: <span class="alert">BBCodes !!!</span> können mich mal kreuzweise am Arsch lecken, bin fertig mit den sinnlosen Drecksdingern. Die kommen hier nie, nie nie rein!</p>
<p>(<a href="$testurl" title="Externe Webseite" target="_blank">$testurl</a>), <a href="$testimage" title="Externes Bild" target="_blank"><img src="$testimage" class="extern" title="Externes Bild" /></a></p>
<p><span class="underline">test1</span>, <span class="bold">test2</span>, <span class="linethrough">test3</span>, <span class="italic">test4</span>, <span class="alert">test5 !!!</span></p>
<p><span class="underline">test 1</span>, <span class="bold">test 2</span>, <span class="linethrough">test 3</span>, <span class="italic">test 4</span>, <span class="alert">test 5 !!!</span></p>
<p>smile: <img class="smiley" src="$url/themes//$theme/img/smileys/smile.png" alt=":)" /> <img class="smiley" src="$url/themes//$theme/img/smileys/smile.png" alt=":-)" /> <img class="smiley" src="$url/themes//$theme/img/smileys/smile.png" alt="=)" />,</p>
<p>sad: <img class="smiley" src="$url/themes//$theme/img/smileys/sad.png" alt=":(" /> <img class="smiley" src="$url/themes//$theme/img/smileys/sad.png" alt=":-(" /> <img class="smiley" src="$url/themes//$theme/img/smileys/sad.png" alt="=(" />,</p>
<p>crying: <img class="smiley" src="$url/themes//$theme/img/smileys/crying.png" alt=":,(" />,</p>
<p>twinkling: <img class="smiley" src="$url/themes//$theme/img/smileys/twinkling.png" alt=";)" /> <img class="smiley" src="$url/themes//$theme/img/smileys/twinkling.png" alt=";-)" />,</p>
<p>laughting: <img class="smiley" src="$url/themes//$theme/img/smileys/laughting.png" alt=":D" /> <img class="smiley" src="$url/themes//$theme/img/smileys/laughting.png" alt="=D" /> <img class="smiley" src="$url/themes//$theme/img/smileys/laughting.png" alt=":-D" /> <img class="smiley" src="$url/themes//$theme/img/smileys/laughting.png" alt="LOL" />,</p>
<p>rofl: <img class="smiley" src="$url/themes//$theme/img/smileys/rofl.png" alt="XD" /> <img class="smiley" src="$url/themes//$theme/img/smileys/rofl.png" alt="X-D" /> <img class="smiley" src="$url/themes//$theme/img/smileys/rofl.png" alt="ROFL" />,</p>
<p>unsure: <img class="smiley" src="$url/themes//$theme/img/smileys/unsure.png" alt=":|" /> <img class="smiley" src="$url/themes//$theme/img/smileys/unsure.png" alt=":-|" /> <img class="smiley" src="$url/themes//$theme/img/smileys/unsure.png" alt="=|" />,</p>
<p>yes: <img class="smiley" src="$url/themes//$theme/img/smileys/yes.png" alt="(y)" /> <img class="smiley" src="$url/themes//$theme/img/smileys/yes.png" alt="(Y)" />,</p>
<p>no: <img class="smiley" src="$url/themes//$theme/img/smileys/no.png" alt="(n)" /> <img class="smiley" src="$url/themes//$theme/img/smileys/no.png" alt="(N)" />,</p>
<p>down: <img class="smiley" src="$url/themes//$theme/img/smileys/down.png" alt="-.-" />,</p>
<p>nope: <img class="smiley" src="$url/themes//$theme/img/smileys/nope.png" alt=":/" /> <img class="smiley" src="$url/themes//$theme/img/smileys/nope.png" alt=":-/" /> <img class="smiley" src="$url/themes//$theme/img/smileys/nope.png" alt=":\\" /> <img class="smiley" src="$url/themes//$theme/img/smileys/nope.png" alt=":-\\" /> <img class="smiley" src="$url/themes//$theme/img/smileys/nope.png" alt="=/" /> <img class="smiley" src="$url/themes//$theme/img/smileys/nope.png" alt="=\\" />,</p>
<p>sunny: <img class="smiley" src="$url/themes//$theme/img/smileys/sunny.png" alt="B)" /> <img class="smiley" src="$url/themes//$theme/img/smileys/sunny.png" alt="B-)" /> <img class="smiley" src="$url/themes//$theme/img/smileys/sunny.png" alt="8)" /> <img class="smiley" src="$url/themes//$theme/img/smileys/sunny.png" alt="8-)" />,</p>
<p>cats: <img class="smiley" src="$url/themes//$theme/img/smileys/cats.png" alt="^^" />,</p>
<p>love: <img class="smiley" src="$url/themes//$theme/img/smileys/love.png" alt="&lt;3" />,</p>
<p>devilsmile: <img class="smiley" src="$url/themes//$theme/img/smileys/devilsmile.png" alt="&gt;:)" /> <img class="smiley" src="$url/themes//$theme/img/smileys/devilsmile.png" alt="&gt;:-)" /> <img class="smiley" src="$url/themes//$theme/img/smileys/devilsmile.png" alt="&gt;=)" />,</p>
<p>evilgrin: <img class="smiley" src="$url/themes//$theme/img/smileys/evilgrin.png" alt="&gt;:D" /> <img class="smiley" src="$url/themes//$theme/img/smileys/evilgrin.png" alt="&gt;:-D" /> <img class="smiley" src="$url/themes//$theme/img/smileys/evilgrin.png" alt="&gt;=D" />,</p>
<p>angry: <img class="smiley" src="$url/themes//$theme/img/smileys/angry.png" alt="&gt;:(" /> <img class="smiley" src="$url/themes//$theme/img/smileys/angry.png" alt="&gt;:-(" /> <img class="smiley" src="$url/themes//$theme/img/smileys/angry.png" alt="&gt;=(" /></p>
EOSTRING
    chomp $controlstring_withimages;
    my $out = Ffc::Data::Formats::format_text($teststring, $c);
    for my $f ( ['got.txt' => $out], ['expected.txt' => $controlstring_withimages] ) {
        open my $fh, '>', $f->[0] or die;
        print $fh $f->[1];
    }
    is(Ffc::Data::Formats::format_text($teststring, $c), $controlstring_withimages, 'teststring testet ok');

    note('checking format_text with images');
    $c->session()->{show_images} = 0;
    is( Ffc::Data::Formats::format_text(' ' x ( 3 + int rand 1000 ), $c), '', 'empty (lots of spaces) string returned empty - like in nothing');
    my $controlstring_withoutimages = << "EOSTRING";
<p>MarkupTests:</p>
<p>Notiz am Rande: <span class="alert">BBCodes !!!</span> können mich mal kreuzweise am Arsch lecken, bin fertig mit den sinnlosen Drecksdingern. Die kommen hier nie, nie nie rein!</p>
<p>(<a href="$testurl" title="Externe Webseite" target="_blank">$testurl</a>), <a href="$testimage" title="Externes Bild" target="_blank"><img class="icon" src="$url/themes/$theme/img/icons/img.png" class="extern" title="Externes Bild" /> $testimage</a></p>
<p><span class="underline">test1</span>, <span class="bold">test2</span>, <span class="linethrough">test3</span>, <span class="italic">test4</span>, <span class="alert">test5 !!!</span></p>
<p><span class="underline">test 1</span>, <span class="bold">test 2</span>, <span class="linethrough">test 3</span>, <span class="italic">test 4</span>, <span class="alert">test 5 !!!</span></p>
<p>smile::):-)=),</p>
<p>sad::(:-(=(,</p>
<p>crying::,(,</p>
<p>twinkling:;);-),</p>
<p>laughting::D=D:-DLOL,</p>
<p>rofl:XDX-DROFL,</p>
<p>unsure::|:-|=|,</p>
<p>yes:(y)(Y),</p>
<p>no:(n)(N),</p>
<p>down:-.-,</p>
<p>nope::/:-/:\\:-\\=/=\\,</p>
<p>sunny:B)B-)8)8-),</p>
<p>cats:^^,</p>
<p>love:<3,</p>
<p>devilsmile:>:)>:-)>=),</p>
<p>evilgrin:>:D>:-D>=D,</p>
<p>angry:>:(>:-(>=(</p>
EOSTRING
    chomp $controlstring_withoutimages;
    is( Ffc::Data::Formats::format_text($teststring, $c), $controlstring_withoutimages, 'teststring testet ok');
}

