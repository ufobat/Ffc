use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
my $t = require Posttest;

use Test::Mojo;
use Test::More tests => 739;

my $cname = 'forum';

# generate some topics
my @Topics;
push @Topics, map { [Testinit::test_randstring(), Testinit::test_randstring()] } 1 .. 3;
login1();
for my $i ( 0 .. $#Topics ) {
    $t->post_ok('/topic/new', form => {
        titlestring => $Topics[$i][0], 
        textdata    => $Topics[$i][1]
    })->status_is(302);
    check_topic($t, $i);
    info('Ein neuer Beitrag wurde erstellt');
}
# insert the first entry of the first topic into the entries array
add_entry_testarray($Topics[0][1], undef, undef, [], 1);
lastid(3);

# check a topic from topics array for precense
sub check_topic {
    my ( $t, $i ) = @_;
    $t->get_ok('/topic/'.($i + 1))
      ->status_is(200)
      ->content_like(qr~$Topics[$i][0]~)
      ->content_like(qr~$Topics[$i][1]~);
}

# runs a standardized test suite
#   run_tests( $UserFrom, $UserTo, $Urlpref, $Check_env, $do_attachements, $do_edit, $do_delete );
# using $user1 (id=2) writing to $user2 (id=3), but not to $admin (id=1)
run_tests(1, undef, "/topic/1", \&check_env, 1, 1, 1);

# checks for correct appearance of side effects
sub check_env {
    my ( $t, $entries, $delents, $delatts, $cnt ) = @_;
    $cnt = @$entries unless $cnt;

    # login als urheber
    login1();
    $t->get_ok('/')->status_is(200)
      ->content_like(qr~<title>Ffc Forum \(0/0\)</title>~)
      ->content_like(qr~activeforum">Forum</span></a>~);
    check_for_topic_count($t, $Topics[$_], $_ + 1, 0) for 0 .. $#Topics;

    # login zum lesen
    login2();
    my $newcnt = grep { !$_->[3] and $_->[5] } @$entries;
    my $newcntsum = $newcnt + 2;
    $t->get_ok('/')->status_is(200)
      ->content_like(qr~<title>Ffc Forum \($newcntsum/0\)</title>~)
      ->content_like(qr~activeforum">Forum\s+\(<span\s+class="mark">$newcntsum</span>\)</span></a>~xms);
    #use Data::Dumper; diag Dumper $newcnt, $newcntsum, $entries;
    check_for_topic_count($t, $Topics[$_], $_ + 1, $_ ? 1 : $newcnt) for 0 .. $#Topics;

    # gelesen markieren
    $t->get_ok('/topic/1')->status_is(200)
      ->content_like(qr~<title>Ffc Forum \($newcntsum/0\)</title>~)
      ->content_like(qr~activeforum">Forum\s+\(<span\s+class="mark">$newcntsum</span>\)</span></a>~xms);
    $entries->[-1]->[5] = 0;

    check_pages(\&login2, '/topic/1');
    $_->[5] = 0 for @$entries;
    $newcntsum = 2;

    # jetzt wurde einiges gelesen
    $t->get_ok('/')->status_is(200)
      ->content_like(qr~<title>Ffc Forum \($newcntsum/0\)</title>~)
      ->content_like(qr~activeforum">Forum\s+\(<span\s+class="mark">$newcntsum</span>\)</span></a>~xms);
    check_for_topic_count($t, $Topics[0], 1, 0);
    check_for_topic_count($t, $Topics[$_], $_ + 1, 1) for 1 .. $#Topics;

    # testen, ob das mit dem ignorieren von themen hinhaut
    diag 'test ignore topics';
}

sub check_for_topic_count {
    my ( $t, $top, $i, $new ) = @_;
    if ( $new ) {
        $t->content_like(qr~$top->[0]</a>\s*\(<span\s+class="mark">$new</span>\)\s*</p>~xms)
          ->content_like(qr~$top->[0]</a>\s*
                <span\s+class="smallfont">\(\s*Neu:\s+<span\s+class="mark">$new</span>,\s+<a\s+href="/topic/$i/ignore"~xms);
    }
    else {
        $t->content_like(qr~$top->[0]</a>\s*</p>~xms)
          ->content_like(qr~$top->[0]</a>\s*
                <span\s+class="smallfont">\(\s*<a\s+href="/topic/$i/ignore"~xms);
    }
}

