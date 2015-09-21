use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use utf8;

use Test::Mojo;
use Test::More tests => 12;

###############################################################################
note q~Testsystem vorbereiten~;
###############################################################################
my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
Testinit::test_login($t, $admin, $apass);
$t->post_ok('/menu', json => {pageurl => '/bla/blubb', queryurl => '/blu/plum', controller => 'notes'})->status_is(200)
  ->content_is(<< 'EOMENU');
<div class="menu" id="menu">
    <div class="menuentry refreshlink">
        <a href="/bla/blubb"><span class="linkalike linkrefresh">aktualisieren</span></a>
    </div>

    <div class="menuentry">
        <a href="/forum"><span class="linktext linkforum">Themenliste</span></a>

    </div>
    <div class="menuentry">
        <a href="/notes"><span class="linktext linknotes active activenotes">Notizen</span></a>
    </div>
    <div class="menuentry">
        <form action="/blu/plum" accept-charset="UTF-8" method="POST">
            <span style="visibility: hidden">X</span>
            <input name="query" type="text" value="">
            <button type="submit">&raquo;Suche</button>
        </form>
    </div>
    <div class="otherspopuplink menuentry">
        <span class="othersmenulinktext">Men&uuml;</span>
        <div class="otherspopup popup">
            <p class="optionslink">
                <a href="/quick" target="_blank" title="Schnelle einfache &Uuml;bersicht &uuml;ber neue Beitr&auml;ge">Statusfenster</a>
            </p>
            <p class="optionslink">
                <a href="/options/form"><span class="linktext linkoptions">Einstellungen</span></a>
            </p>
            <p><a href="/help" target="_blank">Hilfe</a><span id="editbuttons" class="editbuttons nodisplay"></p>
            <p class="othersmenutext">Angemeldet als admin</p>
            <p class="logoutbutton2">
                <a href="/logout"><span class="linkalike linklogout">abmelden</span></a>
            </p>
        </div>
    </div>
</div>
EOMENU

