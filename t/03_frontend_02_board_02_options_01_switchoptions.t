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
use Ffc::Data::General;
use Ffc::Data::Board::Views;

use Test::More tests => 21;

my $t = Test::General::test_prepare_frontend('Ffc');

note('Benutzeranmeldung');
$t->get_ok('/logout');
my $user = Test::General::test_get_rand_user();
$t->post_ok( '/login',
    form => { user => $user->{name}, pass => $user->{password} } )
  ->status_is(302)
  ->header_like( Location => qr{\Ahttps?://localhost:\d+/\z}xms );

note('normal run, changing theme and color is allowed');
$Ffc::Data::FixBgColor = '0';
$Ffc::Data::FixTheme   = '0';
$t->get_ok('/options')
  ->status_is(200)
  ->content_like(qr'<h2>Einstellungen zum Aussehen des Forums</h2>')
  ->content_like(qr'<h2>Einstellungen zur Hintergrundfarbe des Forums</h2>');

note('disable only color choosing');
$Ffc::Data::FixBgColor = '1';
$Ffc::Data::FixTheme   = '0';
$t->get_ok('/options')
  ->status_is(200)
  ->content_like(qr'<h2>Einstellungen zum Aussehen des Forums</h2>')
  ->content_unlike(qr'<h2>Einstellungen zur Hintergrundfarbe des Forums</h2>');

note('disable only theme choosing');
$Ffc::Data::FixBgColor = '0';
$Ffc::Data::FixTheme   = '1';
$t->get_ok('/options')
  ->status_is(200)
  ->content_unlike(qr'<h2>Einstellungen zum Aussehen des Forums</h2>')
  ->content_like(qr'<h2>Einstellungen zur Hintergrundfarbe des Forums</h2>');

note('disable theme and color choosing');
$Ffc::Data::FixBgColor = '1';
$Ffc::Data::FixTheme   = '1';
$t->get_ok('/options')
  ->status_is(200)
  ->content_unlike(qr'<h2>Einstellungen zum Aussehen des Forums</h2>')
  ->content_unlike(qr'<h2>Einstellungen zur Hintergrundfarbe des Forums</h2>');

