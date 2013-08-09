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

use Test::More tests => 2;

use_ok('Ffc::Data::Formats');

my $c = Mock::Controller->new();

{
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
<p>"Halli</p>
<p>Galli"</p>
<p><a href="https://abcde.fghijklmn.opqrst.uvwx.yz/index.pl/?bla=blubb&amp;x=ypsilon" title="Externe Webseite" target="_blank">https://abcde.f…p;amp;x=ypsilon</a></p>~;

    is(Ffc::Data::Formats::format_text($teststring, $c), $controlstring);
}

