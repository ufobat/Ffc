use strict;
use warnings;
use 5.010;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Test::Mojo;

use Test::More tests => 32;

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
    any '/pre_format' => sub {
        my $c = shift;
        $c->prepare;
        $c->render(text => $c->pre_format($c->param('text')));
    };
    any '/username_format' => sub {
        my $c = shift;
        $c->prepare;
        $c->render(text => $c->username_format($c->param('text')));
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
    my $tests = shift;
    note q~Testing the formatting functions~;

    for my $test ( @$tests ) {
        my $res = _escape_str2re($test->[1]);
        $t->post_ok('/pre_format', form => {text => $test->[0]})
          ->status_is(200)
          ->content_like(qr~$res~);
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
    ],
    [
        << 'EOTXT',
devilsmile: >:) >:-) >=),
evilgrin: >:D >:-D >=D,
angry: >:( >:-( >=(
yeah: \o/ \O/ \0/
facepalm: m(
shock: :$ :-$ =$
ironie: </ironie> </irony>
attention: !!!
http://www.testurl.de/test/-test--test-test,1234,1234.html
EOTXT
        << 'EOHTML',
<p>devilsmile: <img class="smiley" src="/theme/img/smileys/devilsmile.png" alt=">:)" title=">:)" /> <img class="smiley" src="/theme/img/smileys/devilsmile.png" alt=">:-)" title=">:-)" /> <img class="smiley" src="/theme/img/smileys/devilsmile.png" alt=">=)" title=">=)" />,</p>
<p>evilgrin: <img class="smiley" src="/theme/img/smileys/evilgrin.png" alt=">:D" title=">:D" /> <img class="smiley" src="/theme/img/smileys/evilgrin.png" alt=">:-D" title=">:-D" /> <img class="smiley" src="/theme/img/smileys/evilgrin.png" alt=">=D" title=">=D" />,</p>
<p>angry: <img class="smiley" src="/theme/img/smileys/angry.png" alt=">:(" title=">:(" /> <img class="smiley" src="/theme/img/smileys/angry.png" alt=">:-(" title=">:-(" /> <img class="smiley" src="/theme/img/smileys/angry.png" alt=">=(" title=">=(" /></p>
<p>yeah: <img class="smiley" src="/theme/img/smileys/yeah.png" alt="\o/" title="\o/" /> <img class="smiley" src="/theme/img/smileys/yeah.png" alt="\O/" title="\O/" /> <img class="smiley" src="/theme/img/smileys/yeah.png" alt="\0/" title="\0/" /></p>
<p>facepalm: <img class="smiley" src="/theme/img/smileys/facepalm.png" alt="m(" title="m(" /></p>
<p>shock: <img class="smiley" src="/theme/img/smileys/shock.png" alt=":$" title=":$" /> <img class="smiley" src="/theme/img/smileys/shock.png" alt=":-$" title=":-$" /> <img class="smiley" src="/theme/img/smileys/shock.png" alt="=$" title="=$" /></p>
<p>ironie: <img class="smiley" src="/theme/img/smileys/ironie.png" alt="</ironie>" title="</ironie>" /> <img class="smiley" src="/theme/img/smileys/ironie.png" alt="</irony>" title="</irony>" /></p>
<p>attention: <img class="smiley" src="/theme/img/smileys/attention.png" alt="!!!" title="!!!" /></p>
<p><a href="http://www.testurl.de/test/-test--test-test,1234,1234.html" title="Externe Webseite: http://www.testurl.de/test/-test--test-test,1234,1234.html" target="_blank">http://www.test…,1234,1234.html</a></p>
EOHTML
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
</ul>
<p>&lt;li&gt;</p>
EOHTML
    ],
);

###############################################################################
###############################################################################
note q~run some tests~;
###############################################################################
###############################################################################

format_timestamp_test();
format_things_test(\@Tests);

