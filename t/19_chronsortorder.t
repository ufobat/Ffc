use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use Ffc::Plugin::Config;
use File::Temp qw~tempfile tempdir~;
use File::Spec::Functions qw(catfile catdir splitdir);

use Test::Mojo;
use Test::More tests => 23;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
Testinit::test_login($t, $admin, $apass);

$t->post_ok('/topic/new', form => {titlestring => 'aa', textdata => 'aaa'})->status_is(302);
$t->post_ok('/topic/new', form => {titlestring => 'bb', textdata => 'bbb'})->status_is(302);

note 'alphabetische sortierung';
$t->post_ok('/options/admin/boardsettings/chronsortorder', form => { optionvalue => 0 })->status_is(302);
$t->get_ok('/forum')->status_is(200)
  ->content_like(qr~<p><a\s+href="/topic/1">aa</a>\.\.\.</p>\s*<p><a\s+href="/topic/2">bb</a>\.\.\.</p>~);

note 'chronologische sortierung';
$t->post_ok('/options/admin/boardsettings/chronsortorder', form => { optionvalue => 1 })->status_is(302);
$t->get_ok('/forum')->status_is(200)
  ->content_like(qr~<p><a\s+href="/topic/2">bb</a>\.\.\.</p>\s*<p><a\s+href="/topic/1">aa</a>\.\.\.</p>~);
