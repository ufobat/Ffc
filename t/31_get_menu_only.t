use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use utf8;

use Test::Mojo;
use Test::More tests => 164;

###############################################################################
note q~Testsystem vorbereiten~;
###############################################################################
my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1 );

Testinit::test_login($t, $user1, $pass1);
$t->post_ok('/topic/new', form => { titlestring => 'tzui', textdata    => 'hjkl' })->status_is(302)
->content_is('');
$t->post_ok("/topic/1/new", form => { textdata => 'asdf' })
  ->status_is(302)->content_is('')
  ->header_like(location => qr~/topic/1~);

Testinit::test_login($t, $admin, $apass);
$t->post_ok('/fetch', json => {pageurl => '/bla/blubb', queryurl => '/blu/plum', controller => 'notes', lastcount => 0})->status_is(200);
for my $str (
  << "EOMENU",
    <div class="activedim menuentry menulinkwleftpu">
        <a href="/forum" title="Liste aller Themen"><span class="linktext linkforum">Themen \\(<span class="mark">2</span>\\)</span></a>
    </div>
EOMENU
  << "EOMENU",
    <div class="menuentry activemenuentry">
        <a href="/notes"><span class="linktext linknotes active activenotes" title="Eigene Notizen">Notizen</span></a>
    </div>
EOMENU
  << "EOMENU",
    <div class="activedim menuentry menulinkwleftpu">
        <a href="/pmsgs" title="Liste aller aktiven Benutzer"><span class="linktext linkpmsgs">Benutzer</span></a>
    </div>
EOMENU
  << "EOMENU",
    <div class="popuparrow activedim menuentry">
        <span class="othersmenulinktext">\\*\\*\\*</span>
        <div class="userspopup popup otherspopup">
            <p class="smallnodisplay"><a href="/pmsgs/2">$user1</a></p>
        </div>
    </div>
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
for my $str (
  << "EOMENU",
            <p class="smallnodisplay"><a href="/pmsgs/1">admin</a></p>
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
    <div class="menuentry">
        <form action="/blu/plum" accept-charset="UTF-8" method="POST">
            <span style="display: none">X</span>
            <input name="query" type="text" value="">
            <button type="submit" title="Suchen">&gt;</button>
        </form>
    </div>
EOMENU
) {
    $t->json_unlike('/1' => qr~$str~);
}
$t->json_is('/0' => 2);
$t->json_is('/2' => []);

$t->post_ok("/topic/1/new", form => { textdata => 'qwer' })
  ->status_is(302)->content_is('')
  ->header_like(location => qr~/topic/1~);

my ( $user, $pass ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users($t, $admin, $apass, $user, $pass);
Testinit::test_login($t, $user, $pass);

$t->post_ok('/fetch', json => {pageurl => '/bla/blubb', queryurl => '/blu/plum', controller => 'notes'})->status_is(200);
for my $str (
  << "EOMENU",
    <div class="activedim menuentry menulinkwleftpu">
        <a href="/forum" title="Liste aller Themen"><span class="linktext linkforum">Themen \\(<span class="mark">3</span>\\)</span></a>
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
        </div>
    </div>
    <span class="menubarseparator">|</span>
</div>
EOMENU
    ) {
    $t->json_like('/1' => qr~$str~);
}
for my $str (
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
) {
    $t->json_unlike('/1' => qr~$str~);
}

Testinit::test_login($t, $admin, $apass);
my ( $user2, $pass2 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user2, $pass2 );

Testinit::test_logout($t);
Testinit::test_login($t, $user1, $pass1);

my $t2 = Test::Mojo->new('Ffc'); 
Testinit::test_login($t2, $user2, $pass2);

$t->post_ok('/fetch')->status_is(200);
$t->json_is('/0' => 1);
$t->json_is('/2' => []);
$t->get_ok('/chat')->status_is(200);
$t->get_ok('/chat/receive/started')->status_is(200);

$t2->post_ok('/fetch')->status_is(200);
$t2->json_is('/0' => 3);
$t2->json_is('/2/0/0' => $user1);
