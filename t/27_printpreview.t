use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 133;

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
  # [ Top  => [ [Article => 2old], ... ], seen?, lastseen, ignore ], #
    [ asdf => [qw(qwe rtz uio)], 0, -1, 1 ],
    [ fgjd => [qw(yxc vbn jkl)], 0, -1, 0 ],
    [ oiuz => [qw(mnb fgd ewq)], 0, -1, 0 ],
);
for my $top ( @Topics ) {
    $top->[1] = [ map {[$_ => 0]} @{$top->[1]} ]
}

###############################################################################
note q~Vorbereiten der Pruefroutinen~;
###############################################################################
sub check_unseen {
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
        \s+$user1,\s+$timeqr,\s+<a\shref="/topic/$id/seen"
        \s+title="Thema\sals\sgelesen\smarkieren">gelesen</a>,
        \s+<a\shref="/topic/$id/pin"
    ~xms);
}

sub check_seen {
    my $i = shift;
    my $id   = $i + 1;
    my $top  = $Topics[$i][0];
    my $arts = $Topics[$i][1];
    my $acnt = @$arts;
    note("Thema Nr. $id sollte als gelesene markiert sein");
    $t->content_like(qr~$top~);
    $t->content_like(qr~
        <span\sclass="smallfont">\(
        \s+$user1,\s+$timeqr,
        \s+<a\shref="/topic/$id/pin"
    ~xms);
}

sub add_article {
    my ( $id, $art ) = @_;
    $t->post_ok("/topic/$id/new", form => {textdata => $art})
      ->status_is(302)->header_like(Location => qr~/topic/$id~)->content_is('');
}

sub check_topic_in_ppv {
    my $start = shift // 0;
    my $end   = shift // $#Topics;
}


###############################################################################
note q~Vorbereiten der Testreihe~;
###############################################################################

login1();
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
note q~Mit anderem Benutzer pruefen, dass alle Themen neue ungelesene Beitraege haben und ignorieren setzen~;
###############################################################################

login2();
$t->get_ok('/forum')->status_is(200);
for my $i ( 0 .. $#Topics ) {
    check_unseen($i);
    my $id = $i + 1;
    if ( $Topics[$i][4] ) {
        note("Thema Nr. $id ignorieren");
        $t->get_ok("/topic/$id/ignore")->status_is(302);
        $t->get_ok('/forum')->status_is(200);
    }
}

###############################################################################
note q~Druckvorschauseite anzeigen und Ungelesenmarkierung pruefen~;
###############################################################################

login2();
$t->get_ok('/forum/printpreview')->status_is(200);

exit;
###############################################################################
note q~Neue Beitraege erstellen~;
###############################################################################

login1();
for my $i ( 0 .. $#Topics ) {
    my $id = $i + 1;
    note("Thema Nr. $id mit Beitraegen anlegen");
    my $top      = $Topics[$i][0];
    my $arts     = $Topics[$i][1];
    my $lastseen = $Topics[$i][3];
    my @newarts  = ( "asdf_n$id", "qwer_n$id", "yxcv_n$id" );
    for ( @newarts ) {
        add_article($id, $_);
    }
    push @$arts, map {[$_ => 0]} @newarts;
    my $acnt = @newarts;
    note("Zum Thema Nr. $id wurden $acnt neue Beitraege erstellt");
}

###############################################################################
note q~Druckvorschauseite mit neuen Beitraegen anzeigen und Gelesenmarkierung pruefen~;
###############################################################################

###############################################################################
note q~Einige Beitraege kuenstlich auf 8 Tage altern~;
###############################################################################

###############################################################################
note q~Druckvorschauseite ohne ueberalterte Beitraege anzeigen~;
###############################################################################

###############################################################################
note q~Druckvorschauseiten-Periode auf 14 Tage verlaengern~;
###############################################################################

###############################################################################
note q~Druckvorschauseite jetzt wieder mit den gealterten Beitraegen anzeigen~;
###############################################################################
#
