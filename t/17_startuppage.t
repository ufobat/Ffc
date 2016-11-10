use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 106;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user, $pass ) = qw(test test1234);
Testinit::test_add_user( $t, $admin, $apass, $user, $pass );
sub admin { Testinit::test_login( $t, $admin, $apass ) }
sub user  { Testinit::test_login( $t, $user,  $pass  ) }
sub error { Testinit::test_error( $t, @_             ) }
sub info  { Testinit::test_info(  $t, @_             ) }
sub rstr  { Testinit::test_randstring(               ) }

my @Topics = (
    [1, rstr(), rstr()],
    [2, rstr(), rstr()],
    [3, rstr(), rstr()],
);

user();
$t->post_ok('/topic/new', form => {titlestring => $_->[1], textdata => $_->[2]})
  ->status_is(302) for @Topics;

$t->get_ok('/')->status_is(200)
  ->content_like(qr'Allgemeines Forum');

$t->post_ok('/admin/set_starttopic', form => { topicid => '0' })
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
error('Nur Administratoren dürfen das');
$t->get_ok('/')->status_is(200)
  ->content_like(qr'Allgemeines Forum');

admin();
$t->get_ok('/admin/form')->status_is(200)
  ->content_like(qr~<select\s+name="topicid">\s*<option\s+value="">~xmso);
$t->content_like(qr~<option\s+value="$_->[0]">$_->[1]</option>~xmso)
    for @Topics;

$t->post_ok('/admin/set_starttopic', form => { topicid => 'asdf' })
  ->status_is(302)->content_is('')->header_is(Location => '/admin/form');
$t->get_ok('/admin/form')->status_is(200);
error('Fehler beim Setzen der Startseite');

$t->get_ok('/config')->status_is(200)
  ->json_is('/starttopic' => 0);

$t->post_ok('/admin/set_starttopic', form => { topicid => 2 })
  ->status_is(302)->content_is('')->header_is(Location => '/admin/form');
$t->get_ok('/admin/form')->status_is(200)
  ->content_like(qr~<select\s+name="topicid">\s*<option\s+value="">~xmso)
  ->content_like(qr~<option\s+value="1">$Topics[0][1]</option>~xmso)
  ->content_like(qr~<option\s+value="2"\s+selected="selected">$Topics[1][1]</option>~xmso)
  ->content_like(qr~<option\s+value="3">$Topics[2][1]</option>~xmso);
info('Startseitenthema geändert');
$t->get_ok('/config')->status_is(200)
  ->json_is('/starttopic' => 2);

$t->get_ok('/')->status_is(302)
  ->header_like( Location => qr{\A/topic/2}xms );

$t->post_ok('/admin/set_starttopic', form => { topicid => '' })
  ->status_is(302)->content_is('')->header_is(Location => '/admin/form');
$t->get_ok('/admin/form')->status_is(200)
  ->content_like(qr~<select\s+name="topicid">\s*<option\s+value="">~xmso);
$t->content_like(qr~<option\s+value="$_->[0]">$_->[1]</option>~xmso)
    for @Topics;
info('Startseitenthema zurückgesetzt');

$t->get_ok('/config')->status_is(200)
  ->json_is('/starttopic' => 0);

$t->get_ok('/')->status_is(200)
  ->content_like(qr'Allgemeines Forum');

