use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 83;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();

my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my ( $user2, $pass2 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1, $user2, $pass2 );

my ( @Topics, @Articles );

sub login1 { Testinit::test_login($t, $user1, $pass1) }
sub login2 { Testinit::test_login($t, $user2, $pass2) }
sub ch_err { Testinit::test_error( $t, @_ ) }
sub ch_nfo { Testinit::test_info(  $t, @_ ) }

#############################################################################
### Ausgangslage checken

login1();
$t->get_ok('/')->status_is(200)
  ->content_like(qr~<div class="postbox topiclist">\s*</div>~)
  ->content_like(qr~<a href="/topic/new" title=~);

login2();
$t->get_ok('/')->status_is(200)
  ->content_like(qr~<div class="postbox topiclist">\s*</div>~);

#############################################################################
### Neues Thema beginnen - Fehlerbehandlung

push @Topics, Testinit::test_randstring();
push @Articles, [Testinit::test_randstring()];

$t->post_ok('/topic/new', form => {titlestring => $Topics[0]})->status_is(200);
ch_err('Es wurde zu wenig Text eingegeben \\(min. 2 Zeichen\\)');
$t->content_like(qr~<input type="text" class="titlestring" name="titlestring" value="$Topics[0]" />~);

$t->post_ok('/topic/new', form => {titlestring => $Topics[0], textdata => 'a'})->status_is(200);
ch_err('Es wurde zu wenig Text eingegeben \\(min. 2 Zeichen\\)');
$t->content_like(qr~<input type="text" class="titlestring" name="titlestring" value="$Topics[0]" />~);
$t->content_like(qr~<textarea name="textdata" id="textinput" class="edit inedit" >a</textarea>~);

$t->post_ok('/topic/new', form => {textdata => $Articles[0][0]})->status_is(200);
ch_err('Die Übschrift ist zu kurz und muss mindestens zwei Zeichen enthalten.');

$t->post_ok('/topic/new', form => {titlestring => 'a', textdata => $Articles[0][0]})->status_is(200);
ch_err('Die Übschrift ist zu kurz und muss mindestens zwei Zeichen enthalten.');
$t->content_like(qr~<input type="text" class="titlestring" name="titlestring" value="a" />~);
$t->content_like(qr~<textarea name="textdata" id="textinput" class="edit inedit" >$Articles[0][0]</textarea>~);

my $tit = 'a' x 257;
$t->post_ok('/topic/new', form => {titlestring => $tit, textdata => $Articles[0][0]})->status_is(200);
ch_err('Die Überschrift ist zu lang und darf höchstens 256 Zeichen enthalten.');
$t->content_like(qr~<input type="text" class="titlestring" name="titlestring" value="$tit" />~);
$t->content_like(qr~<textarea name="textdata" id="textinput" class="edit inedit" >$Articles[0][0]</textarea>~);

$t->post_ok('/topic/new', form => {titlestring => $Topics[0], textdata => $Articles[0][0]})->status_is(302);
$t->header_like( Location => qr{\Ahttps?://localhost:\d+/topic/1}xms );
$t->get_ok('/')->status_is(200)
  ->content_like(qr~$Topics[0]~)->content_like(qr~/topic/1~);
$t->get_ok('/topic/1')->status_is(200)
  ->content_like(qr~$Topics[0]~)->content_like(qr~$Articles[0][0]~);

#############################################################################
### Weitere Artikel zum Thema hinzu fügen
login1();
