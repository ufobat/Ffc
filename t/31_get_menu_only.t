use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use utf8;

use Test::Mojo;
use Test::More tests => 84;

###############################################################################
note q~Testsystem vorbereiten~;
###############################################################################
my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1 );
Testinit::test_login($t, $admin, $apass);
$t->post_ok('/menu', json => {pageurl => '/bla/blubb', queryurl => '/blu/plum', controller => 'notes'})->status_is(200);
for my $str (
  << "EOMENU",
<div class="menu" id="menu">
    <div class="menuentry refreshlink">
        <a href="/bla/blubb"><span class="linkalike linkrefresh">aktualisieren</span></a>
    </div>
EOMENU
  << "EOMENU",
    <div class="activedim menuentry">
        <span class="othersmenulinktext">Forum</span>
        <div class="topicpopup popup otherspopup">
            <p class="separated"><a href="/forum"><span class="linktext linkforum">Themen&uuml;bersicht</span></a></p>
        </div>
    </div>
EOMENU
  << "EOMENU",
    <div class="menuentry activemenuentry">
        <a href="/notes"><span class="linktext linknotes active activenotes">Notizen</span></a>
    </div>
EOMENU
  << "EOMENU",
    <div class="menuentry">
        <form action="/blu/plum" accept-charset="UTF-8" method="POST">
            <span style="visibility: hidden">X</span>
            <input name="query" type="text" value="">
            <button type="submit">&raquo;Suche</button>
        </form>
    </div>
EOMENU
  << "EOMENU",
    <div class="otherspopuplink activedim menuentry">
        <span class="othersmenulinktext">Einstellungen</span>
        <div class="otherspopup popup">
EOMENU
  << "EOMENU",
            <p class="optionslink separated">
                <a href="/quick" target="_blank" title="Schnelle einfache &Uuml;bersicht &uuml;ber neue Beitr&auml;ge">Statusfenster</a>
            </p>
EOMENU
  << "EOMENU",
            <p class="optionslink">
                <a href="/options/form"><span class="linktext linkoptions">Benutzerkonto</span></a>
            </p>
EOMENU
  << "EOMENU",
            <p class="optionslink separated">
                <a href="/admin/form"><span class="linktext linkoptions">Administration</span></a>
            </p>
EOMENU
  << "EOMENU",
            <p class="othersmenutext smallnodisplay">Angemeldet als admin</p>
EOMENU
  << "EOMENU",
            <p class="logoutbutton2">
                <a href="/logout"><span class="linkalike linklogout">abmelden</span></a>
            </p>
EOMENU
  << "EOMENU",
        </div>
    </div>
</div>
EOMENU
    ) {
    $t->content_like(qr~$str~);
}
for my $str (
  << "EOMENU",
    <div class="activedim menuentry">
        <span class="othersmenulinktext">Benutzer</span>
        <div class="userspopup popup">
            <p class="separated"><a href="/pmsgs"><span class="linktext linkpmsgs">Benutzerliste</span></a>
            <p><a href="/pmsgs/1">admin</a></p>
            <p><a href="/pmsgs/2">$user1</a></p>
        </div>
    </div>
EOMENU
    ) {
    $t->content_unlike(qr~$str~);
}

my ( $user, $pass ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users($t, $admin, $apass, $user, $pass);
Testinit::test_login($t, $user, $pass);

$t->post_ok('/menu', json => {pageurl => '/bla/blubb', queryurl => '/blu/plum', controller => 'notes'})->status_is(200);
    for my $str (
  << "EOMENU",
<div class="menu" id="menu">
    <div class="menuentry refreshlink">
        <a href="/bla/blubb"><span class="linkalike linkrefresh">aktualisieren</span></a>
    </div>
EOMENU
  << "EOMENU",
    <div class="activedim menuentry">
        <span class="othersmenulinktext">Forum</span>
        <div class="topicpopup popup otherspopup">
            <p class="separated"><a href="/forum"><span class="linktext linkforum">Themen&uuml;bersicht</span></a></p>
        </div>
    </div>
EOMENU
  << "EOMENU",
    <div class="activedim menuentry">
        <span class="othersmenulinktext">Benutzer</span>
        <div class="userspopup popup otherspopup">
            <p class="separated"><a href="/pmsgs"><span class="linktext linkpmsgs">Benutzerliste</span></a>
            <p class="smallnodisplay"><a href="/pmsgs/1">admin</a></p>
            <p class="smallnodisplay"><a href="/pmsgs/2">$user1</a></p>
        </div>
    </div>
EOMENU
  << "EOMENU",
    <div class="menuentry activemenuentry">
        <a href="/notes"><span class="linktext linknotes active activenotes">Notizen</span></a>
    </div>
EOMENU
  << "EOMENU",
    <div id="chatbutton" class="nodisplay">
        <a href="/chat" target="_blank"><span class="linktext linkchat">Chat</span></a>
    </div>
EOMENU
  << "EOMENU",
    <div class="menuentry">
        <form action="/blu/plum" accept-charset="UTF-8" method="POST">
            <span style="visibility: hidden">X</span>
            <input name="query" type="text" value="">
            <button type="submit">&raquo;Suche</button>
        </form>
    </div>
EOMENU
  << "EOMENU",
    <div class="otherspopuplink activedim menuentry">
        <span class="othersmenulinktext">Einstellungen</span>
        <div class="otherspopup popup">
EOMENU
  << "EOMENU",
            <p class="optionslink separated">
                <a href="/quick" target="_blank" title="Schnelle einfache &Uuml;bersicht &uuml;ber neue Beitr&auml;ge">Statusfenster</a>
            </p>
EOMENU
  << "EOMENU",
            <p class="optionslink separated">
                <a href="/options/form"><span class="linktext linkoptions">Benutzerkonto</span></a>
            </p>
EOMENU
  << "EOMENU",
            <p class="othersmenutext smallnodisplay">Angemeldet als $user</p>
EOMENU
  << "EOMENU",
            <p class="logoutbutton2">
                <a href="/logout"><span class="linkalike linklogout">abmelden</span></a>
            </p>
EOMENU
  << "EOMENU",
        </div>
    </div>
</div>
EOMENU
    ) {
    $t->content_like(qr~$str~);
}

