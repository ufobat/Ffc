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
$t->post_ok('/fetch', json => {pageurl => '/bla/blubb', queryurl => '/blu/plum', controller => 'notes'})->status_is(200);
for my $str (
  << "EOMENU",
    <div class="activedim menuentry menulinkwleftpu">
        <a href="/forum" title="Liste aller Themen"><span class="linktext linkforum">Themen</span></a>
    </div>
EOMENU
  << "EOMENU",
    <div class="menuentry activemenuentry">
        <a href="/notes"><span class="linktext linknotes active activenotes" title="Eigene Notizen">Notizen</span></a>
    </div>
EOMENU
  << "EOMENU",
    <div class="menuentry">
        <form action="/blu/plum" accept-charset="UTF-8" method="POST">
            <span style="display: none">X</span>
            <input name="query" type="text" value="">
            <button type="submit" title="Suchen">&gt;</button>
        </form>
    </div>
EOMENU
  << "EOMENU",
    <div class="otherspopuplink activedim menuentry">
        <span class="othersmenulinktext">Konto</span>
        <div class="otherspopup popup optionspopup">
EOMENU
  << "EOMENU",
            <p class="optionslink">
                <a href="/options/form"><span class="linktext linkoptions">Einstellungen</span></a>
            </p>
EOMENU
  << "EOMENU",
            <p class="optionslink">
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
    <span class="menubarseparator">|</span>
</div>
EOMENU
  << "EOMENU",
    <div class="activedim menuentry menulinkwleftpu">
        <a href="/pmsgs" title="Liste aller aktiven Benutzer"><span class="linktext linkpmsgs">Benutzer</span></a>
    </div>
EOMENU
    ) {
    $t->json_like('/1' => qr~$str~);
}
for my $str (
  << "EOMENU",
    <div class="popuparrow activedim menuentry">
        <span class="othersmenulinktext">\\*\\*\\*</span>
        <div class="userspopup popup otherspopup">
            <p class="smallnodisplay"><a href="/pmsgs/1">admin</a></p>
            <p class="smallnodisplay"><a href="/pmsgs/2">$user1</a></p>
        </div>
    </div>
EOMENU
    ) {
    $t->json_unlike('/1' => qr~$str~);
}
$t->json_is('/0' => 0);
$t->json_like('/2' => qr~<div id="chatbutton" class="nodisplay">~);

my ( $user, $pass ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users($t, $admin, $apass, $user, $pass);
Testinit::test_login($t, $user, $pass);

$t->post_ok('/fetch', json => {pageurl => '/bla/blubb', queryurl => '/blu/plum', controller => 'notes'})->status_is(200);
    for my $str (
  << "EOMENU",
    <div class="activedim menuentry menulinkwleftpu">
        <a href="/forum" title="Liste aller Themen"><span class="linktext linkforum">Themen</span></a>
    </div>
EOMENU
  << "EOMENU",
    <div class="popuparrow activedim menuentry">
        <span class="othersmenulinktext">\\*\\*\\*</span>
        <div class="userspopup popup otherspopup">
            <p class="smallnodisplay"><a href="/pmsgs/1">admin</a></p>
            <p class="smallnodisplay"><a href="/pmsgs/2">$user1</a></p>
        </div>
    </div>
EOMENU
  << "EOMENU",
    <div class="activedim menuentry menulinkwleftpu">
        <a href="/pmsgs" title="Liste aller aktiven Benutzer"><span class="linktext linkpmsgs">Benutzer</span></a>
    </div>
EOMENU
  << "EOMENU",
    <div class="menuentry activemenuentry">
        <a href="/notes"><span class="linktext linknotes active activenotes" title="Eigene Notizen">Notizen</span></a>
    </div>
EOMENU
  << "EOMENU",
    <div class="menuentry">
        <form action="/blu/plum" accept-charset="UTF-8" method="POST">
            <span style="display: none">X</span>
            <input name="query" type="text" value="">
            <button type="submit" title="Suchen">&gt;</button>
        </form>
    </div>
EOMENU
  << "EOMENU",
        <span class="othersmenulinktext">Konto</span>
        <div class="otherspopup popup optionspopup">
            <p class="optionslink">
                <a href="/options/form"><span class="linktext linkoptions">Einstellungen</span></a>
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
    <span class="menubarseparator">|</span>
</div>
EOMENU
    ) {
    $t->json_like('/1' => qr~$str~);
}
$t->json_is('/0' => 0);
$t->json_like('/2' => qr~<div id="chatbutton" class="nodisplay">~);

