use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 124;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();

my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my ( $user2, $pass2 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1, $user2, $pass2 );

my $timeqr = qr~(?:jetzt|(\d?\d\.\d?\d\.\d\d\d\d, )?\d?\d:\d\d)~;

sub login1 { Testinit::test_login(   $t, $user1, $pass1 ) }
sub login2 { Testinit::test_login(   $t, $user2, $pass2 ) }
sub ch_err { Testinit::test_error(   $t, @_             ) }
sub ch_nfo { Testinit::test_info(    $t, @_             ) }
sub ch_wrn { Testinit::test_warning( $t, @_             ) }

# Copy und Paste aus t/11_topiclist.t - Kann man ja mal erweitern
my @Topics = ('asdf');
my @Articles = (['fdsa']);

login1();
$t->post_ok('/topic/new', form => {titlestring => $Topics[0], textdata => $Articles[0][0]})->status_is(302);
$t->header_like( Location => qr{\A/topic/1}xms );
$t->get_ok('/')->status_is(200)
  ->content_like(qr~<a href="/topic/1">$Topics[0]</a>~)
  ->content_like(qr~$user1,\n\s*$timeqr~);
ch_nfo('Ein neuer Beitrag wurde erstellt');

login2();
$t->get_ok('/')->status_is(200)
  ->content_like(qr~<span class="smallfont">\(\s*Neu: <span class="mark">1</span>,\s*$user1,\n\s*$timeqr,\s*~)
  ->content_like(qr~<a href="/topic/1">$Topics[0]</a>~);
$t->get_ok('/topic/1')->status_is(200)->content_like(qr~$Articles[0][0]~);
$t->post_ok('/topic/1/new', form => {textdata => $Articles[0][0]})
  ->status_is(302)->header_like(Location => qr~/topic/1~);
$t->get_ok('/topic/1')->status_is(200)->content_like(qr~$Articles[0][0]~);
ch_nfo('Ein neuer Beitrag wurde erstellt');
$t->get_ok('/')->status_is(200)
  ->content_like(qr~<a href="/topic/1">$Topics[0]</a>~)
  ->content_like(qr~$user2,\n\s*$timeqr,~);

login1();
$t->get_ok('/')->status_is(200)
  ->content_like(qr~<span class="smallfont">\(\s*Neu: <span class="mark">1</span>,\s*$user2,\n\s*$timeqr,\s*~)
  ->content_like(qr~<a href="/topic/1">$Topics[0]</a>~);
$t->get_ok('/topic/1')->status_is(200)->content_like(qr~$Articles[0][0]~);
$t->post_ok('/topic/1/new', form => {textdata => $Articles[0][0]})
  ->status_is(302)->header_like(Location => qr~/topic/1~);
$t->get_ok('/topic/1')->status_is(200)->content_like(qr~$Articles[0][0]~);
ch_nfo('Ein neuer Beitrag wurde erstellt');
$t->post_ok('/topic/1/new', form => {textdata => $Articles[0][0]})
  ->status_is(302)->header_like(Location => qr~/topic/1~);
$t->get_ok('/topic/1')->status_is(200)->content_like(qr~$Articles[0][0]~);
ch_nfo('Ein neuer Beitrag wurde erstellt');
$t->post_ok('/topic/1/new', form => {textdata => $Articles[0][0]})
  ->status_is(302)->header_like(Location => qr~/topic/1~);
$t->get_ok('/topic/1')->status_is(200)->content_like(qr~$Articles[0][0]~);
ch_nfo('Ein neuer Beitrag wurde erstellt');
$t->get_ok('/')->status_is(200)
  ->content_like(qr~<a href="/topic/1">$Topics[0]</a>~)
  ->content_like(qr~$user1,\n\s*$timeqr,~);

login2();
$t->get_ok('/')->status_is(200)
  ->content_like(qr~<span class="smallfont">\(\s*Neu: <span class="mark">3</span>,\s*$user1,\n\s*$timeqr,\s*~)
  ->content_like(qr~<a href="/topic/1">$Topics[0]</a>~);

