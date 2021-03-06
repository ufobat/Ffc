use strict;
use warnings;
use 5.010;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Test::Mojo;

use Test::More tests => 113;

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
    any '/format_timestamp_oj' => sub {
        my $c = shift;
        $c->prepare;
        $c->render(text => $c->format_timestamp($c->param('text'), 1));
    };
    any '/format_short' => sub {
        my $c = shift;
        $c->prepare;
        $c->render(text => $c->format_short($c->param('text')));
    };
    any '/pre_format' => sub {
        my $c = shift;
        $c->prepare;
        $c->render(text => $c->pre_format($c->param('text')));
    };
    any '/pre_format_nosmiley' => sub {
        my $c = shift;
        $c->prepare;
        $c->render(text => $c->pre_format($c->param('text'), 1));
    };
    any '/pre_format_inlineimage' => sub {
        my $c = shift;
        $c->prepare;
        $c->render(text => $c->pre_format($c->param('text'), undef, 1));
    };
}

my $t = Test::Mojo->new;

sub format_timestamp_test {
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
        my @time = localtime;
        if ( $time[0] > 55 ) {
            sleep 6; # fix (workarround) testing bug with edge case on minute switch
            @time = localtime;
        }
        $time[5] += 1900; $time[4]++;
        my $stamp = sprintf '%04d-%02d-%02d %02d:%02d:%02d', @time[5,4,3,2,1,0];
        $t->post_ok('/format_timestamp', form => { text => $stamp })
          ->content_is('jetzt');
    }
    {
        my @time = localtime;
        if ( $time[0] > 55 ) {
            sleep 6; # fix (workarround) testing bug with edge case on minute switch
            @time = localtime;
        }
        $time[5] += 1900; $time[4]++;
        my $stamp = sprintf '%04d-%02d-%02d %02d:%02d:%02d', @time[5,4,3,2,1,0];
        my $check = sprintf '%02d:%02d', @time[2,1];
        $t->post_ok('/format_timestamp_oj', form => { text => $stamp })
          ->content_is($check);
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

sub _escape_str2re {
    my $str = shift;
    $str =~ s~(\\|\$|\%|\&|\(|\)|\?|\+|\*|\.|\[|\]|\{|\}|\^|\|)~\\$1~xgmso;
    chomp $str;
    return $str;
}

sub format_things_test {
    my $tests   = shift;
    my $nosmil  = shift;
    my $summary = shift;
    my $inlimg  = shift;
    note q~Testing the formatting functions~;

    for my $test ( @$tests ) {
        note qq~issuing test no. $test->[2]~;
        my $txt = $test->[0];
        chomp $txt;
        my $html = $test->[1];
        chomp $html;
        my $url = '/pre_format';
        $url = '/pre_format_nosmiley' if $nosmil;
        $url = '/pre_format_inlineimage' if $inlimg;
        $url = '/format_short' if $summary;
        $t->post_ok($url, form => {text => $test->[0]})
          ->status_is(200);
        $t->content_is($html);
    }
}

my @Tests = (
    [ 
        << 'EOTXT',
<u>test1</u>, <b>test2</b>, <strike>test3</strike>, <i>test4</i>, <em>test6</em>

<u>test_1</u>, <b>test-2</b>, <strike>test <3 3</strike>, <i>test :) 4</i>, <em>test 6</em>
EOTXT
        << 'EOHTML',
<p><u>test1</u>, <b>test2</b>, <strike>test3</strike>, <i>test4</i>, <em>test6</em></p>
<p><u>test_1</u>, <b>test-2</b>, <strike>test <img class="smiley" src="/theme/img/smileys/love.png" alt="<3" title="<3" /> 3</strike>, <i>test <img class="smiley" src="/theme/img/smileys/smile.png" alt=":)" title=":)" /> 4</i>, <em>test 6</em></p>
EOHTML
        1
    ],
    [
        << 'EOTXT',
<h3>Über geschifft</h3>
look: O.O 0.0 O_O 0_0,
what: o.O O.o O.ò ó.O,
tongue: :P :-P =P :p :-p =p,
ooo: :O :-O =O :o :-o =o,
smile: :) :-) =),
sad: :( :-( =(,
EOTXT
        << 'EOHTML',
<h3>Über geschifft</h3>
<p>look: <img class="smiley" src="/theme/img/smileys/look.png" alt="O.O" title="O.O" /> <img class="smiley" src="/theme/img/smileys/look.png" alt="0.0" title="0.0" /> <img class="smiley" src="/theme/img/smileys/look.png" alt="O_O" title="O_O" /> <img class="smiley" src="/theme/img/smileys/look.png" alt="0_0" title="0_0" />,</p>
<p>what: <img class="smiley" src="/theme/img/smileys/what.png" alt="o.O" title="o.O" /> <img class="smiley" src="/theme/img/smileys/what.png" alt="O.o" title="O.o" /> <img class="smiley" src="/theme/img/smileys/what.png" alt="O.ò" title="O.ò" /> <img class="smiley" src="/theme/img/smileys/what.png" alt="ó.O" title="ó.O" />,</p>
<p>tongue: <img class="smiley" src="/theme/img/smileys/tongue.png" alt=":P" title=":P" /> <img class="smiley" src="/theme/img/smileys/tongue.png" alt=":-P" title=":-P" /> <img class="smiley" src="/theme/img/smileys/tongue.png" alt="=P" title="=P" /> <img class="smiley" src="/theme/img/smileys/tongue.png" alt=":p" title=":p" /> <img class="smiley" src="/theme/img/smileys/tongue.png" alt=":-p" title=":-p" /> <img class="smiley" src="/theme/img/smileys/tongue.png" alt="=p" title="=p" />,</p>
<p>ooo: <img class="smiley" src="/theme/img/smileys/ooo.png" alt=":O" title=":O" /> <img class="smiley" src="/theme/img/smileys/ooo.png" alt=":-O" title=":-O" /> <img class="smiley" src="/theme/img/smileys/ooo.png" alt="=O" title="=O" /> <img class="smiley" src="/theme/img/smileys/ooo.png" alt=":o" title=":o" /> <img class="smiley" src="/theme/img/smileys/ooo.png" alt=":-o" title=":-o" /> <img class="smiley" src="/theme/img/smileys/ooo.png" alt="=o" title="=o" />,</p>
<p>smile: <img class="smiley" src="/theme/img/smileys/smile.png" alt=":)" title=":)" /> <img class="smiley" src="/theme/img/smileys/smile.png" alt=":-)" title=":-)" /> <img class="smiley" src="/theme/img/smileys/smile.png" alt="=)" title="=)" />,</p>
<p>sad: <img class="smiley" src="/theme/img/smileys/sad.png" alt=":(" title=":(" /> <img class="smiley" src="/theme/img/smileys/sad.png" alt=":-(" title=":-(" /> <img class="smiley" src="/theme/img/smileys/sad.png" alt="=(" title="=(" />,</p>
EOHTML
        2
    ],
    [
        << 'EOTXT',
<pre>
test
  test
   $test
</pre>
<ul>
<li>test1</li>
<li>test2</li>
</ul>
<ol>
<li>test3</li>
<li>test4</li>
</ol>
</pre>
EOTXT
        << 'EOHTML',
<pre>
test
  test
   $test
</pre>
<ul>
<li>test1</li>
<li>test2</li>
</ul>
<ol>
<li>test3</li>
<li>test4</li>
</ol>
<p>&lt;/pre&gt;</p>
EOHTML
        3
    ],
    [
        << 'EOTXT',
crying: :,( :'(,
twinkling: ;) ;-),
laughting: :D =D :-D LOL,
rofl: XD X-D ROFL,
unsure: :| :-| =|,
yes: (y) (Y),
no: (n) (N),
down: -.-,
nope: :/ :-/ :\ :-\ =/ =\,
sunny: B-) 8) 8-),
cats: ^^,
love: <3,
EOTXT
        << 'EOHTML',
<p>crying: <img class="smiley" src="/theme/img/smileys/crying.png" alt=":,(" title=":,(" /> <img class="smiley" src="/theme/img/smileys/crying.png" alt=":'(" title=":'(" />,</p>
<p>twinkling: <img class="smiley" src="/theme/img/smileys/twinkling.png" alt=";)" title=";)" /> <img class="smiley" src="/theme/img/smileys/twinkling.png" alt=";-)" title=";-)" />,</p>
<p>laughting: <img class="smiley" src="/theme/img/smileys/laughting.png" alt=":D" title=":D" /> <img class="smiley" src="/theme/img/smileys/laughting.png" alt="=D" title="=D" /> <img class="smiley" src="/theme/img/smileys/laughting.png" alt=":-D" title=":-D" /> <img class="smiley" src="/theme/img/smileys/laughting.png" alt="LOL" title="LOL" />,</p>
<p>rofl: <img class="smiley" src="/theme/img/smileys/rofl.png" alt="XD" title="XD" /> <img class="smiley" src="/theme/img/smileys/rofl.png" alt="X-D" title="X-D" /> <img class="smiley" src="/theme/img/smileys/rofl.png" alt="ROFL" title="ROFL" />,</p>
<p>unsure: <img class="smiley" src="/theme/img/smileys/unsure.png" alt=":|" title=":|" /> <img class="smiley" src="/theme/img/smileys/unsure.png" alt=":-|" title=":-|" /> <img class="smiley" src="/theme/img/smileys/unsure.png" alt="=|" title="=|" />,</p>
<p>yes: <img class="smiley" src="/theme/img/smileys/yes.png" alt="(y)" title="(y)" /> <img class="smiley" src="/theme/img/smileys/yes.png" alt="(Y)" title="(Y)" />,</p>
<p>no: <img class="smiley" src="/theme/img/smileys/no.png" alt="(n)" title="(n)" /> <img class="smiley" src="/theme/img/smileys/no.png" alt="(N)" title="(N)" />,</p>
<p>down: <img class="smiley" src="/theme/img/smileys/down.png" alt="-.-" title="-.-" />,</p>
<p>nope: <img class="smiley" src="/theme/img/smileys/nope.png" alt=":/" title=":/" /> <img class="smiley" src="/theme/img/smileys/nope.png" alt=":-/" title=":-/" /> <img class="smiley" src="/theme/img/smileys/nope.png" alt=":\" title=":\" /> <img class="smiley" src="/theme/img/smileys/nope.png" alt=":-\" title=":-\" /> <img class="smiley" src="/theme/img/smileys/nope.png" alt="=/" title="=/" /> <img class="smiley" src="/theme/img/smileys/nope.png" alt="=\" title="=\" />,</p>
<p>sunny: <img class="smiley" src="/theme/img/smileys/sunny.png" alt="B-)" title="B-)" /> <img class="smiley" src="/theme/img/smileys/sunny.png" alt="8)" title="8)" /> <img class="smiley" src="/theme/img/smileys/sunny.png" alt="8-)" title="8-)" />,</p>
<p>cats: <img class="smiley" src="/theme/img/smileys/cats.png" alt="^^" title="^^" />,</p>
<p>love: <img class="smiley" src="/theme/img/smileys/love.png" alt="<3" title="<3" />,</p>
EOHTML
        4
    ],
    [
        << 'EOTXT',
headbange: \m/,
devilsmile: >:) >:-) >=),
evilgrin: >:D >:-D >=D,
angry: >:( >:-( >=(
yeah: \o/ \O/ \0/
facepalm: m(
shock: :$ :-$ =$
ironie: </ironie> </irony>
sarcasm: </sarcasm>
attention: !!!
joke: !joke
http://www.testurl.de/test/-test--test-test,1234,1234.html
EOTXT
        << 'EOHTML',
<p>headbange: <img class="smiley" src="/theme/img/smileys/headbange.png" alt="\m/" title="\m/" />,</p>
<p>devilsmile: <img class="smiley" src="/theme/img/smileys/devilsmile.png" alt=">:)" title=">:)" /> <img class="smiley" src="/theme/img/smileys/devilsmile.png" alt=">:-)" title=">:-)" /> <img class="smiley" src="/theme/img/smileys/devilsmile.png" alt=">=)" title=">=)" />,</p>
<p>evilgrin: <img class="smiley" src="/theme/img/smileys/evilgrin.png" alt=">:D" title=">:D" /> <img class="smiley" src="/theme/img/smileys/evilgrin.png" alt=">:-D" title=">:-D" /> <img class="smiley" src="/theme/img/smileys/evilgrin.png" alt=">=D" title=">=D" />,</p>
<p>angry: <img class="smiley" src="/theme/img/smileys/angry.png" alt=">:(" title=">:(" /> <img class="smiley" src="/theme/img/smileys/angry.png" alt=">:-(" title=">:-(" /> <img class="smiley" src="/theme/img/smileys/angry.png" alt=">=(" title=">=(" /></p>
<p>yeah: <img class="smiley" src="/theme/img/smileys/yeah.png" alt="\o/" title="\o/" /> <img class="smiley" src="/theme/img/smileys/yeah.png" alt="\O/" title="\O/" /> <img class="smiley" src="/theme/img/smileys/yeah.png" alt="\0/" title="\0/" /></p>
<p>facepalm: <img class="smiley" src="/theme/img/smileys/facepalm.png" alt="m(" title="m(" /></p>
<p>shock: <img class="smiley" src="/theme/img/smileys/shock.png" alt=":$" title=":$" /> <img class="smiley" src="/theme/img/smileys/shock.png" alt=":-$" title=":-$" /> <img class="smiley" src="/theme/img/smileys/shock.png" alt="=$" title="=$" /></p>
<p>ironie: <img class="smiley" src="/theme/img/smileys/ironie.png" alt="</ironie>" title="</ironie>" /> <img class="smiley" src="/theme/img/smileys/ironie.png" alt="</irony>" title="</irony>" /></p>
<p>sarcasm: <img class="smiley" src="/theme/img/smileys/sarcasm.png" alt="</sarcasm>" title="</sarcasm>" /></p>
<p>attention: <img class="smiley" src="/theme/img/smileys/attention.png" alt="!!!" title="!!!" /></p>
<p>joke: <img class="smiley" src="/theme/img/smileys/joke.png" alt="!joke" title="!joke" /></p>
<p><a href="http://www.testurl.de/test/-test--test-test,1234,1234.html" title="Externe Webseite: http://www.testurl.de/test/-test--test-test,1234,1234.html" target="_blank">http://www.test…,1234,1234.html</a></p>
EOHTML
        5
    ],
    [
        << 'EOTXT',
<pre>
    <b>test</b>, test
    <pre>test</pre>
</pre>
<pre>
<ul>
    <li>asdf <3 <u>bla</u></li>
    <li>asdf asdf asdf
asdfasdf asdf</li>
</ul>
<li>
EOTXT
        << 'EOHTML',
<pre>
    &lt;b&gt;test&lt;/b&gt;, test
    &lt;pre&gt;test</pre>
<p>&lt;/pre&gt;</p>
<p>&lt;pre&gt;</p>
<ul>
    <li>asdf <img class="smiley" src="/theme/img/smileys/love.png" alt="<3" title="<3" /> <u>bla</u></li>
    <li>asdf asdf asdf
asdfasdf asdf</li>
</ul>
<p>&lt;li&gt;</p>
EOHTML
        6
    ],
    [
        '<u></u>',
        '',
        #'<p>&lt;u&gt;&lt;/u&gt;</p>',
        7
    ],
    [
        '<u></u><b></b>',
        '',
        #'<p>&lt;u&gt;&lt;/u&gt;&lt;b&gt;&lt;/b&gt;</p>',
        8
    ],
    [
        << 'EOTXT',
<u></u><b></b>
<h3></h3>
EOTXT
        '',
        #'<p>&lt;u&gt;&lt;/u&gt;&lt;b&gt;&lt;/b&gt;</p>
#<p>&lt;h3&gt;&lt;/h3&gt;</p>',
        9
    ],
    [
        << 'EOTXT',
Ist <q>Programm</q> mit drin? Dachte die kommen von den Herstellern selber oder sind dann eben in der Verwaltungssoftware mit drin (<q>System</q>).

Wenn man sie denn macht, ansonsten isses einem ja irgendwie eh wurscht, was das System da zieht. Wird schon wichtig sein werden ... wenn man sie denn macht.

<b>update:</b> jetzt muss ich doch nochmal eine naive Frage stellen, ich tue das aber im entsprechenden Thread (https://local.host/forum.pl/topic/1, Beitrag: https://local.host/forum.pl/topic/16/display/1)
EOTXT
        << 'EOHTML',
<p>Ist <q>Programm</q> mit drin? Dachte die kommen von den Herstellern selber oder sind dann eben in der Verwaltungssoftware mit drin (<q>System</q>).</p>
<p>Wenn man sie denn macht, ansonsten isses einem ja irgendwie eh wurscht, was das System da zieht. Wird schon wichtig sein werden ... wenn man sie denn macht.</p>
<p><b>update:</b> jetzt muss ich doch nochmal eine naive Frage stellen, ich tue das aber im entsprechenden Thread (<a href="https://local.host/forum.pl/topic/1" title="Externe Webseite: https://local.host/forum.pl/topic/1" target="_blank">https://local.h…forum.pl/topic/1</a>, Beitrag: <a href="https://local.host/forum.pl/topic/16/display/1" title="Externe Webseite: https://local.host/forum.pl/topic/16/display/1" target="_blank">https://local.h…ic/16/display/1</a>)</p>
EOHTML
        10
    ],
    [
        << 'EOTXT',
blupp blupp
<blockquote>
Bla Bla
Fasel Fasel
</blockquote>

fapp blapp
EOTXT
        << 'EOHTML',
<p>blupp blupp</p>
<blockquote>
<p>Bla Bla</p>
<p>Fasel Fasel</p>
</blockquote>
<p>fapp blapp</p>
EOHTML
        11
    ],
    [
        << 'EOTXT',
blupp blupp
<pre>
Bla Bla
Fasel Fasel
</pre>

fapp blapp
EOTXT
        << 'EOHTML',
<p>blupp blupp</p>
<pre>
Bla Bla
Fasel Fasel
</pre>
<p>fapp blapp</p>
EOHTML
        12
    ],
    [
        << 'EOTXT',
<ol>
    <li>asdf <3 asdfasd</li>
    <li>fsdfa :D <i>x</i></li>
    <li>fsdfa :D dfasdf</li>
    <li>fsdfa <i>dfasdf</i></li>
</ol>
EOTXT
        << 'EOHTML',
<ol>
    <li>asdf <img class="smiley" src="/theme/img/smileys/love.png" alt="<3" title="<3" /> asdfasd</li>
    <li>fsdfa <img class="smiley" src="/theme/img/smileys/laughting.png" alt=":D" title=":D" /> <i>x</i></li>
    <li>fsdfa <img class="smiley" src="/theme/img/smileys/laughting.png" alt=":D" title=":D" /> dfasdf</li>
    <li>fsdfa <i>dfasdf</i></li>
</ol>
EOHTML
        13
    ],
    [
        << 'EOTXT',
asdf asdf <u>asdfasfd</u>
EOTXT
        << 'EOHTML',
<p>asdf asdf <u>asdfasfd</u></p>
EOHTML
        14
    ],
    [
        << 'EOTXT',
asdf asdf http://test.org/bla/blubb asdfas.
blubblbub (https://test2.org/bla.html) fdf das.
blubblbub [https://test2.org/bla.html] fdf das.
bloblo fd (http://test3.com/bli.pl, hat sich erledigt).
daddel didi <b>http://test5.co.uk/balla.cgi baddabing</b> und da.
dummdi dummi <u>didumm https://test4.de/bong.lua</u> oder so.
EOTXT
        << 'EOHTML',
<p>asdf asdf <a href="http://test.org/bla/blubb" title="Externe Webseite: http://test.org/bla/blubb" target="_blank">http://test.org/bla/blubb</a> asdfas.</p>
<p>blubblbub (<a href="https://test2.org/bla.html" title="Externe Webseite: https://test2.org/bla.html" target="_blank">https://test2.org/bla.html</a>) fdf das.</p>
<p>blubblbub [<a href="https://test2.org/bla.html" title="Externe Webseite: https://test2.org/bla.html" target="_blank">https://test2.org/bla.html</a>] fdf das.</p>
<p>bloblo fd (<a href="http://test3.com/bli.pl" title="Externe Webseite: http://test3.com/bli.pl" target="_blank">http://test3.com/bli.pl</a>, hat sich erledigt).</p>
<p>daddel didi <b><a href="http://test5.co.uk/balla.cgi" title="Externe Webseite: http://test5.co.uk/balla.cgi" target="_blank">http://test5.co.uk/balla.cgi</a> baddabing</b> und da.</p>
<p>dummdi dummi <u>didumm <a href="https://test4.de/bong.lua" title="Externe Webseite: https://test4.de/bong.lua" target="_blank">https://test4.de/bong.lua</a></u> oder so.</p>
EOHTML
        15
    ],
    [
        << 'EOTXT',
Blaaa blubb (http://www.test.de/?test=bla,blubb, https://www.test.org/?toast=bli,) und http://wupp.pl/hlu.,&roh so https://www.test.com/?tast=blo,
EOTXT
        << 'EOHTML',
<p>Blaaa blubb (<a href="http://www.test.de/?test=bla,blubb" title="Externe Webseite: http://www.test.de/?test=bla,blubb" target="_blank">http://www.test…?test=bla,blubb</a>, <a href="https://www.test.org/?toast=bli" title="Externe Webseite: https://www.test.org/?toast=bli" target="_blank">https://www.tes…t.org/?toast=bli</a>,) und <a href="http://wupp.pl/hlu.,&roh" title="Externe Webseite: http://wupp.pl/hlu.,&amp;roh" target="_blank">http://wupp.pl/hlu.,&amp;roh</a> so <a href="https://www.test.com/?tast=blo" title="Externe Webseite: https://www.test.com/?tast=blo" target="_blank">https://www.test.com/?tast=blo</a>,</p>
EOHTML
        16
    ],
    [
        << 'EOTXT',
<hr />
<u>Bla</u>
<b><hr /></b>
<b>asdf <hr />fasd</b>
asdf<hr />asdfas
<hr />
<hr //>
<hr>
<hr />
EOTXT
        << 'EOHTML',
<hr />
<p><u>Bla</u></p>
<p><b>&lt;hr /&gt;</b></p>
<p><b>asdf &lt;hr /&gt;fasd</b></p>
<p>asdf&lt;hr /&gt;asdfas</p>
<hr />
<p>&lt;hr //&gt;</p>
<p>&lt;hr&gt;</p>
<hr />
EOHTML
        17
    ],
    [
        << 'EOTXT',
asdfasdf
asdf<b>zert
fasd</b>hfgjhfg
gsdfggsdfg
EOTXT
        << 'EOHTML',
<p>asdfasdf</p>
<p>asdf&lt;b&gt;zert</p>
<p>fasd&lt;/b&gt;hfgjhfg</p>
<p>gsdfggsdfg</p>
EOHTML
        18
    ],
    [
        '',
        '',
        19
    ],
    [
        '<u></u>',
        '',
        20
    ],
    [
        join( ' … ', 
            'o_O', 'O_o', 'O_ò', 'ó_O', 'Oo', 'oO' ),
        '<p>' . join( ' … ', map {
            qq~<img class="smiley" src="/theme/img/smileys/what.png" alt="$_" title="$_" />~
            } 'o_O', 'O_o', 'O_ò', 'ó_O', 'Oo', 'oO' ) . '</p>',
        21
    ],
    [
        << 'EOCODE',
Obächt >

Halla

<pre>
Test, Töst, <Täst>:

Blups

Bla
</pre>

TamTam
EOCODE
        << 'EOCODE',
<p>Obächt &gt;</p>
<p>Halla</p>
<pre>
Test, Töst, &lt;Täst&gt;:

Blups

Bla
</pre>
<p>TamTam</p>
EOCODE
        22
    ],
);

my @Tests_NoSmil = (
    [
        << 'EOTXT',
asdf asdf <u>asdfasfd</u>
EOTXT
        << 'EOHTML',
<p>asdf asdf <u>asdfasfd</u></p>
EOHTML
        1
    ],
    [
        << 'EOTXT',
asdf :D asdf <u>asdfasfd</u>
EOTXT
        << 'EOHTML',
<p>asdf :D asdf <u>asdfasfd</u></p>
EOHTML
        2
    ],
);

my @Tests_Short = (
    [
        << 'EOTXT',
asdfasdfasdf
EOTXT
        << 'EOHTML',
asdfasdfasdf
EOHTML
        1
    ],
    [
        << 'EOTXT',
as<b>df</b>asdfasdf
EOTXT
        << 'EOHTML',
asdfasdfasdf
EOHTML
        2
    ],
    [
        << 'EOTXT',
as<b>dfasdfasdf
EOTXT
        << 'EOHTML',
asdfasdfasdf
EOHTML
        3
    ],
    [
        << 'EOTXT',
as</b>dfasdfasdf
EOTXT
        << 'EOHTML',
asdfasdfasdf
EOHTML
        4
    ],
    [
        << 'EOTXT',
asdfasdfasdf<b>
EOTXT
        << 'EOHTML',
asdfasdfasdf
EOHTML
        5
    ],
    [
        ('a' x 240) . '</a',
        ('a' x 240),
        6
    ],
    [
        ('b' x 240) . '<b',
        ('b' x 240),
        7
    ],
);
my @Tests_Inlimg = (
    [
        << 'EOTXT',
asdf http://test.de asdf asdf
https://bla.org
asdfasdf
EOTXT
        << 'EOHTML',
<p>asdf <a href="http://test.de" title="Externe Webseite: http://test.de" target="_blank">http://test.de</a> asdf asdf</p>
<p><a href="https://bla.org" title="Externe Webseite: https://bla.org" target="_blank">https://bla.org</a></p>
<p>asdfasdf</p>
EOHTML
        1
    ],
    [
        << 'EOTXT',
asdf http://blubbdi.de/test.png afsdf
EOTXT
        << 'EOTXT',
<p>asdf <a href="http://blubbdi.de/test.png" title="Externe Webseite: http://blubbdi.de/test.png" target="_blank"><img src="http://blubbdi.de/test.png" title="http://blubbdi.de/test.png" /></a> afsdf</p>
EOTXT
        2
    ],
);

###############################################################################
###############################################################################
note q~run some tests~;
###############################################################################
###############################################################################

format_timestamp_test();
#format_things_test([$Tests[21]]);
format_things_test(\@Tests);
format_things_test(\@Tests_NoSmil, 1, 0, 0);
format_things_test(\@Tests_Short,  0, 1, 0);
format_things_test(\@Tests_Inlimg, 0, 0, 1)

