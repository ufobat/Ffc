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
  # [ Top  => [ Articles, ... ], seen? ], #
    [ asdf => [qw(qwe rtz uio)], 0 ],
    [ fgjd => [qw(yxc vbn jkl)], 0 ],
    [ oiuz => [qw(mnb fgd ewq)], 0 ],
);

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
        \s+$user1,\s+$timeqr,
        \s+<a\shref="/forum/printpreview/$id\#goto_unread_$id"
        \s+title="Thema\sin\sder\sDruckvorschau\sanzeigen">Leseansicht</a>,
        \s+<a\shref="/topic/$id/seen"
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
        \s+<a\shref="/forum/printpreview/$id\#goto_unread_$id"
        \s+title="Thema\sin\sder\sDruckvorschau\sanzeigen">Leseansicht</a>,
        \s+<a\shref="/topic/$id/pin"
    ~xms);
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
    $t->post_ok('/topic/new', form => {titlestring => $top, textdata => $arts->[0]})
      ->status_is(302)->header_like( Location => qr{\A/topic/$id}xms );
    $t->get_ok('/forum')->status_is(200)
      ->content_like(qr~<a href="/topic/$id">$top</a>~);
    for my $art ( @{$arts}[1..$#$arts] ) {
        $t->post_ok("/topic/$id/new", form => {textdata => $art})
          ->status_is(302)->header_like(Location => qr~/topic/$id~);
    }
    my $acnt = @$arts;
    note("Thema Nr. $id mit $acnt Beitraegen wurde erstellt");
}

###############################################################################
note q~Mit anderem Benutzer pruefen, dass alle Themen neue ungelesene Beitraege haben~;
###############################################################################

login2();
$t->get_ok('/forum')->status_is(200);
check_unseen($_) for 0 .. $#Topics;

###############################################################################
note q~Themen der Reihe nach als gelesen markieren und pruefen~;
###############################################################################

login2();
for my $i ( 0 .. $#Topics ) {
    my $id   = $i + 1;
    note("Thema Nr. $id als gelesen markieren und pruefen");
    my $top  = $Topics[$i][0];
    my $arts = $Topics[$i][1];
    $Topics[$i][2] = 1;
    $t->get_ok("/topic/$id/seen")
      ->status_is(302)->header_like( Location => qr{\A/forum\z}xms );
    $t->get_ok('/forum')->status_is(200)
      ->content_like(qr~<a href="/topic/$id">$top</a>~);
    for my $i ( 0 .. $#Topics ) {
        if ( $Topics[$i][2] ) { check_seen(   $i ) }
        else                  { check_unseen( $i ) }
    }
    note("Thema Nr. $id enthaelt jetzt keine als neu markierten Beitraege mehr");
}

