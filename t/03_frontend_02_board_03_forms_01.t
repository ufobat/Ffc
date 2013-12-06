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

use Test::More tests => 14;

my $t1 = Test::General::test_prepare_frontend('Ffc');

my $u1 = Mock::Testuser->new_active_user();
my $u2 = Mock::Testuser->new_active_user();
my $text1 = Test::General::test_r();
my $text2 = Test::General::test_r();
my $text3 = Test::General::test_r();

$t1->get_ok('/logout')
  ->status_is(200)
  ->content_like(qr/Bitte\s+melden\s+Sie\s+sich\s+an/xmsi);
$t1->post_ok( '/login',
    form => { user => $u1->{name}, pass => $u1->{password} } )
  ->status_is(302)
  ->header_like( Location => qr{\Ahttps?://localhost:\d+/}xms );
$t1->post_ok('/forum/new', form => { post => $text1 } )
  ->status_is(302)
  ->header_like( Location => qr{\Ahttps?://localhost:\d+/}xms );
$t1->get_ok('/forum')
  ->status_is(200)
  ->content_like(qr/$text1/);
my $id = Ffc::Data::dbh()->selectall_arrayref('SELECT id FROM '.$Ffc::Data::Prefix.'posts WHERE textdata=?', undef, $text1)->[0]->[0];
ok $id, 'got a post id';

