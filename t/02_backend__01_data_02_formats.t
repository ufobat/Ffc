use strict;
use warnings;
use 5.010;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Mock::Controller;
use Test::Callcheck;
srand;

use Test::More tests => 62;

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
    is( Ffc::Data::Formats::format_timestamp(),
        '', 'no input returned empty string' );
    is( Ffc::Data::Formats::format_timestamp($timebad),
        $timebad, 'bad time string just returned unaltered' );
    is( Ffc::Data::Formats::format_timestamp($timeok_teststring),
        $timeok_checkstring, 'good timestring returned like expected' );
}
{
    note('checking format_text');
    my @chars = ('a'..'z', 0..9, '.');
    my $zs = sub { join '', map({;$chars[int rand scalar @chars]} 0 .. 4 + int rand 8) };
    my $tu = sub { 'http://www.'.$zs->().'.de' };
    my $c = Mock::Controller->new();
    {
        note('checking wrong calls');
        check_call( \&Ffc::Data::Formats::format_text,
            format_text =>
            {
                name => 'input string',
                good => '',
                bad => [],
                emptyerror => 'Controller ungültig',
                errormsg => [],
            },
            {
                name => 'controller object',
                good => $c,
                bad => [ '' ],
                emptyerror => 'Controller ungültig',
                errormsg => ['Controller ungültig'],
            },
        );
    }
    note('checking format_text without input');
    {
        $c->session()->{show_images} = 1;
        is( Ffc::Data::Formats::format_text('', $c), '', 'empty (nuthing) string returned empty - like in nothing');
        is( Ffc::Data::Formats::format_text('', $c), '', 'empty (nuthing) string returned empty - like in nothing');
        is( Ffc::Data::Formats::format_text(' ' x ( 3 + int rand 1000 ), $c), '', 'empty (lots of spaces) string returned empty - like in nothing');
        $c->session()->{show_images} = 0;
        is( Ffc::Data::Formats::format_text('', $c), '', 'empty (nuthing) string returned empty - like in nothing');
        is( Ffc::Data::Formats::format_text('', $c), '', 'empty (nuthing) string returned empty - like in nothing');
        is( Ffc::Data::Formats::format_text(' ' x ( 3 + int rand 1000 ), $c), '', 'empty (lots of spaces) string returned empty - like in nothing');
    }

    {
        note('checking calls with actual strings');
        my $prep = do {
            my $nop_ing = sub { join '', map { "$_\n" } @{ shift() } };
            my $p_ing = sub { join '', map { "<p>$_</p>\n" } @{ shift() } };
            sub {
                my ( $start, $str, $stop, $p ) = @_;
                my $s = $p
                    ? $p_ing->($start)."$str\n".$p_ing->($stop)
                    : $nop_ing->($start)."$str\n".$nop_ing->($stop);
                chomp $s;
                return $s;
            };
        };
        my $code = \&Ffc::Data::Formats::format_text;
        my $testurl = $tu->().'/'.$zs->().'.html';
        my $testimage = $tu->().'/'.$zs->().'.png';
        $c->session()->{theme} = my $theme = $zs->();
        $c->{url} = my $url = $tu->();
        my @input = map { chomp; $_ ? $_ : () } split /\n+/, teststring($testurl, $testimage);
        my @output_w_img = map { chomp; $_ ? $_ : () } split /\n+/, controlstring_withimages($testurl, $testimage, $url, $theme);
        my @output_wo_img = map { chomp; $_ ? $_ : () } split /\n+/, controlstring_withoutimages($testurl, $testimage, $url, $theme);
        #die ">".@input."<>".@output_w_img."<>".@output_wo_img."<";
        for my $i ( 0..$#input ) {
            my $start = [ map {$zs->()} 0 .. int rand 3 ];
            my $stop = [ map {$zs->()} 0 .. int rand 3 ];
            my $input = $prep->($start, $input[$i], $stop, 0);
            my $output_w = $prep->($start, $output_w_img[$i], $stop, 1);
            my $output_wo = $prep->($start, $output_wo_img[$i], $stop, 1);
            $c->session()->{show_images} = 1;
            is($code->($input, $c), $output_w, 'teststring testet ok with images');
            $c->session()->{show_images} = 0;
            is($code->($input, $c), $output_wo, 'teststring testet ok witout images');
        }
    }


}

sub teststring {
    my ( $testurl, $testimage ) = @_;
    return << "EOSTRING";
MarkupTests:

Notiz am Rande: !BBCodes! können mich mal kreuzweise am Arsch lecken, bin fertig mit den sinnlosen Drecksdingern. Die kommen hier nie, nie nie rein!

($testurl), $testimage
_test1_, +test2+, -test3-, ~test4~, !test5!
_test_1_, +test+2+, -test-3-, ~test~4~, !test!5!
tongue: :P :-P =P :p :-p =p,
ooo: :O :-O =O :o :-o =o,
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
}

sub controlstring_withimages {
    my ( $testurl, $testimage, $url, $theme ) = @_;
    return << "EOSTRING";
<p>MarkupTests:</p>
<p>Notiz am Rande: <span class="alert">BBCodes !!!</span> können mich mal kreuzweise am Arsch lecken, bin fertig mit den sinnlosen Drecksdingern. Die kommen hier nie, nie nie rein!</p>
<p>(<a href="$testurl" title="Externe Webseite" target="_blank">$testurl</a>), <a href="$testimage" title="Externes Bild" target="_blank"><img src="$testimage" class="extern" title="Externes Bild" /></a></p>
<p><span class="underline">test1</span>, <span class="bold">test2</span>, <span class="linethrough">test3</span>, <span class="italic">test4</span>, <span class="alert">test5 !!!</span></p>
<p><span class="underline">test 1</span>, <span class="bold">test 2</span>, <span class="linethrough">test 3</span>, <span class="italic">test 4</span>, <span class="alert">test 5 !!!</span></p>
<p>tongue: <img class="smiley" src="$url/themes//$theme/img/smileys/tongue.png" alt=":P" /> <img class="smiley" src="$url/themes//$theme/img/smileys/tongue.png" alt=":-P" /> <img class="smiley" src="$url/themes//$theme/img/smileys/tongue.png" alt="=P" /> <img class="smiley" src="$url/themes//$theme/img/smileys/tongue.png" alt=":p" /> <img class="smiley" src="$url/themes//$theme/img/smileys/tongue.png" alt=":-p" /> <img class="smiley" src="$url/themes//$theme/img/smileys/tongue.png" alt="=p" />,</p>
<p>ooo: <img class="smiley" src="$url/themes//$theme/img/smileys/ooo.png" alt=":O" /> <img class="smiley" src="$url/themes//$theme/img/smileys/ooo.png" alt=":-O" /> <img class="smiley" src="$url/themes//$theme/img/smileys/ooo.png" alt="=O" /> <img class="smiley" src="$url/themes//$theme/img/smileys/ooo.png" alt=":o" /> <img class="smiley" src="$url/themes//$theme/img/smileys/ooo.png" alt=":-o" /> <img class="smiley" src="$url/themes//$theme/img/smileys/ooo.png" alt="=o" />,</p>
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
}
sub controlstring_withoutimages {
    my ( $testurl, $testimage, $url, $theme ) = @_;
    return << "EOSTRING";
<p>MarkupTests:</p>
<p>Notiz am Rande: <span class="alert">BBCodes !!!</span> können mich mal kreuzweise am Arsch lecken, bin fertig mit den sinnlosen Drecksdingern. Die kommen hier nie, nie nie rein!</p>
<p>(<a href="$testurl" title="Externe Webseite" target="_blank">$testurl</a>), <a href="$testimage" title="Externes Bild" target="_blank"><img class="icon" src="$url/themes/$theme/img/icons/img.png" class="extern" title="Externes Bild" /> $testimage</a></p>
<p><span class="underline">test1</span>, <span class="bold">test2</span>, <span class="linethrough">test3</span>, <span class="italic">test4</span>, <span class="alert">test5 !!!</span></p>
<p><span class="underline">test 1</span>, <span class="bold">test 2</span>, <span class="linethrough">test 3</span>, <span class="italic">test 4</span>, <span class="alert">test 5 !!!</span></p>
<p>tongue::P:-P=P:p:-p=p,</p>
<p>ooo::O:-O=O:o:-o=o,</p>
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
}
