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

use Test::More tests => 140;

my $t = Test::General::test_prepare_frontend('Ffc');

note('Benutzeranmeldung');
$t->get_ok('/logout');
my $user = Test::General::test_get_rand_user();
$t->post_ok( '/login',
    form => { user => $user->{name}, pass => $user->{password} } )
  ->status_is(302)
  ->header_like( Location => qr{\Ahttps?://localhost:\d+/\z}xms );

for ( 1..3 ) {
    $t->get_ok('/')
      ->status_is(200)
      ->content_like(qr'"/options/mobile"')
      ->content_unlike(qr'"/options/desktop"')
      ->content_unlike(qr'/mobile.css')
      ->content_like(qr'/themes/default/css/style.css');

    $t->get_ok('/options')
      ->status_is(200)
      ->content_like(qr'"/options/mobile"')
      ->content_unlike(qr'"/desktop"')
      ->content_unlike(qr'/mobile.css')
      ->content_like(qr'/themes/default/css/style.css')
      ->content_like(qr'<h2>Einstellungen zum Aussehen des Forums</h2>')
      ->content_like(qr'<h2>Einstellungen zur Hintergrundfarbe des Forums</h2>')
      ->content_like(qr'<h2>Benutzeravatar verwalten</h2>');

    $t->get_ok('/options/mobile')
      ->status_is(200)
      ->content_unlike(qr'"/options/mobile"')
      ->content_like(qr'"/options/desktop"')
      ->content_like(qr'/mobile.css')
      ->content_unlike(qr'/themes/default/css/style.css');

    $t->get_ok('/options')
      ->status_is(200)
      ->content_unlike(qr'"/options/mobile"')
      ->content_like(qr'"/options/desktop"')
      ->content_like(qr'/mobile.css')
      ->content_unlike(qr'/themes/default/css/style.css')
      ->content_unlike(qr'<h2>Einstellungen zum Aussehen des Forums</h2>')
      ->content_unlike(qr'<h2>Einstellungen zur Hintergrundfarbe des Forums</h2>')
      ->content_unlike(qr'<h2>Benutzeravatar verwalten</h2>');

    $t->get_ok('/options/desktop')
      ->status_is(200)
      ->content_like(qr'"/options/mobile"')
      ->content_unlike(qr'"/desktop"')
      ->content_unlike(qr'/mobile.css')
      ->content_like(qr'/themes/default/css/style.css');

    $t->get_ok('/options')
      ->status_is(200)
      ->content_like(qr'"/options/mobile"')
      ->content_unlike(qr'"/desktop"')
      ->content_unlike(qr'/mobile.css')
      ->content_like(qr'/themes/default/css/style.css')
      ->content_like(qr'<h2>Einstellungen zum Aussehen des Forums</h2>')
      ->content_like(qr'<h2>Einstellungen zur Hintergrundfarbe des Forums</h2>')
      ->content_like(qr'<h2>Benutzeravatar verwalten</h2>');
}

