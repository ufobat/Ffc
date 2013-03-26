use Mojo::Base -strict;

use Test::Mojo;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Mock::Controller;
use Test::General;

use Test::More tests => 12;

use_ok('Ffc');
my $t = Test::Mojo->new('Ffc');
$t->get_ok('/')->status_is(200)->content_like(qr{Bitte melden Sie sich an});

note('sub switch_act( $app, $controller, $act, $category, $msgsuserid )');
my $c = Mock::Controller->new();
my $session = $c->session();
$session->{blubb} = 'bla';
my $standard = {%$session};

$standard->{act} = $session->{act} = '';
ok(!Ffc::switch_act(), 'invalid call returns false');
is_deeply($session, $standard, 'unaltered session ok');

$session->{act} = '';
$standard->{act} = 'forum';
$standard->{category} = undef;
ok(Ffc::switch_act(undef, $c), 'call without act returns false');
is_deeply($session, $standard, 'altered session ok');

$session->{act} = '';
ok(Ffc::switch_act(undef, $c, 'asdf'), 'call with wrong act returns false');
is_deeply($session, $standard, 'altered session ok');

ok(Ffc::switch_act(undef, $c, 'notes'), 'call ok');
$standard->{act} = 'notes';
is_deeply($session, $standard, 'altered session ok');

