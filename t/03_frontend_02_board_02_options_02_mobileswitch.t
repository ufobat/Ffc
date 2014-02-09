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

use Test::More tests => 142;

my $t = Test::General::test_prepare_frontend('Ffc');

note('Benutzeranmeldung');
$t->get_ok('/logout');
my $user = Test::General::test_get_rand_user();
$t->post_ok( '/login',
    form => { user => $user->{name}, pass => $user->{password} } )
  ->status_is(302)
  ->header_like( Location => qr{\Ahttps?://localhost:\d+/\z}xms );

$t->post_ok( qq'/options/bgcolor_save', form => { bgcolor => 'silver' } )
  ->status_is(200);

for ( 1..3 ) {
    $t->get_ok('/')
      ->status_is(200)
      ->content_like(qr'"/options/mobile"')
      ->content_unlike(qr'"/options/desktop"')
      ->content_like(qr'background-color: silver;')
      ->content_unlike(qr'/themes/mobil/css/style.css')
      ->content_like(qr'/themes/default/css/style.css');

    $t->get_ok('/options')
      ->status_is(200)
      ->content_like(qr'"/options/mobile"')
      ->content_unlike(qr'"/desktop"')
      ->content_unlike(qr'/themes/mobil/css/style.css')
      ->content_like(qr'/themes/default/css/style.css')
      ->content_like(qr'background-color: silver;')
      ->content_like(qr'<h2>Einstellungen zum Aussehen des Forums</h2>');

    $t->get_ok('/options/mobile')
      ->status_is(200)
      ->content_unlike(qr'"/options/mobile"')
      ->content_like(qr'"/options/desktop"')
      ->content_like(qr'/themes/mobil/css/style.css')
      ->content_like(qr'background-color: silver;')
      ->content_unlike(qr'/themes/default/css/style.css');

    $t->get_ok('/options')
      ->status_is(200)
      ->content_unlike(qr'"/options/mobile"')
      ->content_like(qr'"/options/desktop"')
      ->content_like(qr'/themes/mobil/css/style.css')
      ->content_unlike(qr'/themes/default/css/style.css')
      ->content_like(qr'background-color: silver;')
      ->content_unlike(qr'<h2>Einstellungen zum Aussehen des Forums</h2>');

    $t->get_ok('/options/desktop')
      ->status_is(200)
      ->content_like(qr'"/options/mobile"')
      ->content_unlike(qr'"/desktop"')
      ->content_unlike(qr'/themes/mobil/css/style.css')
      ->content_like(qr'background-color: silver;')
      ->content_like(qr'/themes/default/css/style.css');

    $t->get_ok('/options')
      ->status_is(200)
      ->content_like(qr'"/options/mobile"')
      ->content_unlike(qr'"/desktop"')
      ->content_unlike(qr'/themes/mobil/css/style.css')
      ->content_like(qr'/themes/default/css/style.css')
      ->content_like(qr'background-color: silver;')
      ->content_like(qr'<h2>Einstellungen zum Aussehen des Forums</h2>');
}

