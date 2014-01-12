#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Test::Mojo;
use Test::General;
use Mock::Testuser;
use Ffc::Data::Board::Views;

use Test::More tests => 112;

my $t1 = Test::General::test_prepare_frontend('Ffc');
my $t2 = Test::Mojo->new('Ffc');
$t2->ua->server($t1->ua->server);

my $u1 = Mock::Testuser->new_active_user();
my $u2 = Mock::Testuser->new_active_user();
my $text1 = Test::General::test_r();
my $text2 = Test::General::test_r();

note('Benutzer 1 ('.$u1->{name}.') anmeldem und testposten');
$t1->get_ok('/logout')
  ->status_is(200)
  ->content_like(qr/Nicht\s+angemeldet/)
  ->content_like(qr/Bitte\s+melden\s+Sie\s+sich\s+an/xmsi);
$t1->post_ok( '/login',
    form => { user => $u1->{name}, pass => $u1->{password} } )
  ->status_is(302)
  ->header_like( Location => qr{\Ahttps?://localhost:\d+/}xms );

$t1->get_ok('/')
  ->status_is(200)
  ->content_like(qr/$u1->{name}\s+abmelden/);

$t1->post_ok('/forum/new', form => { post => $text1 } )
  ->status_is(302)
  ->header_like( Location => qr{\Ahttps?://localhost:\d+/}xms );
$t1->get_ok('/forum')
  ->status_is(200)
  ->content_like(qr/$text1/);
note('wait for it');
sleep 1.2;
note('Benutzer 2 ('.$u2->{name}.') anmeldem und testposten');
$t2->get_ok('/logout')
  ->status_is(200)
  ->content_like(qr/Nicht\s+angemeldet/)
  ->content_like(qr/Bitte\s+melden\s+Sie\s+sich\s+an/xmsi);
$t2->post_ok( '/login',
    form => { user => $u2->{name}, pass => $u2->{password} } )
  ->status_is(302)
  ->header_like( Location => qr{\Ahttps?://localhost:\d+/}xms );

$t2->get_ok('/')
  ->status_is(200)
  ->content_like(qr/$text1/)
  ->content_like(qr/$u2->{name}\s+abmelden/)
  ->content_like(qr~Ffc\s+\(1/0\)~);
$t2->get_ok('/')
  ->status_is(200)
  ->content_like(qr/$text1/)
  ->content_like(qr/$u2->{name}\s+abmelden/)
  ->content_unlike(qr~Ffc\s+\(1/0\)~);

$t2->post_ok('/forum/new', form => { post => $text2 } )
  ->status_is(302)
  ->content_is('')
  ->header_like( Location => qr{\Ahttps?://localhost:\d+/}xms );
$t2->get_ok('/forum')
  ->status_is(200)
  ->content_like(qr/$text1/)
  ->content_like(qr/$text2/);

{
    my $cnt = Ffc::Data::dbh()->selectall_arrayref('SELECT COUNT(id) FROM '.$Ffc::Data::Prefix.'posts')->[0]->[0];
    is $cnt, 2, 'post count is ok';
}

{
    my $id = Ffc::Data::dbh()->selectall_arrayref('SELECT id FROM '.$Ffc::Data::Prefix.'posts WHERE textdata=?', undef, $text1)->[0]->[0];
    ok $id, 'got a post id';
}

{
    my $id = Ffc::Data::dbh()->selectall_arrayref('SELECT id FROM '.$Ffc::Data::Prefix.'posts WHERE textdata=?', undef, $text2)->[0]->[0];
    ok $id, 'got a post id';
}

my $text3 = Test::General::test_r();
my $text4 = Test::General::test_r();

note('Tests fuer neue Beitrage');
note(qq(Etwas als Benutzer 1 "$u1->{name}" posten));
note('wait for it');
sleep 1.2;
$t1->get_ok('/')
  ->status_is(200)
  ->content_like(qr/$text1/)
  ->content_like(qr/$text2/)
  ->content_like(qr/$u1->{name}\s+abmelden/)
  ->content_like(qr~<form\s+action="/forum/new"\s+(?:accept\-charset="UTF\-8"\s)?method="POST">~)
  ->content_like(qr~Ffc\s+\(1/0\)~);
$t1->get_ok('/')
  ->status_is(200)
  ->content_like(qr/$text1/)
  ->content_like(qr/$text2/)
  ->content_like(qr/$u1->{name}\s+abmelden/)
  ->content_like(qr~<form\s+action="/forum/new"\s+(?:accept\-charset="UTF\-8"\s)?method="POST">~)
  ->content_unlike(qr~Ffc\s+\(1/0\)~);
$t1->post_ok('/forum/new', form => { post => $text3 } )
  ->status_is(302)
  ->content_is('')
  ->header_like( Location => qr{\Ahttps?://localhost:\d+/}xms );
$t1->get_ok('/')
  ->status_is(200)
  ->content_like(qr/$text3/);
note('wait for it');
sleep 1.2;
note(qq~Etwas als Benutzer 2 "$u2->{name}" versuchen zu posten (Fehlermeldung)~);
$t2->post_ok('/forum/new', form => { post => $text4 } )
  ->status_is(200)
  ->content_like(qr/Ein\s+neuer\s+Beitrag\s+wurde\s+zwischenzeitlich\s+durch\s+einen\s+anderen\s+Benutzer\s+erstellt/)
  ->content_like(qr~<form\s+action="/forum/new"\s+(?:accept\-charset="UTF\-8"\s)?method="POST">~)
  ->content_like(qr~<textarea\s+name="post"\s+id="textinput"\s+class="insert_post"\s+>$text4</textarea>~);
note('wait for it');
sleep 1.2;
$t2->post_ok('/forum/new', form => { post => $text4 } )
  ->status_is(302)
  ->content_is('')
  ->header_like( Location => qr{\Ahttps?://localhost:\d+/}xms );
$t2->get_ok('/forum')
  ->status_is(200)
  ->content_like(qr~<form\s+action="/forum/new"\s+(?:accept\-charset="UTF\-8"\s)?method="POST">~)
  ->content_like(qr/$text4/);

note(qq'Formular zum Aendern von Beitrag "$text4"');

my $id = Ffc::Data::dbh()->selectall_arrayref('SELECT id FROM '.$Ffc::Data::Prefix.'posts WHERE textdata=?', undef, $text4)->[0]->[0];
ok $id, qq'Id fuer Beitrag "$text4" ist "$id"';

$t2->get_ok("/forum/edit/$id")
  ->status_is(200)
  ->content_like(qr~<form\s+action="/forum/edit/$id"\s+(?:accept\-charset="UTF\-8"\s)?method="POST">~)
  ->content_like(qr~<textarea\s+name="post"\s+id="textinput"\s+class="update_post"\s+>$text4</textarea>~);

note('Tests zum Aendern von Beitrawgen');

my $text5 = Test::General::test_r();
my $text6 = Test::General::test_r();
note(qq(Etwas als Benutzer 1 "$u1->{name}" posten));
note('wait for it');
sleep 1.2;
$t1->get_ok('/')
  ->status_is(200)
  ->content_like(qr/$text1/)
  ->content_like(qr/$text2/)
  ->content_like(qr/$text3/)
  ->content_like(qr/$text4/)
  ->content_like(qr/$u1->{name}\s+abmelden/)
  ->content_like(qr~Ffc\s+\(1/0\)~);
$t1->get_ok('/')
  ->status_is(200)
  ->content_like(qr/$text1/)
  ->content_like(qr/$text2/)
  ->content_like(qr/$text3/)
  ->content_like(qr/$text4/)
  ->content_like(qr/$u1->{name}\s+abmelden/)
  ->content_unlike(qr~Ffc\s+\(1/0\)~);
$t1->post_ok('/forum/new', form => { post => $text5 } )
  ->status_is(302)
  ->content_is('')
  ->header_like( Location => qr{\Ahttps?://localhost:\d+/}xms );
$t1->get_ok('/')
  ->status_is(200)
  ->content_like(qr/$text5/);

note(qq'Einen Beitrag von Benutzer 2 "$u2->{name}" aendern');
$t2->post_ok("/forum/edit/$id", form => { post => $text6 })
  ->status_is(200)
  ->content_like(qr/Ein\s+neuer\s+Beitrag\s+wurde\s+zwischenzeitlich\s+durch\s+einen\s+anderen\s+Benutzer\s+erstellt/)
  ->content_like(qr~<form\s+action="/forum/edit/$id"\s+(?:accept\-charset="UTF\-8"\s)?method="POST">~)
  ->content_like(qr~<textarea\s+name="post"\s+id="textinput"\s+class="update_post"\s+>$text6</textarea>~);

