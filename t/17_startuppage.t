use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 330;

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



# Sortierung definieren, sonst krachts
user();
$t->post_ok('/topic/sort/chronological')->status_is(302)->content_is('')->header_is(Location => '/forum');
admin();
$t->post_ok('/topic/sort/chronological')->status_is(302)->content_is('')->header_is(Location => '/forum');



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



# schauen wir mal, ob die Startseite auch korrekt einsortiert wird
admin();
$t->post_ok('/admin/set_starttopic', form => { topicid => 2 })
  ->status_is(302)->content_is('')->header_is(Location => '/admin/form');
$t->get_ok('/')->status_is(302)->content_is('')->header_is(Location => '/topic/2');

user();
$t->get_ok('/')->status_is(302)->content_is('')->header_is(Location => '/topic/2');
# An erster Stelle in den Listen
$t->get_ok('/forum')->status_is(200);
$t->content_unlike(qr~<div class="postbox topiclist">\s*<h2 [^\w="]>\s*<span class="menuentry">\s*<a href="/topic/2"~);
$t->content_like(qr~<div class="topicpopup popup otherspopup">\s*<p class="smallnodisplay"><a href="/topic/[13]">~);



# neue Beiträge zählen (Startseite => 3, anderes Thema => 4, insgesamt => 10)
sub add_post {
    my $tid = shift;
    my $r = rstr();
    $t->post_ok("/topic/$tid/new", form => {textdata => $r})->status_is(302)->content_is('');
    push @{$Topics[$tid - 1]}, $r;
}
add_post(2); add_post(2); add_post(2);
add_post(3); add_post(3); add_post(3); add_post(3);

admin();
$t->get_ok('/forum')->status_is(200);
$t->content_like(qr~<div class="postbox topiclist">\s*<h2 class="newpost">\s*<span class="menuentry">\s*<a href="/topic/3"~);
$t->content_like(qr~<title>\(10\) Ffc Forum</title>~);
$t->content_like(qr~<span class="linktext linkstart">Start \(<span class="mark">4</span>\)</span></a>~);
$t->content_like(qr~
    \s*<div class="topicpopup popup otherspopup">
    \s*<p class="smallnodisplay newpost"><a href="/topic/3">$Topics[2][1]</a>\.\.\. \(<span class="mark">5</span>\)</p>
    \s*<p class="smallnodisplay newpost"><a href="/topic/1">$Topics[0][1]</a>\.\.\. \(<span class="mark">1</span>\)</p>
    \s*</div>
~);

$t->get_ok('/')->status_is(302)->content_is('')->header_is(Location => '/topic/2');
$t->get_ok('/topic/2')->status_is(200);
$t->content_unlike(qr~<div class="postbox topiclist">\s*<h2\s*[\w="]+>\s*<span class="menuentry">\s*<a href="/topic/2"~);
$t->content_unlike(qr~<div class="topicpopup popup otherspopup">\s*<p class="smallnodisplay\s*starttopic"><a href="/topic/2">~);
$t->content_like(qr~<h1>\s*Startseite~);
$t->content_like(qr~<title>\(6\) Ffc Forum</title>~);
$t->content_like(qr~<span class="linktext linkstart active activestart">Start \(<span class="mark">4</span>\)</span></a>~);
$t->content_like(qr~
    \s*<div class="topicpopup popup otherspopup">
    \s*<p class="smallnodisplay newpost"><a href="/topic/3">$Topics[2][1]</a>\.\.\. \(<span class="mark">5</span>\)</p>
    \s*<p class="smallnodisplay newpost"><a href="/topic/1">$Topics[0][1]</a>\.\.\. \(<span class="mark">1</span>\)</p>
    \s*</div>
~);



# Jetzt noch mal schauen, dass "ignorieren" und "ankleben" keinen Einfluss auf die Sortierung haben
admin();
$t->post_ok('/admin/set_starttopic', form => { topicid => '' })
  ->status_is(302)->content_is('')->header_is(Location => '/admin/form');
$t->get_ok('/admin/form')->status_is(200)
  ->content_like(qr~<select\s+name="topicid">\s*<option\s+value="">~xmso);
$t->content_like(qr~<option\s+value="$_->[0]">$_->[1]</option>~xmso)
    for @Topics;
info('Startseitenthema zurückgesetzt');
$t->content_unlike(qr~<span class="linktext linkstart">Start~);
$t->content_like(qr~\s*<p class="smallnodisplay"><a href="/topic/2">$Topics[1][1]</a>\.\.\.</p>~);

user();
$t->get_ok('/')->status_is(200);
$t->content_unlike(qr~<h1>\s*Startseite~);
$t->content_unlike(qr~<span class="linktext linkstart">Start~);
$t->content_like(qr~\s*<p class="smallnodisplay"><a href="/topic/2">$Topics[1][1]</a>\.\.\.</p>~);

# Pin and Ignore
for my $set ( qw~pin ignore~ ) {
    admin();
    $t->get_ok("/topic/2/$set")->status_is(302)->content_is('')->header_is(Location => '/forum');
    $t->get_ok('/forum')->status_is(200);
    $t->content_unlike(qr~<span class="linktext linkstart">Start~);
    if ( $set eq 'ignore' ) {
        $t->content_like(qr~\s*<p class="smallnodisplay ignored"><a href="/topic/2">$Topics[1][1]</a>\.\.\.</p>~);
    }
    else {
        $t->content_like(qr~\s*<p class="smallnodisplay $set"><a href="/topic/2">$Topics[1][1]</a>\.\.\.</p>~);
    }

    $t->post_ok('/admin/set_starttopic', form => { topicid => 2 })
      ->status_is(302)->content_is('')->header_is(Location => '/admin/form');
    $t->get_ok('/')->status_is(302)->content_is('')->header_is(Location => '/topic/2');
    $t->get_ok('/forum')->status_is(200);
    $t->content_like(qr~<span class="linktext linkstart">Start \(<span class="mark">4</span>\)</span></a>~);

    $t->post_ok('/admin/set_starttopic', form => { topicid => '' })
      ->status_is(302)->content_is('')->header_is(Location => '/admin/form');

    $t->get_ok("/topic/2/un$set")->status_is(302)->content_is('')->header_is(Location => '/forum');
    $t->get_ok('/forum')->status_is(200);
    $t->content_unlike(qr~<span class="linktext linkstart">Start~);
    $t->content_like(qr~\s*<p class="smallnodisplay"><a href="/topic/2">$Topics[1][1]</a>\.\.\.</p>~);
}
