use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 386;

###############################################################################
note q~Testsystem vorbereiten~;
###############################################################################
my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();

my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my ( $user2, $pass2 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1, $user2, $pass2 );
sub login1 { Testinit::test_login(   $t, $user1, $pass1 ) }
sub login2 { Testinit::test_login(   $t, $user2, $pass2 ) }
my $timeqr = qr~(?:jetzt|(\d?\d\.\d?\d\.\d\d\d\d, )?\d?\d:\d\d)~;

##################################################
note('Testdaten zusammenstellen');
my @Topics = (
  # [ Top  => [ [Article => 2old, id], ... ], lastseen, ignore ], #
    [ asdf => [qw(qwe rtz uio)], -1, 1 ],
    [ fgjd => [qw(yxc vbn jkl)], -1, 0 ],
    [ oiuz => [qw(mnb fgd ewq)], -1, 0 ],
);
my $articleid = 1;
for my $top ( @Topics ) {
    $top->[1] = [ map {[$_ => 0, $articleid++]} @{$top->[1]} ]
}

###############################################################################
note q~Vorbereiten der Pruefroutinen~;
###############################################################################
sub check_topiclist_unseen {
    my $i = shift;
    my $id   = $i + 1;
    my $top  = $Topics[$i][0];
    my $arts = $Topics[$i][1];
    my $acnt = @$arts;
    note("Thema Nr. $id sollte $acnt ungelesene Beitraege haben");
    $t->content_like(qr~$top~);
    $t->content_like(qr~
        <span\sclass="smallfont">\(
        \s+Neu:\s<span\sclass="mark">$acnt</span>,
        \s+$user1,\s+$timeqr,
        \s+<span\sclass="menuentry">
        \s+<span\sclass="othersmenulinktext">Optionen</span>
        \s+<div\sclass="otherspopup\spopup\stopiclistpopup">
        \s+<a\shref="/forum/printpreview/$id\#goto_unread_$id"
        \s+title="Thema\sin\sder\sDruckvorschau\sanzeigen">Leseansicht</a>,
        \s+<a\shref="/topic/$id/seen"
        \s+title="Thema\sals\sgelesen\smarkieren">gelesen</a>,
        \s+<a\shref="/topic/$id/pin"
    ~xms);
}

sub add_article {
    my ( $id, $art ) = @_;
    $t->post_ok("/topic/$id/new", form => {textdata => $art})
      ->status_is(302)->header_like(Location => qr~/topic/$id~)->content_is('');
}

sub check_topic_in_ppv {
    my $topicid = shift;
    if ( $topicid ) {
        $t->get_ok("/forum/printpreview/$topicid");
        $t->content_unlike(qr'Inhaltsverzeichnis');
    }
    else {
        $t->get_ok('/forum/printpreview');
        $t->content_like(qr'Inhaltsverzeichnis');
    }
    $t->status_is(200);
    for my $i ( 0 .. $#Topics ) {
        my $id = $i + 1;
        my ( $top, $arts, $lastseen, $ignore ) = @{$Topics[$i]};
        my $acnt = @$arts;
        if ( $ignore ) {
            note("Thema Nr. $id wird ignoriert, nichts davon soll angezeigt werden");
            $t->content_unlike(qr~$top</a></h1>~);
            $t->content_unlike(qr~$_->[0]~) for @$arts;
            next;
        }
        my $ungelesene = 0;
        note("Thema Nr. $id mit $acnt Beitraegen pruefen");
        for my $art ( @$arts ) {
            my $artid = $art->[2];
            if ( $art->[1] ) {
                note("Beitrag Nr. $artid ist zu alt und darf nicht zu sehen sein");
                $t->content_unlike(qr~$art->[0]~);
            }
            elsif ( $lastseen >= $artid ) {
                note("Beitrag Nr. $artid wurde bereits gelesen");
                $t->content_like(qr~
<div class="postbox">
    <h2 class="title">
        <img class="avatar" src="/avatar/2" alt="" />
        <span class="username">$user1</span>,
        $timeqr
        <span class="functionlinks">\(
            <a href="/pmsgs/2" title="Private Nachricht an den Beitragsautoren schreiben">Nachricht</a>,
            <a href="/topic/$id/display/$artid" target="_blank" title="Direkter Link zum Beitrag">Link</a>,
            Bewertung:
            <a href="/topic/$id/score/increase/$artid" title="Bewertung erhöhen">\+</a>
            <span title="Bewertungswert des Beitrages" class="score">0</span>
            <a href="/topic/$id/score/decrease/$artid" title="Bewertung herabsetzen">\-</a>
        \)</span>
    </h2>
<p>$art->[0]</p>
</div>~);
            }
            else {
                note("Beitrag Nr. $artid ist noch ungelesen");
                $ungelesene = 1;
                $t->content_like(qr~
<div class="postbox newpost">
    <h2 class="title">
        <img class="avatar" src="/avatar/2" alt="" />
        <span class="username">$user1</span>,
        $timeqr
        <span class="functionlinks">\(
            <a href="/pmsgs/2" title="Private Nachricht an den Beitragsautoren schreiben">Nachricht</a>,
            <a href="/topic/$id/display/$artid" target="_blank" title="Direkter Link zum Beitrag">Link</a>,
            Bewertung:
            <a href="/topic/$id/score/increase/$artid" title="Bewertung erhöhen">\+</a>
            <span title="Bewertungswert des Beitrages" class="score">0</span>
            <a href="/topic/$id/score/decrease/$artid" title="Bewertung herabsetzen">\-</a>
        \)</span>
    </h2>
<p>$art->[0]</p>
</div>~);
            }
        }
        if ( $topicid ) {
            note qq~Inhaltsverzeichnis darf nicht da sein und auch Topic Nr. $id pruefen~;
            $t->content_unlike(qr~<li><a href="#goto_start_$id">$top</a>~);
        }
        else {
            note qq~Inhaltsverzeichnis auf Topic Nr. $id pruefen~;
            if ( $ungelesene ) {
                $t->content_unlike(qr~<li><a href="#goto_start_$id">$top</a></li>~);
            }
            else {
                $t->content_unlike(qr~<li><a href="#goto_start_$id">$top</a> \(<span class="mark">ungelesene Beiträge</span>\)</li>~);
            }
        }
    }
}

###############################################################################

login1();

###############################################################################
note q~Schauen, dass das Richtige erscheint, wenn keine Beitraege da sind~;
###############################################################################

$t->get_ok('/forum/printpreview')->status_is(200)
  ->content_like(qr~Keine Beiträge im anzuzeigenden Zeitraum~);

###############################################################################
note q~Vorbereiten der Testreihe~;
###############################################################################

for my $i ( 0 .. $#Topics ) {
    my $id   = $i + 1;
    note("Thema Nr. $id mit Beitraegen anlegen");
    my $top  = $Topics[$i][0];
    my $arts = $Topics[$i][1];
    $t->post_ok('/topic/new', form => {titlestring => $top, textdata => $arts->[0]->[0]})
      ->status_is(302)->header_like( Location => qr{\A/topic/$id}xms )->content_is('');
    $t->get_ok('/forum')->status_is(200)
      ->content_like(qr~<a href="/topic/$id">$top</a>~);
    for my $art ( @{$arts}[1..$#$arts] ) {
        add_article($id, $art->[0]);
    }
    my $acnt = @$arts;
    note("Thema Nr. $id mit $acnt Beitraegen wurde erstellt");
}

###############################################################################

login2();

###############################################################################
note q~Mit anderem Benutzer pruefen, dass alle Themen neue ungelesene Beitraege haben und ignorieren setzen~;
###############################################################################

$t->get_ok('/forum')->status_is(200);
for my $i ( 0 .. $#Topics ) {
    check_topiclist_unseen($i);
    my $id = $i + 1;
    if ( $Topics[$i][3] ) {
        note("Thema Nr. $id ignorieren");
        $t->get_ok("/topic/$id/ignore")->status_is(302);
        $t->get_ok('/forum')->status_is(200);
    }
}

###############################################################################
note q~Druckvorschauseite anzeigen und Ungelesenmarkierung pruefen~;
###############################################################################

check_topic_in_ppv();

###############################################################################

login1();

###############################################################################
note q~Neue Beitraege erstellen~;
###############################################################################

for my $i ( 0 .. $#Topics ) {
    my $id = $i + 1;
    note("Thema Nr. $id mit Beitraegen anlegen");
    my $top      = $Topics[$i][0];
    my $arts     = $Topics[$i][1];
    my @newarts  = ( "asxdf_n$id", "qwxer_n$id", "yxxcv_n$id" );
    for ( @newarts ) {
        add_article($id, $_);
    }
    push @$arts, map {[$_ => 0, $articleid++]} @newarts;
    my $acnt = @newarts;
    note("Zum Thema Nr. $id wurden $acnt neue Beitraege erstellt");
}

###############################################################################

login2();

###############################################################################
note q~Druckvorschauseite mit neuen Beitraegen anzeigen und Gelesenmarkierung pruefen~;
###############################################################################

check_topic_in_ppv();

###############################################################################
note q~Druckvorschauperiode ist standardmaeßig auf 7 Tage gesetzt~;
###############################################################################

$t->content_like(qr~14 Tage</a>,~);
$t->content_like(qr~7 Tage</span>,~);
$t->content_like(qr~31 Tage</a>,~);

###############################################################################
note q~Einige Beitraege kuenstlich auf 8 Tage altern~;
###############################################################################

my @oldies = ( @{$Topics[1][1]}[1,2], @{$Topics[2][1]}[3,4] );
for my $art ( @oldies ) {
    $art->[1] = 1;
    $dbh->do(qq~UPDATE "posts" SET "posted"=DATETIME("posted", '-8 days') WHERE "id"=?~, 
        undef, $art->[2]);
}

###############################################################################
note q~Druckvorschauseite ohne ueberalterte Beitraege anzeigen~;
###############################################################################

check_topic_in_ppv();

###############################################################################
note q~Druckvorschauseiten-Periode auf 14 Tage verlaengern~;
###############################################################################

$t->get_ok('/forum/set_ppv_period/14')->status_is(302)
  ->header_is(Location => '/forum/printpreview');
$_->[1] = 0 for @oldies;

###############################################################################
note q~Druckvorschauseite jetzt wieder mit ueberalterte Beitraege anzeigen bei der laengeren Periode~;
###############################################################################

check_topic_in_ppv();

###############################################################################
note q~Druckvorschauperiode ist auch wirklich auf 14 Tage gesetzt~;
###############################################################################

$t->content_like(qr~7 Tage</a>,~);
$t->content_like(qr~14 Tage</span>,~);
$t->content_like(qr~31 Tage</a>,~);

###############################################################################
note q~Einige Beitraege kuenstlich auf 16 Tage altern~;
###############################################################################

for my $art ( @oldies ) {
    $art->[1] = 1;
    $dbh->do(qq~UPDATE "posts" SET "posted"=DATETIME("posted", '-8 days') WHERE "id"=?~, 
        undef, $art->[2]);
}

###############################################################################
note q~Druckvorschauseite ohne die neu ueberalterten Beitraege anzeigen~;
###############################################################################

check_topic_in_ppv();

###############################################################################
note q~Druckvorschauseiten-Periode auf 31 Tage verlaengern, damit mit allen Themen getestet werden kan~;
###############################################################################

$t->get_ok('/forum/set_ppv_period/31')->status_is(302)
  ->header_is(Location => '/forum/printpreview');
$_->[1] = 0 for @oldies;

###############################################################################
note q~Alle wieder da~;
###############################################################################

check_topic_in_ppv();
$t->content_like(qr~7 Tage</a>,~);
$t->content_like(qr~14 Tage</a>,~);
$t->content_like(qr~31 Tage</span>,~);

###############################################################################
note q~Nur ein einzelnes Thema anzeigen~;
###############################################################################

$Topics[2][3] = 1;
check_topic_in_ppv(2);
$Topics[2][3] = 0;

###############################################################################
note q~Ein Thema als gelesen markieren~;
###############################################################################

$t->get_ok('/topic/2/printpreview/seen')->status_is(302)
  ->header_is(Location => '/forum/printpreview');
# Markierung in den Testdaten ändern
$Topics[1][2] = $Topics[1][1][-1][2];

###############################################################################
note q~Lesemarkierung pruefen~;
###############################################################################

check_topic_in_ppv();

###############################################################################
note q~Ein Thema ignorieren~;
###############################################################################

$t->get_ok('/topic/2/printpreview/ignore')->status_is(302)
  ->header_is(Location => '/forum/printpreview');
# Markierung in den Testdaten ändern
$Topics[1][3] = 1;

###############################################################################
note q~Ignoration pruefen~;
###############################################################################

check_topic_in_ppv();

