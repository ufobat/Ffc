use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use utf8;

use Carp;
use Data::Dumper;
use Test::Mojo;
use Test::More tests => 170;

#################################################
# Vorbereitungstreffen
#################################################

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user1, $pass1, $user2, $pass2, $user3, $pass3 ) = ( map {; Testinit::test_randstring() } 1 .. 6 );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1, $user2, $pass2, $user3, $pass3 );
sub login1 { Testinit::test_login( $t, $user1, $pass1 ) } # erstellt
sub login2 { Testinit::test_login( $t, $user2, $pass2 ) } # flaggt
sub login3 { Testinit::test_login( $t, $user3, $pass3 ) } # schaut alles an
sub info { Testinit::test_info(    $t, @_ ) }

sub check_new {
    my ( $tid, $cnt ) = @_;
    $t->content_like(
        qr~<a title="Testtopic $tid" href="/topic/$tid">Testtopic $tid</a>\.\.\. \(<span class="mark">$cnt</span>\)</p>~);
    $t->content_unlike(
        qr~<a title="Testtopic $tid" href="/topic/$tid">Testtopic $tid</a>\.\.\.</p>~);
}

sub check_old {
    my ( $tid ) = @_;
    $t->content_like(
        qr~<a title="Testtopic $tid" href="/topic/$tid">Testtopic $tid</a>\.\.\.</p>~);
    $t->content_unlike(
        qr~<a title="Testtopic $tid" href="/topic/$tid">Testtopic $tid</a>\.\.\. \(<span class="mark">\d*</span>\)</p>~);
}

#################################################
# Themen erstellen
#################################################

my $tid = 1;
my @Topics = map {[$tid++, Testinit::test_randstring()]} 1 .. 4;

login1();
for my $tix ( 0 .. $#Topics ) {
    my $tid = $tix + 1;
    $t->post_ok('/topic/new', 
        form => {
            titlestring => "Testtopic $tid",
            textdata => $Topics[$tix][1]
        })->status_is(302)->content_is('');
}

#################################################
# ein Thema schon mal anguggen mit User 2
#################################################

login2();
$t->get_ok('/topic/2')->status_is(200)
  ->content_like(qr~$Topics[1][1]~);

#################################################
# auch das beguggte Thema bekommt einen neuen Beitrag
#################################################

login1();
$t->post_ok('/topic/2/new', form => {
    textdata => $Topics[1][1] = Testinit::test_randstring(),
})->status_is(302)->content_is('');

#################################################
# Hier gibt es auch mal nichts neues
#################################################

login2();
$t->get_ok('/topic/3')->status_is(200)
  ->content_like(qr~$Topics[2][1]~);

#################################################
# gibt es was neues für User 2 und 3?
#################################################

login2();
$t->get_ok('/forum')->status_is(200);
check_new(1,1);
check_new(2,1);
check_old(3);
check_new(4,1);

login3();
$t->get_ok('/forum')->status_is(200);
check_new(1,1);
check_new(2,2);
check_new(3,1);
check_new(4,1);

#################################################
# User 2 markiert gleich mal alles als gelesen
#################################################

login2();
$t->get_ok('/topic/mark_all_read')->status_is(302)
  ->content_is('')->header_is(Location => '/forum');
$t->get_ok('/forum')->status_is(200);
check_old(1);
check_old(2);
check_old(3);
check_old(4);

#################################################
# User 3 hat noch nichts gelesen
#################################################

login3();
$t->get_ok('/forum')->status_is(200);
check_new(1,1);
check_new(2,2);
check_new(3,1);
check_new(4,1);

