use strict;
use warnings;
use 5.010;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;

use Test::Mojo;

use Test::More tests => 18;

srand;

{
    use Mojolicious::Lite;

    my $config = {};
    plugin 'Ffc::Plugin::Formats';
    helper configdata => sub { $config };
    helper prepare    => sub {
        my $c = shift;
        $c->session->{user} = $c->param('user') // '';
        $c->configdata->{urlshorten} = $c->param('urlshorten') // 30;
    };
    any '/pre_format' => sub {
        my $c = shift;
        $c->prepare;
        $c->render(text => $c->pre_format($c->param('text')));
    };
}
my $tl = Test::Mojo->new;

my ( $tf, $path, $admin, $apass, $dbh ) = Testinit::start_test();

Testinit::test_login($tf, $admin, $apass);

my $text = "asdfasdf <b>jkasdhfkljashd</b>asdfasdf\nasdfas <i>asdf</i>\nasdfasdf http://localhost.de asdfsad";
my $result = '<p>asdfasdf <b>jkasdhfkljashd</b>asdfasdf</p>
<p>asdfas <i>asdf</i></p>
<p>asdfasdf <a href="http://localhost.de" title="Externe Webseite: http://localhost.de" target="_blank">http://localhost.de</a> asdfsad</p>';

my $tf_ret = $tl->post_ok('/pre_format', form => {text => $text} )
                ->status_is(200)->content_isnt('')
                ->tx->res->body;

my $tl_ret = $tf->post_ok('/textpreview', json => $text )
                ->status_is(200)->content_isnt('""')
                ->json_unlike('' => qr~\A\z~)->tx->res->json;

ok $tf_ret eq $result, '"textpreview" liefert das erwartete Ergebnis';
ok $tf_ret eq $tl_ret, '"textpreview" liefert das gleiche Ergebnis wie die Test-Formatierung';

