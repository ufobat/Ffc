use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 335;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();

my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my ( $user2, $pass2 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1, $user2, $pass2 );

my ( @Topics, @Articles );
my $tit = 'a' x 257;

sub login1 { Testinit::test_login(   $t, $user1, $pass1 ) }
sub login2 { Testinit::test_login(   $t, $user2, $pass2 ) }
sub ch_err { Testinit::test_error(   $t, @_             ) }
sub ch_nfo { Testinit::test_info(    $t, @_             ) }
sub ch_wrn { Testinit::test_warning( $t, @_             ) }

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

$t->post_ok('/topic/new', form => {titlestring => $tit, textdata => $Articles[0][0]})->status_is(200);
ch_err('Die Überschrift ist zu lang und darf höchstens 256 Zeichen enthalten.');
$t->content_like(qr~<input type="text" class="titlestring" name="titlestring" value="$tit" />~);
$t->content_like(qr~<textarea name="textdata" id="textinput" class="edit inedit" >$Articles[0][0]</textarea>~);

$t->post_ok('/topic/new', form => {titlestring => $Topics[0], textdata => $Articles[0][0]})->status_is(302);
$t->header_like( Location => qr{\Ahttps?://localhost:\d+/topic/1}xms );
$t->get_ok('/')->status_is(200)
  ->content_like(qr~$Topics[0]~)->content_like(qr~/topic/1~);
ch_nfo('Ein neuer Beitrag wurde erstellt');
$t->get_ok('/topic/1')->status_is(200)
  ->content_like(qr~$Topics[0]~)->content_like(qr~$Articles[0][0]~);

#############################################################################
### Weitere Artikel aus der Topicliste zum Thema hinzufügen
login1();
$Articles[0][1] = Testinit::test_randstring();
$t->get_ok('/topic/1')->status_is(200)
  ->content_like(qr~$Topics[0]~)->content_like(qr~$Articles[0][0]~);

$t->post_ok('/topic/new', form => {titlestring => $Topics[0], textdata => $Articles[0][1]})->status_is(302);
$t->header_like( Location => qr{\Ahttps?://localhost:\d+/topic/1}xms );
$t->get_ok('/')->status_is(200)
  ->content_like(qr~$Topics[0]~)->content_like(qr~/topic/1~);
ch_nfo('Ein neuer Beitrag wurde erstellt');
$t->get_ok('/topic/1')->status_is(200)
  ->content_like(qr~$Topics[0]~)->content_like(qr~$Articles[0][0]~)->content_like(qr~$Articles[0][1]~);

#############################################################################
### Weiteres Tema anfügen
login1();
push @Topics, Testinit::test_randstring();
push @Articles, [Testinit::test_randstring()];
$t->post_ok('/topic/new', form => {titlestring => $Topics[1], textdata => $Articles[1][0]})->status_is(302);

$t->header_like( Location => qr{\Ahttps?://localhost:\d+/topic/2}xms );
$t->get_ok('/')->status_is(200)
  ->content_like(qr~$Topics[0]~)->content_like(qr~/topic/1~)
  ->content_like(qr~$Topics[1]~)->content_like(qr~/topic/2~);
ch_nfo('Ein neuer Beitrag wurde erstellt');
$t->get_ok('/topic/2')->status_is(200)
  ->content_like(qr~$Topics[1]~)->content_like(qr~$Articles[1][0]~);

#############################################################################
### Thema umbenennen
login2();
$t->get_ok('/topic/2')->status_is(200)->content_unlike(qr~/topic/2/edit~);

login1();
$t->get_ok('/topic/2')->status_is(200)->content_like(qr~/topic/2/edit~);
$t->get_ok('/topic/2/edit')->status_is(200)
  ->content_like(qr~Themenüberschrift verändern~)
  ->content_like(qr~<a href="/forum" title="&Auml;nderung abbrechen">Abbrechen</a>~)
  ->content_like(qr~<form action="/topic/2/edit" method="post">~)
  ->content_like(qr~<input type="text" class="titlestring" name="titlestring" value="$Topics[1]" />~);

$t->post_ok('/topic/2/edit', form => { titlestring => 'a' })->status_is(200)
  ->content_like(qr~Themenüberschrift verändern~)
  ->content_like(qr~<a href="/forum" title="&Auml;nderung abbrechen">Abbrechen</a>~)
  ->content_like(qr~<form action="/topic/2/edit" method="post">~)
  ->content_like(qr~<input type="text" class="titlestring" name="titlestring" value="a" />~);
ch_err('Die Übschrift ist zu kurz und muss mindestens zwei Zeichen enthalten.');

$t->post_ok('/topic/2/edit', form => { titlestring => $tit })->status_is(200)
  ->content_like(qr~Themenüberschrift verändern~)
  ->content_like(qr~<a href="/forum" title="&Auml;nderung abbrechen">Abbrechen</a>~)
  ->content_like(qr~<form action="/topic/2/edit" method="post">~)
  ->content_like(qr~<input type="text" class="titlestring" name="titlestring" value="$tit" />~);
ch_err('Die Überschrift ist zu lang und darf höchstens 256 Zeichen enthalten.');

my $oldtopic = $Topics[1];
$Topics[1] = Testinit::test_randstring();
$t->post_ok('/topic/2/edit', form => { titlestring => $Topics[1] })->status_is(302);
$t->header_like( Location => qr{\Ahttps?://localhost:\d+/topic/2}xms );
$t->get_ok('/')->status_is(200)
  ->content_like(qr~$Topics[1]~)->content_like(qr~/topic/2~)->content_unlike(qr~$oldtopic~);
ch_nfo('Die Überschrift des Themas wurde geändert.');
$t->get_ok('/topic/2')->status_is(200)
  ->content_like(qr~$Topics[1]~)->content_like(qr~$Articles[1][0]~);

login2();
$t->get_ok('/')->status_is(200)
  ->content_like(qr~$Topics[1]~)->content_like(qr~/topic/2~)->content_unlike(qr~$oldtopic~);
$t->get_ok('/topic/2')->status_is(200)
  ->content_like(qr~$Topics[1]~)->content_like(qr~$Articles[1][0]~);

my $newtopic = Testinit::test_randstring();
$t->post_ok('/topic/2/edit', form => { titlestring => $newtopic })->status_is(302);
$t->header_like( Location => qr{\Ahttps?://localhost:\d+/topic/2}xms );
$t->get_ok('/topic/2')->status_is(200)
  ->content_like(qr~$Topics[1]~)->content_like(qr~/topic/2~)->content_unlike(qr~$newtopic~);
ch_err('Kann das Thema nicht ändern, da es nicht von Ihnen angelegt wurde und Sie auch kein Administrator sind.');

Testinit::test_login($t, $admin, $apass);
$oldtopic = $Topics[1];
$Topics[1] = Testinit::test_randstring();
$t->post_ok('/topic/2/edit', form => { titlestring => $Topics[1] })->status_is(302);
$t->header_like( Location => qr{\Ahttps?://localhost:\d+/topic/2}xms );
$t->get_ok('/')->status_is(200)
  ->content_like(qr~$Topics[1]~)->content_like(qr~/topic/2~)->content_unlike(qr~$oldtopic~);
ch_nfo('Die Überschrift des Themas wurde geändert.');
$t->get_ok('/topic/2')->status_is(200)
  ->content_like(qr~$Topics[1]~)->content_like(qr~$Articles[1][0]~);

#############################################################################
### Themen zusammenführen
login2();

$t->post_ok('/topic/1/edit', form => { titlestring => $Topics[1] })->status_is(200)
  ->content_like(qr~<a href="/topic/1/moveto/2" title="Alle Beiträge in das andere Thema verschieben">~)
  ->content_like(qr~<a href="/topic/1/edit" title="Überschrift des Themas und dessen Beiträge beibehalten">~);
ch_wrn('Das gewünschte Thema existiert bereits.');

login1(); # Fehler
$t->get_ok('/topic/1/moveto/2')->status_is(302);
$t->header_like( Location => qr{\Ahttps?://localhost:\d+/forum}xms );
$t->get_ok('/')->status_is(200)
  ->content_like(qr~"/topic/new"~)->content_like(qr~<div class="postbox topiclist">~)
  ->content_like(qr~$Topics[0]~)->content_like(qr~/topic/1~)
  ->content_like(qr~$Topics[1]~)->content_like(qr~/topic/2~);
ch_err('Kann das Thema nicht ändern, da es nicht von Ihnen angelegt wurde und Sie auch kein Administrator sind.');

login2();
$t->get_ok('/topic/1/moveto/2')->status_is(302);
$t->header_like( Location => qr{\Ahttps?://localhost:\d+/topic/2}xms );
$t->get_ok('/topic/2')->status_is(200);
ch_nfo('Die Beiträge wurden in ein anderes Thema verschoben.');
$t->content_like(qr~$_~) for @{$Articles[0]}, @{$Articles[1]};
$t->get_ok('/')->status_is(200)
  ->content_like(qr~"/topic/new"~)->content_like(qr~<div class="postbox topiclist">~)
  ->content_unlike(qr~$Topics[0]~)->content_unlike(qr~/topic/1~)
  ->content_like(qr~$Topics[1]~)->content_like(qr~/topic/2~);
$t->get_ok('/topic/1')->status_is(200)
  ->content_like(qr~"/topic/new"~)->content_like(qr~<div class="postbox topiclist">~);
ch_err('Konnte das gewünschte Thema nicht finden.');

