use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
my $t = require Posttest;

use Test::Mojo;
use Test::More tests => 2693;

my $cname = 'forum';

# generate some topics
my @Topics;
push @Topics, map { [Testinit::test_randstring(), Testinit::test_randstring(),$_] } 1 .. 3;
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

# testen, ob das mit dem ignorieren von themen hinhaut
my $newcntsum = 1;
$t->get_ok('/topic/2/ignore')->status_is(302)
  ->header_like(location => qr~\A/~);
$t->get_ok('/')->status_is(200)
  ->content_like(qr~<title>\($newcntsum\)\s+Ffc\s+Forum~)
  ->content_like(qr~activeforum">Themen\s+\(<span\s+class="mark">$newcntsum</span>\)</span>~xms)
  ->content_like(qr~href="/topic/2/unignore"~)
  ->content_like(qr~href="/topic/1/ignore"~);
info('Zum gewählten Thema werden keine neuen Beiträge mehr angezählt.');
check_for_topic_count($t, $Topics[1], 2, 0);
check_for_topic_count($t, $Topics[2], 3, 1);

# und wieder unignorieren
$newcntsum = 2;
$t->get_ok('/topic/2/unignore')->status_is(302)
  ->header_like(location => qr~\A/~);
$t->get_ok('/')->status_is(200)
  ->content_like(qr~<title>\($newcntsum\)\s+Ffc\s+Forum~)
  ->content_like(qr~activeforum">Themen\s+\(<span\s+class="mark">$newcntsum</span>\)</span>~xms)
  ->content_like(qr~href="/topic/2/ignore"~)
  ->content_like(qr~href="/topic/1/ignore"~);
info('Das gewählte Thema wird jetzt nicht mehr ignoriert.');
check_for_topic_count($t, $Topics[1], 2, 1);
check_for_topic_count($t, $Topics[2], 3, 1);

# das anpinnen von themen ausprobieren
$t->get_ok('/topic/2/pin')->status_is(302)
  ->header_like(location => qr~\A/~);
$t->get_ok('/')->status_is(200)
  ->content_like(qr~href="/topic/2/unpin"~)
  ->content_like(qr~href="/topic/1/pin"~);
info('Das gewählte Thema wird immer oben angeheftet.');
# und wieder unanpinnen
$t->get_ok('/topic/2/unpin')->status_is(302)
  ->header_like(location => qr~\A/~);
$t->get_ok('/')->status_is(200)
  ->content_like(qr~href="/topic/2/pin"~)
  ->content_like(qr~href="/topic/1/pin"~);
info('Das gewählte Thema wird jetzt nicht mehr oben angeheftet.');

# checks for correct appearance of side effects
sub check_env {
    my ( $t, $entries, $delents, $delatts, $cnt, $query ) = @_;
    $cnt = @$entries unless $cnt;

    note 'login als urheber';
    login1();
    $t->get_ok('/')->status_is(200)
      ->content_like(qr~<title>\(0\)\s+Ffc\s+Forum~)
      ->content_like(qr~activeforum">Themen</span>~);
    for ( 0 .. $#Topics ) {
        note "topic idx $_ als urheber checken";
        check_for_topic_count($t, $Topics[$_], $_ + 1, 0, $entries, $delents, $cnt, $query);
    }

    note 'login zum lesen';
    login2();
    my $newcnt = grep { !$_->[3] and $_->[5] } @$entries;
    my $newcntsum = $newcnt + 2;
    $t->get_ok('/')->status_is(200)
      ->content_like(qr~<title>\($newcntsum\)\s+Ffc Forum~)
      ->content_like(qr~activeforum">Themen\s+\(<span\s+class="mark">$newcntsum</span>\)</span>~xms);
    for ( 0 .. $#Topics ) {
        note "pruefe mal wieder Topic idx $_";
        check_for_topic_count($t, $Topics[$_], $_ + 1, $_ ? 1 : $newcnt, $entries, $delents, $cnt, $query);
    }

    note 'gelesen markieren';
    $newcntsum = 2;
    my $u1 = users(1);
    $t->get_ok('/topic/1')->status_is(200)
      ->content_like(qr~<title>\($newcntsum\)\s+Ffc\s+Forum~)
      ->content_like(qr~activeforum">Themen\s+\(<span\s+class="mark">$newcntsum</span>\)</span>~xms)
      ->content_like(qr~/pmsgs/2"\s+title="Private\s+Nachricht\s+an\s+den\s+Beitragsautoren\s+schreiben">private\s+Nachricht</a>~xms);
    $entries->[-1]->[5] = 0;

    check_pages(\&login2, '/topic/1');
    $_->[5] = 0 for @$entries;
    $newcntsum = 2;

    note 'jetzt wurde einiges gelesen';
    $t->get_ok('/')->status_is(200)
      ->content_like(qr~<title>\($newcntsum\)\s+Ffc\s+Forum~)
      ->content_like(qr~activeforum">Themen\s+\(<span\s+class="mark">$newcntsum</span>\)</span>~xms);
    note 'topic 1';
    check_for_topic_count($t, $Topics[0], 1, 0, $entries, $delents, $cnt, $query);
    for ( 1 .. $#Topics ) {
        note 'check topic ' . $_;
        check_for_topic_count($t, $Topics[$_], $_ + 1, 1, $entries, $delents, $cnt, $query);
    }

}

sub check_for_topic_count {
    my ( $t, $top, $i, $new, $entries, $delents, $cnt, $query ) = @_;
    if ( $new ) {
        $t->content_like(qr~$top->[0]\s*</a>\s*\.\.\.\s*\(<span\s+class="mark">$new</span>\)\s*</p>~xms)
          ->content_like(qr~href="/topic/$i">$top->[0]</a>~)
          ->content_like(qr~
                <span\s+class="addinfos">\s*Neu:\s+<span\s+class="mark">\[$new\]</span>,
                \s*\w+,\s*(?:[.\d:]+|jetzt)\s*<br\s+/>
                \s+<span\sclass="smallfont">
                \s+<a\shref="/topic/$i/seen"\s+title="Thema\sals\sgelesen\smarkieren">gelesen</a>
                \s+/
                \s+<a\s+href="/topic/$i/(?:un)?(?:ignore|pin|newsmail)"~xms);
    }
    else {
        $t->content_like(qr~$top->[0]\s*</a>\s*\.\.\.\s*</p>~xms)
          ->content_like(qr~href="/topic/$i">$top->[0]</a>~)
          ->content_like(qr~
                <span\s+class="addinfos">
                \s*\w+,\s*(?:[.\d:]+|jetzt)\s*<br\s+/>
                \s+<span\sclass="smallfont">
                \s+<a\s+href="/topic/$i/(?:un)?(?:ignore|pin|newsmail)"~xms);
    }
    unless ( $t->success ) {
        diag Dumper $top, $i, $new, $entries, $delents;
    }
}

