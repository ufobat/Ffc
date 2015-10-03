use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use utf8;

use Test::Mojo;
use Test::More tests => 43;

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
        <span class="othersmenulinktext">Einstellungen</span>
        <div class="otherspopup popup">
            <p class="optionslink">
                <a href="/quick" target="_blank" title="Schnelle einfache &Uuml;bersicht &uuml;ber neue Beitr&auml;ge">Statusfenster</a>
            </p>
            <p class="optionslink">
                <a href="/options/form"><span class="linktext linkoptions">Benutzerkonto</span></a>
            </p>
            <p class="optionslink">
                <a href="/options/admin/form"><span class="linktext linkoptions">Administration</span></a>
            </p>
            <p><a href="/help" target="_blank">Hilfe</a></p>
            <p class="othersmenutext">Angemeldet als admin</p>
            <p class="logoutbutton2">
                <a href="/logout"><span class="linkalike linklogout">abmelden</span></a>
            </p>
        </div>
    </div>
</div>
EOMENU

my ( $user, $pass ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users($t, $admin, $apass, $user, $pass);
Testinit::test_login($t, $user, $pass);

$t->post_ok('/menu', json => {pageurl => '/bla/blubb', queryurl => '/blu/plum', controller => 'notes'})->status_is(200)
  ->content_is(<< "EOMENU");
<div class="menu" id="menu">
    <div class="menuentry refreshlink">
        <a href="/bla/blubb"><span class="linkalike linkrefresh">aktualisieren</span></a>
    </div>

    <div class="menuentry">
        <a href="/forum"><span class="linktext linkforum">Forum</span></a>

    </div>
    <div class="menuentry">
        <a href="/pmsgs"><span class="linktext linkpmsgs">Benutzer</span></a>
        <div class="userspopup popup">
            <p><a href="/pmsgs/1">admin</a></p>
        </div>

    </div>
    <div class="menuentry">
        <a href="/notes"><span class="linktext linknotes active activenotes">Notizen</span></a>
    </div>
    <div id="chatbutton" class="nodisplay">
        <a href="/chat" target="_blank"><span class="linktext linkchat">Chat</span></a>
    </div>
    <div class="menuentry">
        <form action="/blu/plum" accept-charset="UTF-8" method="POST">
            <span style="visibility: hidden">X</span>
            <input name="query" type="text" value="">
            <button type="submit">&raquo;Suche</button>
        </form>
    </div>
    <div class="otherspopuplink menuentry">
        <span class="othersmenulinktext">Einstellungen</span>
        <div class="otherspopup popup">
            <p class="optionslink">
                <a href="/quick" target="_blank" title="Schnelle einfache &Uuml;bersicht &uuml;ber neue Beitr&auml;ge">Statusfenster</a>
            </p>
            <p class="optionslink">
                <a href="/options/form"><span class="linktext linkoptions">Benutzerkonto</span></a>
            </p>
            <p><a href="/help" target="_blank">Hilfe</a></p>
            <p class="othersmenutext">Angemeldet als $user</p>
            <p class="logoutbutton2">
                <a href="/logout"><span class="linkalike linklogout">abmelden</span></a>
            </p>
        </div>
    </div>
</div>
EOMENU

