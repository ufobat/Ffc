use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 180;

###############################################################################
note q~Testsystem vorbereiten~;
###############################################################################
my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();

my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my ( $user2, $pass2 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1, $user2, $pass2 );
sub login1 { Testinit::test_login(   $t, $user1, $pass1 ) }
sub login2 { Testinit::test_login(   $t, $user2, $pass2 ) }

##################################################
note('Testdaten zusammenstellen');
my @Topics = ('asdf', 'fsa');        # Themenueberschriften
my @Articles0 = (qw(fdsa dfh wert)); # Beitrag zum ersten Thema
my @Articles1 = (qw(zuoio ghjk));    # Privatnachrichtentexte
my @Articles2 = (qw(zuoio));         # Beitrag zum zweiten Thema

###############################################################################
note q~Ausgangslage ohne Beitraege ansehen~;
###############################################################################

note('Anzeige ohne Beitraege pruefen');
login2();
$t->get_ok('/quick')->status_is(200)
  ->content_like(qr~<title>\(0\)\sFfc\sForum</title>~)
  ->content_like(qr~<p>Keine neuen Beiträge</p>~)
  ->content_like(qr~<p><a href="/">Forum öffnen</a></p>~)
  ->content_unlike(qr/<link/)->content_unlike(qr/<style/);

###############################################################################
note q~Vorbereiten der Testreihe~;
###############################################################################

note('Themen mit Beitraegen anlegen');
login1();
$t->post_ok('/topic/new', form => {titlestring => $Topics[0], textdata => $Articles0[0]})
  ->status_is(302)->header_like( Location => qr{\A/topic/1}xms );
$t->get_ok('/')->status_is(200)
  ->content_like(qr~<a href="/topic/1">$Topics[0]</a>~);
note('Ein neues Thema mit Beitrag wurde erstellt');
$t->post_ok('/topic/1/new', form => {textdata => $Articles0[1]})
  ->status_is(302)->header_like(Location => qr~/topic/1~);
$t->get_ok('/topic/1')->status_is(200)->content_like(qr~$Articles0[1]~);
note('Ein neuer Beitrag wurde erstellt');
$t->post_ok('/topic/1/new', form => {textdata => $Articles0[2]})
  ->status_is(302)->header_like(Location => qr~/topic/1~);
$t->get_ok('/topic/1')->status_is(200)->content_like(qr~$Articles0[2]~);
note('Ein neuer Beitrag wurde erstellt');
$t->post_ok('/topic/new', form => {titlestring => $Topics[1], textdata => $Articles2[0]})
  ->status_is(302)->header_like( Location => qr{\A/topic/2}xms );
$t->get_ok('/')->status_is(200)
  ->content_like(qr~<a href="/topic/2">$Topics[1]</a>~);
note('Ein neues Thema mit Beitrag wurde erstellt');

##################################################
note('Privatnachrichten anlegen');
login1();
$t->post_ok('/pmsgs/3/new', form => {textdata => $Articles1[0]})
  ->status_is(302)->header_like(Location => qr~/pmsgs/3~);
$t->get_ok('/pmsgs/3')->status_is(200)->content_like(qr~$Articles1[0]~);
note('Eine neue Privatnachricht wurde erstellt');
$t->post_ok('/pmsgs/3/new', form => {textdata => $Articles1[1]})
  ->status_is(302)->header_like(Location => qr~/pmsgs/3~);
$t->get_ok('/pmsgs/3')->status_is(200)->content_like(qr~$Articles1[1]~);
note('Eine neue Privatnachricht wurde erstellt');

###############################################################################
note q~Test der Quick-Seite mit neuen Beitraegen~;
###############################################################################

login2();
$t->get_ok('/quick')->status_is(200)
  ->content_like(qr~<title>\(6\)\sFfc\sForum</title>~)
  ->content_like(qr~<p><a href="/">Forum öffnen</a></p>~)
  ->content_like(qr~<p><a\shref="/pmsgs/2">$user1</a>\s\(2\)</p>~)
  ->content_like(qr~<p><a\shref="/topic/1">$Topics[0]</a>\s\(3\)</p>~)
  ->content_like(qr~<p><a\shref="/topic/2">$Topics[1]</a>\s\(1\)</p>~);

###############################################################################
note q~Einige Beitraege ansehen~;
###############################################################################

login2();
$t->get_ok('/topic/1')->status_is(200)
  ->content_like(qr~$Articles0[0]~)
  ->content_like(qr~$Articles0[1]~)
  ->content_like(qr~$Articles0[1]~);
$t->get_ok('/')->status_is(200)
  ->content_like(qr~<title>\(3\)\sFfc\sForum</title>~);

###############################################################################
note q~Test der Quick-Seite, wenn einige Beitraege angesehen wurden~;
###############################################################################

login2();
$t->get_ok('/quick')->status_is(200)
  ->content_like(qr~<title>\(3\)\sFfc\sForum</title>~)
  ->content_like(qr~<p><a href="/">Forum öffnen</a></p>~)
  ->content_like(qr~<p><a\shref="/pmsgs/2">$user1</a>\s\(2\)</p>~)
  ->content_like(qr~<p><a\shref="/topic/2">$Topics[1]</a>\s\(1\)</p>~)
  ->content_unlike(qr~<p><a\shref="/topic/1">$Topics[0]</a>~);

###############################################################################
note q~Alle Beitraege ansehen~;
###############################################################################

login2();
$t->get_ok('/topic/2')->status_is(200)
  ->content_like(qr~$Articles2[0]~);
$t->get_ok('/pmsgs/2')->status_is(200)
  ->content_like(qr~$Articles1[0]~)
  ->content_like(qr~$Articles1[1]~);
$t->get_ok('/')->status_is(200)
  ->content_like(qr~<title>\(0\)\sFfc\sForum</title>~);

###############################################################################
note q~Test der Quick-Seite, wenn alle Beitraege angesehen wurden~;
###############################################################################

login2();
$t->get_ok('/quick')->status_is(200)
  ->content_like(qr~<title>\(0\)\sFfc\sForum</title>~)
  ->content_like(qr~<p>Keine neuen Beiträge</p>~)
  ->content_like(qr~<p><a href="/">Forum öffnen</a></p>~)
  ->content_unlike(qr/<link/)->content_unlike(qr/<style/);

