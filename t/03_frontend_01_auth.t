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

use Test::More tests => 43;

my $t = Test::General::test_prepare_frontend('Ffc');

note('test without login');
$t->get_ok('/')->status_is(200)->content_like(qr{Bitte melden Sie sich an});
$t->get_ok('/msgs')->status_is(200)->content_like(qr{Bitte melden Sie sich an});
$t->get_ok('/notes')->status_is(200)
  ->content_like(qr{Bitte melden Sie sich an});
my $user = Test::General::test_get_rand_user();

note('test login');
$t->post_ok( '/login',
    form => { user => $user->{name}, pass => $user->{password} } )
  ->status_is(302)->header_like(Location => qr{\Ahttps?://localhost:\d+/\z}xms);

note('test with login');
$t->get_ok('/')->status_is(200)->content_like(qr{Keine Daten für die Anzeige vorhanden});
$t->get_ok('/msgs')->status_is(200)->content_like(qr{Keine Daten für die Anzeige vorhanden});
$t->get_ok('/notes')->status_is(200)->content_like(qr{Keine Daten für die Anzeige vorhanden});

note('test logout');
$t->get_ok('/logout')->status_is(200)
  ->content_like(qr{Abmelden bestätigt, bitte melden Sie sich erneut an});
$t->get_ok('/msgs')->status_is(200)->content_like(qr{Bitte melden Sie sich an});
$t->get_ok('/notes')->status_is(200)
  ->content_like(qr{Bitte melden Sie sich an});

note('test login with wrong password');
$user->alter_password;
$t->post_ok( '/login',
    form => { user => $user->{name}, pass => $user->{password} } )
  ->status_is(200)->content_like(qr'Benutzername oder Passwort ungültig,');
$t->get_ok('/')->status_is(200)->content_like(qr{Bitte melden Sie sich an});
$t->get_ok('/msgs')->status_is(200)->content_like(qr{Bitte melden Sie sich an});
$t->get_ok('/notes')->status_is(200)
  ->content_like(qr{Bitte melden Sie sich an});

