use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 274;

use Data::Dumper;

###############################################################################
note q~Testsystem vorbereiten~;
###############################################################################
my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();

my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1 );
sub login1 { Testinit::test_login(   $t, $user1, $pass1 ) }
my $timeqr = qr~(?:jetzt|(\d?\d\.\d?\d\.\d\d\d\d, )?\d?\d:\d\d)~;

##################################################
note('Testdaten zusammenstellen');
my @Topics = (
  # [ Top  => [ Articles, exist, $id], lastid ], #
    [ asdf => [map {[$_, 1, 0]} qw(qwe rtz uio oiu tre)], -1 ],
    [ fgjd => [map {[$_, 1, 0]} qw(yxc vbn jkl cft hgf)], -1 ],
);

login1();
for my $i ( 0 .. $#Topics ) {
    my $id   = $i + 1;
    note("Thema Nr. $id mit Beitraegen anlegen");
    my $top  = $Topics[$i][0];
    my $arts = $Topics[$i][1];
    $t->post_ok('/topic/new', form => {titlestring => $top, textdata => $arts->[0]->[0]})
      ->status_is(302)->header_like( Location => qr{\A/topic/$id}xms )->content_is('');
    set_lastid($arts->[0]);
    $t->get_ok('/forum')->status_is(200)
      ->content_like(qr~<a href="/topic/$id">$top</a>~);
    $t->get_ok("/topic/$id")->status_is(200)
      ->content_like(qr~<p>$arts->[0]->[0]</p>~);
    note(qq~Fuege weitere Artikel zum Thema Nr. $id hinzu~);
    for my $art ( @{$arts}[1 .. 4] ) {
        $t->post_ok("/topic/$id/new", form => {textdata => $art->[0]})
          ->status_is(302)->header_like(Location => qr~/topic/$id~)->content_is('');
        $t->get_ok("/topic/$id")->status_is(200)
          ->content_like(qr~<p>$art->[0]</p>~);
        my $artid = set_lastid($art);
        note(qq~Artikel Nr. $artid wurde zu Thema Nr. $id hinzugefuegt~);
    }
    my $acnt = @$arts;
    $Topics[$i][2] = get_lastid();
    my $lasttopicid = select_lastid_for_topic($id);
    ok $lasttopicid == $Topics[$i][2], 
        qq~Aktuellste Artikel-ID $lasttopicid passt zur berechneten $Topics[$i][2] bei Thema Nr. $id~;
    note("Thema Nr. $id mit $acnt Beitraegen wurde erstellt");
}
check_topics();

##################################################
note('Helferroutinen');

{
    my $lastaid = 0;
    sub set_lastid { 
        $_[0]->[2] = ++$lastaid;
        note(qq~Artikel-ID $lastaid wurde ausgegeben~);
        return $lastaid;
    }
    sub get_lastid { $lastaid }
}

sub check_topics {
    note(qq~Themen werden geprueft~);
    for my $i ( 0 .. $#Topics ) {
        my $id   = $i + 1;
        note(qq~Pruefe das Thema Nr. $id~);
        my $arts = $Topics[$i][1];
        note("Beitraege von Thema Nr. $id pruefen");
        $t->get_ok("/topic/$id")->status_is(200)
          ->content_like(qr~<h1>\s*$Topics[$i][0]~xmsi);
        for my $art ( @$arts ) {
            if ( $art->[1] ) { $t->content_like  (qr~<p>$art->[0]</p>~) }
            else             { $t->content_unlike(qr~<p>$art->[0]</p>~) }
        }
        my $lasttopicid = select_lastid_for_topic($id);
        ok $lasttopicid == $Topics[$i][2], qq~Aktuellste Topicid passt bei Thema Nr. $id~;
        note(qq~Thema Nr. $id wurde ueberprueft~);
    }
}

sub select_lastid_for_topic {
    my $id = shift;
    my $lasttopicid = $dbh->selectall_arrayref(
        'SELECT MAX("id") FROM "posts" WHERE "topicid"=?',
        undef, $id);
    note(qq~Neu errechnete aktuellste Artikel-ID fuer Thema Nr. $id ist $lasttopicid->[0]->[0]~);
    #$lasttopicid = $dbh->selectall_arrayref( 'SELECT "id", "lastid" FROM "topics"' );
    #note(Dumper $lasttopicid);
    #$lasttopicid = $dbh->selectall_arrayref( 'SELECT "id", "topicid" FROM "posts" ORDER BY "id"' );
    #note(Dumper $lasttopicid);
    $lasttopicid = $dbh->selectall_arrayref(
        'SELECT "lastid" FROM "topics" WHERE "id"=?',
        undef, $id);
    return $lasttopicid->[0]->[0];
}

sub delete_article {
    my ( $topic_i, $article_i ) = @_;
    my $topic_id = $topic_i + 1;
    my $article = $Topics[$topic_i][1][$article_i];
    my $article_id = $article->[2];
    my $lasttopicid_b = select_lastid_for_topic($topic_id);
    note(qq~Aktuellste Artikel-ID fuer Thema Nr. $topic_id ist laut Datenbank im Moment $lasttopicid_b~);
    note(qq~Artikel Nr. $article_id vom Thema Nr. $topic_id wird geloescht~);
    $t->get_ok("/topic/$topic_id/delete/$article_id")->status_is(200)
      ->content_like(qr~<p>$article->[0]</p>~)
      ->content_like(qr~action="/topic/$topic_id/delete/$article_id"~);
    my $lasttopicid_m = select_lastid_for_topic($topic_id);
    note(qq~Aktuellste Artikel-ID fuer Thema Nr. $topic_id ist laut Datenbank zwischenzeitlich $lasttopicid_m~);
    $t->post_ok("/topic/$topic_id/delete/$article_id")->status_is(302)
      ->header_is( Location => "/topic/$topic_id" );
    $article->[1] = 0;
    note(qq~Artikel Nr. $article_id vom Thema Nr. $topic_id wurde geloescht~);
    my $lasttopicid_a = select_lastid_for_topic($topic_id);
    note(qq~Aktuellste Artikel-ID fuer Thema Nr. $topic_id ist laut Datenbank jetzt $lasttopicid_a~);
    check_topics();
}

##################################################
note('Loeschtests durchlaufen');

note('Loeschen irgendwo zwischendrin aendert die Last-IDs nicht');
delete_article(0,2);
delete_article(1,3);

note('Loeschen am Ende aendert die Last-IDs');
$Topics[0][2] = $Topics[0][1][3][2];
delete_article(0,4);
$Topics[1][2] = $Topics[1][1][2][2];
delete_article(1,4);
$Topics[0][2] = $Topics[0][1][1][2];
delete_article(0,3);
delete_article(1,1);

