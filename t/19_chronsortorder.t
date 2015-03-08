use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use Ffc::Plugin::Config;
use File::Temp qw~tempfile tempdir~;
use File::Spec::Functions qw(catfile catdir splitdir);

use Test::Mojo;
use Test::More tests => 128;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1 );
Testinit::test_login($t, $user1, $pass1);

$t->post_ok('/topic/new', form => {titlestring => 'aa', textdata => 'aaa'})->status_is(302);
$t->post_ok('/topic/new', form => {titlestring => 'bb', textdata => 'bbb'})->status_is(302);

sub set_sort_chron {
    $t->get_ok('/topic/sort/chronological')->status_is(302);
    $t->get_ok('/forum')->status_is(200)
      ->content_like(qr~Themenliste ist chronologisch sortiert~)
      ->content_unlike(qr~Themenliste ist alphabetisch sortiert~);
    Testinit::test_info($t, 'Themen werden chronologisch sortiert.');
}
sub set_sort_alpha {
    $t->get_ok('/topic/sort/alphabetical')->status_is(302);
    $t->get_ok('/forum')->status_is(200)
      ->content_like(qr~Themenliste ist alphabetisch sortiert~)
      ->content_unlike(qr~Themenliste ist chronologisch sortiert~);
    Testinit::test_info($t, 'Themen werden alphabetisch sortiert.');
}

note 'alphabetische sortierung default';
$t->get_ok('/forum')->status_is(200)
  ->content_like(qr~<p><a\s+href="/topic/1">aa</a>\.\.\.</p>\s*<p><a\s+href="/topic/2">bb</a>\.\.\.</p>~);

note 'chronologische sortierung';
set_sort_chron();
$t->get_ok('/forum')->status_is(200)
  ->content_like(qr~<p><a\s+href="/topic/2">bb</a>\.\.\.</p>\s*<p><a\s+href="/topic/1">aa</a>\.\.\.</p>~);

note 'alphabetische sortierung';
set_sort_alpha();
$t->get_ok('/forum')->status_is(200)
  ->content_like(qr~<p><a\s+href="/topic/1">aa</a>\.\.\.</p>\s*<p><a\s+href="/topic/2">bb</a>\.\.\.</p>~);

note 'bei chronologischer sortierung müssen angeheftete posts immer oben sein, ignorierte immer unten';
set_sort_chron();
$t->post_ok('/topic/new', form => {titlestring => 'cc', textdata => 'ccc'})->status_is(302);
$t->post_ok('/topic/new', form => {titlestring => 'dd', textdata => 'ddd'})->status_is(302);
$t->post_ok('/topic/new', form => {titlestring => 'ee', textdata => 'eee'})->status_is(302);
$t->post_ok('/topic/new', form => {titlestring => 'ff', textdata => 'fff'})->status_is(302);
$t->get_ok('/topic/1/ignore')->status_is(302);
$t->get_ok('/topic/2/pin')->status_is(302);
$t->get_ok('/topic/3/ignore')->status_is(302);
$t->get_ok('/topic/4/pin')->status_is(302);
$t->get_ok('/forum')->status_is(200)
  ->content_like(qr~
    <p><a\s+href="/topic/4">dd</a>\.\.\.</p>\s*
    <p><a\s+href="/topic/2">bb</a>\.\.\.</p>\s+
    <p><a\s+href="/topic/6">ff</a>\.\.\.</p>\s+
    <p><a\s+href="/topic/5">ee</a>\.\.\.</p>\s*
    <p><a\s+href="/topic/3">cc</a>\.\.\.</p>\s*
    <p><a\s+href="/topic/1">aa</a>\.\.\.</p>~x);


note 'bei alphabetischer sortierung müssen angeheftete posts immer oben sein, ignorierte immer unten';
set_sort_alpha();
$t->get_ok('/forum')->status_is(200)
  ->content_like(qr~
    <p><a\s+href="/topic/2">bb</a>\.\.\.</p>\s*
    <p><a\s+href="/topic/4">dd</a>\.\.\.</p>\s+
    <p><a\s+href="/topic/5">ee</a>\.\.\.</p>\s+
    <p><a\s+href="/topic/6">ff</a>\.\.\.</p>\s*
    <p><a\s+href="/topic/1">aa</a>\.\.\.</p>\s*
    <p><a\s+href="/topic/3">cc</a>\.\.\.</p>~x);

note 'chronsortorder soll logout überleben';
Testinit::test_logout($t);
Testinit::test_login($t, $user1, $pass1);
$t->get_ok('/forum')->status_is(200)
  ->content_like(qr~
    <p><a\s+href="/topic/2">bb</a>\.\.\.</p>\s*
    <p><a\s+href="/topic/4">dd</a>\.\.\.</p>\s+
    <p><a\s+href="/topic/5">ee</a>\.\.\.</p>\s+
    <p><a\s+href="/topic/6">ff</a>\.\.\.</p>\s*
    <p><a\s+href="/topic/1">aa</a>\.\.\.</p>\s*
    <p><a\s+href="/topic/3">cc</a>\.\.\.</p>~x);
set_sort_chron();
Testinit::test_logout($t);
Testinit::test_login($t, $user1, $pass1);
$t->get_ok('/forum')->status_is(200)
  ->content_like(qr~
    <p><a\s+href="/topic/4">dd</a>\.\.\.</p>\s*
    <p><a\s+href="/topic/2">bb</a>\.\.\.</p>\s+
    <p><a\s+href="/topic/6">ff</a>\.\.\.</p>\s+
    <p><a\s+href="/topic/5">ee</a>\.\.\.</p>\s*
    <p><a\s+href="/topic/3">cc</a>\.\.\.</p>\s*
    <p><a\s+href="/topic/1">aa</a>\.\.\.</p>~x);
