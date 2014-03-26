use strict;
use warnings;
use 5.010;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Test::Mojo;

use Test::More tests => 98;

srand;

{
    use Mojolicious::Lite;

    my $config = {};
    plugin 'Ffc::Plugin::Formats';
    helper configdata => sub { $config };
    helper prepare    => sub {
        my $c = shift;
        $c->session->{user} = $c->param('user') // '';
        $c->configdata->{urlshorten} = $c->param('urlshorten') // 30;
    };

    any '/format_timestamp' => sub {
        my $c = shift;
        $c->prepare;
        $c->render(text => $c->format_timestamp($c->param('text')));
    };
    any '/pre_format' => sub {
        my $c = shift;
        $c->prepare;
        $c->render(text => $c->pre_format($c->param('text')));
    };
    any '/post_format' => sub {
        my $c = shift;
        $c->prepare;
        $c->render(text => $c->post_format($c->param('text')));
    };
}

my $t = Test::Mojo->new;

{
    note('checking format_timestamp( $timestring )');
    my @timeok = ( int( rand 10000 ), map { int rand 100 } 0 .. 4 );
    $timeok[0]-- if $timeok[0] == ( localtime )[5] + 1900; # im zweifelsfall ein jahr zuvor
    my $timeok_teststring =
        sprintf '%04d-%02d-%02d'
      . ( ' ' x ( 3 + int rand 8 ) )
      . '%02d:%02d:%02d', @timeok;
    my $timeok_checkstring = sprintf '%02d.%02d.%04d, %02d:%02d',
      @timeok[ 2, 1, 0, 3, 4 ];
    my $timebad = ">>> " . int( rand 1000000 ) . " <<<";

    $t->post_ok('/format_timestamp', form => { text => '' })
      ->content_is('');
    $t->post_ok('/format_timestamp', form => { text => $timebad })
      ->content_is($timebad);
    $t->post_ok('/format_timestamp', form => { text => $timeok_teststring })
      ->content_is($timeok_checkstring);
    $t->post_ok('/format_timestamp', form => { text => '0000-00-00 00:00:00' })
      ->content_is('neu');
    {
        my @time = localtime; $time[5] += 1900; $time[4]++;
        my $stamp = sprintf '%04d-%02d-%02d %02d:%02d:%02d', @time[5,4,3,2,1,0];
        $t->post_ok('/format_timestamp', form => { text => $stamp })
          ->content_is('jetzt');
    }
    {
        my @time = localtime; $time[5] += 1900; $time[4]++;
        $time[1]++;
        my $stamp = sprintf '%04d-%02d-%02d %02d:%02d:%02d', @time[5,4,3,2,1,0];
        my $check = sprintf '%02d:%02d', @time[2,1];
        $t->post_ok('/format_timestamp', form => { text => $stamp })
          ->content_is($check);
    }
}

{
    note('checking pre_format');
    my @chars = ('a'..'z', 0..9, '.');
    my $zs = sub { join '', map({;$chars[int rand scalar @chars]} 0 .. 4 + int rand 8) };
    my $tu = sub { 'http://www.'.$zs->().'.de' };
    my @params;
    {
        @params = ( user => '', urlshorten => 10 + length $tu );
        $t->post_ok('/pre_format', form => { text => '', @params })
          ->content_is('');
        $t->post_ok('/pre_format', form => { text => '' x ( 3 + int rand 1000), @params })
          ->content_is('');
        @params = ( user => '', urlshorten => 10 + length $tu );
        $t->post_ok('/pre_format', form => { text => '', @params })
          ->content_is('');
        $t->post_ok('/pre_format', form => { text => '' x ( 3 + int rand 1000), @params })
          ->content_is('');
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
        my $testurl = $tu->().'/'.$zs->().'.html';
        my $testimage = $tu->().'/'.$zs->().'.png';
        my $testuser = $zs->();
        my @input = map { chomp; $_ ? $_ : () } split /\n+/, teststring($testurl, $testimage, $testuser);
        my @output_w_img = map { chomp; $_ ? $_ : () } split /\n+/, controlstring_withimages($testurl, $testimage, $testuser);
        for my $i ( 0..$#input ) {
            my $start = [ map {$zs->()} 0 .. int rand 3 ];
            my $stop = [ map {$zs->()} 0 .. int rand 3 ];
            my $input = $prep->($start, $input[$i], $stop, 0);
            my $output_w = $prep->($start, $output_w_img[$i], $stop, 1);
            {
                my @params = ( user => $testuser, urlshorten => 10 + length $testurl.$testimage );
                $t->post_ok('/pre_format', form => { text => $input, @params })
                  ->content_is($output_w);
            }
        }
    }
}

{
    note 'test multiline quotes';
    my $src = 'Und "Da kommt
ein mehrzeiliges

Zitat"! ... Haha!';

    my $expected = '<p>Und „<span class="quote">Da kommt</span></p>
<p><span class="quote">ein mehrzeiliges</span></p>
<p><span class="quote">Zitat</span>“! ... Haha!</p>';

    $t->post_ok('/pre_format', form => { text => $src })->content_is($expected);
}

{
    note 'test quotes and single "';
    my $teststring = q~
"Hallo Welt" blabla.
Mein 11" "Notebook" ist toll! oder nicht?
"a"
Mein "11" Notebook" ist tool! oder doch?
"Halli
Galli"
https://abcde.fghijklmn.opqrst.uvwx.yz/index.pl/?bla=blubb&x=ypsilon
~;

    my $controlstring = qq~<p>„<span class="quote">Hallo Welt</span>“ blabla.</p>
<p>Mein 11" „<span class="quote">Notebook</span>“ ist toll! oder nicht?</p>
<p>„<span class="quote">a</span>“</p>
<p>Mein „<span class="quote">11</span>“ Notebook" ist tool! oder doch?</p>
<p>„<span class="quote">Halli</span></p>
<p><span class="quote">Galli</span>“</p>
<p><a href="https://abcde.fghijklmn.opqrst.uvwx.yz/index.pl/?bla=blubb&amp;x=ypsilon" title="Externe Webseite: https://abcde.fghijklmn.opqrst.uvwx.yz/index.pl/?bla=blubb&amp;amp;x=ypsilon" target="_blank">https://abcde.f…p;amp;x=ypsilon</a></p>~;

    $t->post_ok('/pre_format', form => { text => $teststring, urlshorten => 30 })->content_is($controlstring);
}
{
    note 'test headings';
    my $teststring = q~
=Abc
Hall
= DEf
llo
=diad
~;
    my $controlstring = qq~<p><h2>Abc</h2></p>
<p>Hall</p>
<p><h2>DEf</h2></p>
<p>llo</p>
<p><h2>diad</h2></p>~;
    $t->post_ok('/pre_format', form => { text => $teststring, urlshorten => 30 })->content_is($controlstring);
}
{
    note 'test lists';
    my $teststring = q~
- Hallo
- Welt
Das ist eine Liste
-Haha
Das auch
# weil ich es kann
#du nicht?
# hui~;
    my $controlstring = qq~<ul>
<li>Hallo</li>
<li>Welt</li>
</ul>
<p>Das ist eine Liste</p>
<ul>
<li>Haha</li>
</ul>
<p>Das auch</p>
<ol>
<li>weil ich es kann</li>
<li>du nicht?</li>
<li>hui</li>
</ol>~;
    $t->post_ok('/pre_format', form => { text => $teststring, urlshorten => 30 })->content_is($controlstring);

    $teststring = q~- Hallo~;
    $controlstring = qq~<ul>
<li>Hallo</li>
</ul>~;
    $t->post_ok('/pre_format', form => { text => $teststring, urlshorten => 30 })->content_is($controlstring);

    $teststring = q~# Hallo~;
    $controlstring = qq~<ol>
<li>Hallo</li>
</ol>~;
    $t->post_ok('/pre_format', form => { text => $teststring, urlshorten => 30 })->content_is($controlstring);
}

{
    note 'test usernames';
    my @chars = ('a'..'z', 0..9, '.');
    my $zs = sub { join '', map({;$chars[int rand scalar @chars]} 0 .. 4 + int rand 8) };
    my $test = $zs->();
    my $testuser = $test.'<>&"';
    my $controluser = $test.'&lt;&gt;&amp;"';
    my $teststring = qq~
$testuser
Und "Hier, in dieser :) ... achso" und da" oder, so.

Achso \@$testuser: $testuser oder http://www.$testuser.de weil ja!
$testuser

Hallo

$testuser

<a href="http://www.$testuser.de">http://www.$testuser.de</a>~;
    my $controlstring = qq~
<span class="username">$controluser</span>
Und "Hier, in dieser :) ... achso" und da" oder, so.

Achso <span class="username"><span class="alert">@</span>$controluser</span>: <span class="username">$controluser</span> oder http://www.$test<>&".de weil ja!
<span class="username">$controluser</span>

Hallo

<span class="username">$controluser</span>

<a href="http://www.$testuser.de">http://www.$testuser.de</a>~;
    $t->post_ok('/post_format', form => { text => $teststring, user => $testuser, urlshorten => 999999 })
      ->content_is($controlstring);
}

sub teststring {
    my ( $testurl, $testimage, $testuser ) = @_;
    return << "EOSTRING";
MarkupTests:

Notiz am Rande: !BBCodes! können mich mal kreuzweise am Arsch lecken, bin fertig mit den sinnlosen Drecksdingern. Die kommen hier nie, nie nie rein!

$testurl $testurl $testurl

$testurl, $testurl

Hallo $testurl Hallo ($testurl) Hallo

($testurl), $testimage

Und "Hier, in dieser :) ... $testurl ... achso" und da" oder, $testuser, so.

Achso \@$testuser: $testuser oder http://www.$testuser.de weil ja!

_test1_, +test2+, -test3-, ~test4~, !test5!, *test6*
_test_1_, +test+2+, -test-3-, ~test~4~, !test!5!, *test*6*
look: O.O 0.0,
what: o.O O.o O.ò ó.O,
tongue: :P :-P =P :p :-p =p,
ooo: :O :-O =O :o :-o =o,
smile: :) :-) =),
sad: :( :-( =(,
crying: :,( :'(,
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
facepalm: m(
EOSTRING
}

sub controlstring_withimages {
    my ( $testurl, $testimage, $testuser ) = @_;
    return << "EOSTRING";
<p>MarkupTests:</p>
<p>Notiz am Rande: <span class="alert">BBCodes !!!</span> können mich mal kreuzweise am Arsch lecken, bin fertig mit den sinnlosen Drecksdingern. Die kommen hier nie, nie nie rein!</p>
<p><a href="$testurl" title="Externe Webseite: $testurl" target="_blank">$testurl</a> <a href="$testurl" title="Externe Webseite: $testurl" target="_blank">$testurl</a> <a href="$testurl" title="Externe Webseite: $testurl" target="_blank">$testurl</a></p>
<p><a href="$testurl" title="Externe Webseite: $testurl" target="_blank">$testurl</a>, <a href="$testurl" title="Externe Webseite: $testurl" target="_blank">$testurl</a></p>
<p>Hallo <a href="$testurl" title="Externe Webseite: $testurl" target="_blank">$testurl</a> Hallo (<a href="$testurl" title="Externe Webseite: $testurl" target="_blank">$testurl</a>) Hallo</p>
<p>(<a href="$testurl" title="Externe Webseite: $testurl" target="_blank">$testurl</a>), <a href="$testimage" title="Externes Bild" target="_blank"><img src="$testimage" class="extern" title="Externes Bild" /></a></p>
<p>Und „<span class="quote">Hier, in dieser <img class="smiley" src="/theme/img/smileys/smile.png" alt=":)" /> ... <a href="$testurl" title="Externe Webseite: $testurl" target="_blank">$testurl</a> ... achso</span>“ und da" oder, $testuser, so.</p>
<p>Achso \@$testuser: $testuser oder <a href="http://www.$testuser.de" title="Externe Webseite: http://www.$testuser.de" target="_blank">http://www.$testuser.de</a> weil ja!</p>
<p><span class="underline">test1</span>, <span class="bold">test2</span>, <span class="linethrough">test3</span>, <span class="italic">test4</span>, <span class="alert">test5 !!!</span>, <span class="emotion">test6</span></p>
<p><span class="underline">test 1</span>, <span class="bold">test 2</span>, <span class="linethrough">test 3</span>, <span class="italic">test 4</span>, <span class="alert">test 5 !!!</span>, <span class="emotion">test 6</span></p>
<p>look: <img class="smiley" src="/theme/img/smileys/look.png" alt="O.O" /> <img class="smiley" src="/theme/img/smileys/look.png" alt="0.0" />,</p>
<p>what: <img class="smiley" src="/theme/img/smileys/what.png" alt="o.O" /> <img class="smiley" src="/theme/img/smileys/what.png" alt="O.o" /> <img class="smiley" src="/theme/img/smileys/what.png" alt="O.ò" /> <img class="smiley" src="/theme/img/smileys/what.png" alt="ó.O" />,</p>
<p>tongue: <img class="smiley" src="/theme/img/smileys/tongue.png" alt=":P" /> <img class="smiley" src="/theme/img/smileys/tongue.png" alt=":-P" /> <img class="smiley" src="/theme/img/smileys/tongue.png" alt="=P" /> <img class="smiley" src="/theme/img/smileys/tongue.png" alt=":p" /> <img class="smiley" src="/theme/img/smileys/tongue.png" alt=":-p" /> <img class="smiley" src="/theme/img/smileys/tongue.png" alt="=p" />,</p>
<p>ooo: <img class="smiley" src="/theme/img/smileys/ooo.png" alt=":O" /> <img class="smiley" src="/theme/img/smileys/ooo.png" alt=":-O" /> <img class="smiley" src="/theme/img/smileys/ooo.png" alt="=O" /> <img class="smiley" src="/theme/img/smileys/ooo.png" alt=":o" /> <img class="smiley" src="/theme/img/smileys/ooo.png" alt=":-o" /> <img class="smiley" src="/theme/img/smileys/ooo.png" alt="=o" />,</p>
<p>smile: <img class="smiley" src="/theme/img/smileys/smile.png" alt=":)" /> <img class="smiley" src="/theme/img/smileys/smile.png" alt=":-)" /> <img class="smiley" src="/theme/img/smileys/smile.png" alt="=)" />,</p>
<p>sad: <img class="smiley" src="/theme/img/smileys/sad.png" alt=":(" /> <img class="smiley" src="/theme/img/smileys/sad.png" alt=":-(" /> <img class="smiley" src="/theme/img/smileys/sad.png" alt="=(" />,</p>
<p>crying: <img class="smiley" src="/theme/img/smileys/crying.png" alt=":,(" /> <img class="smiley" src="/theme/img/smileys/crying.png" alt=":'(" />,</p>
<p>twinkling: <img class="smiley" src="/theme/img/smileys/twinkling.png" alt=";)" /> <img class="smiley" src="/theme/img/smileys/twinkling.png" alt=";-)" />,</p>
<p>laughting: <img class="smiley" src="/theme/img/smileys/laughting.png" alt=":D" /> <img class="smiley" src="/theme/img/smileys/laughting.png" alt="=D" /> <img class="smiley" src="/theme/img/smileys/laughting.png" alt=":-D" /> <img class="smiley" src="/theme/img/smileys/laughting.png" alt="LOL" />,</p>
<p>rofl: <img class="smiley" src="/theme/img/smileys/rofl.png" alt="XD" /> <img class="smiley" src="/theme/img/smileys/rofl.png" alt="X-D" /> <img class="smiley" src="/theme/img/smileys/rofl.png" alt="ROFL" />,</p>
<p>unsure: <img class="smiley" src="/theme/img/smileys/unsure.png" alt=":|" /> <img class="smiley" src="/theme/img/smileys/unsure.png" alt=":-|" /> <img class="smiley" src="/theme/img/smileys/unsure.png" alt="=|" />,</p>
<p>yes: <img class="smiley" src="/theme/img/smileys/yes.png" alt="(y)" /> <img class="smiley" src="/theme/img/smileys/yes.png" alt="(Y)" />,</p>
<p>no: <img class="smiley" src="/theme/img/smileys/no.png" alt="(n)" /> <img class="smiley" src="/theme/img/smileys/no.png" alt="(N)" />,</p>
<p>down: <img class="smiley" src="/theme/img/smileys/down.png" alt="-.-" />,</p>
<p>nope: <img class="smiley" src="/theme/img/smileys/nope.png" alt=":/" /> <img class="smiley" src="/theme/img/smileys/nope.png" alt=":-/" /> <img class="smiley" src="/theme/img/smileys/nope.png" alt=":\\" /> <img class="smiley" src="/theme/img/smileys/nope.png" alt=":-\\" /> <img class="smiley" src="/theme/img/smileys/nope.png" alt="=/" /> <img class="smiley" src="/theme/img/smileys/nope.png" alt="=\\" />,</p>
<p>sunny: <img class="smiley" src="/theme/img/smileys/sunny.png" alt="B)" /> <img class="smiley" src="/theme/img/smileys/sunny.png" alt="B-)" /> <img class="smiley" src="/theme/img/smileys/sunny.png" alt="8)" /> <img class="smiley" src="/theme/img/smileys/sunny.png" alt="8-)" />,</p>
<p>cats: <img class="smiley" src="/theme/img/smileys/cats.png" alt="^^" />,</p>
<p>love: <img class="smiley" src="/theme/img/smileys/love.png" alt="&lt;3" />,</p>
<p>devilsmile: <img class="smiley" src="/theme/img/smileys/devilsmile.png" alt="&gt;:)" /> <img class="smiley" src="/theme/img/smileys/devilsmile.png" alt="&gt;:-)" /> <img class="smiley" src="/theme/img/smileys/devilsmile.png" alt="&gt;=)" />,</p>
<p>evilgrin: <img class="smiley" src="/theme/img/smileys/evilgrin.png" alt="&gt;:D" /> <img class="smiley" src="/theme/img/smileys/evilgrin.png" alt="&gt;:-D" /> <img class="smiley" src="/theme/img/smileys/evilgrin.png" alt="&gt;=D" />,</p>
<p>angry: <img class="smiley" src="/theme/img/smileys/angry.png" alt="&gt;:(" /> <img class="smiley" src="/theme/img/smileys/angry.png" alt="&gt;:-(" /> <img class="smiley" src="/theme/img/smileys/angry.png" alt="&gt;=(" /></p>
<p>facepalm: <img class="smiley" src="/theme/img/smileys/facepalm.png" alt="m(" /></p>
EOSTRING
}
