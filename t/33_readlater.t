use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use utf8;

use Carp;
use Data::Dumper;
use Test::Mojo;
use Test::More tests => 607;

###############################################################################
note q~Testsystem vorbereiten~;
###############################################################################
my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user1, $pass1, $user2, $pass2 ) = ( map {; Testinit::test_randstring() } 1 .. 4 );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1, $user2, $pass2 );
sub login_user1 { Testinit::test_login( $t, $user1, $pass1 ) }
sub login_user2 { Testinit::test_login( $t, $user2, $pass2 ) }
sub info    { Testinit::test_info(    $t, @_ ) }
sub error   { Testinit::test_error(   $t, @_ ) }
sub warning { Testinit::test_warning( $t, @_ ) }
my $timeqr = qr~(?:jetzt|(\d?\d\.\d?\d\.\d\d\d\d, )?\d?\d:\d\d)~;

###############################################################################
note q~Beitraege erstellen~;
###############################################################################

login_user1(); # User1 erstellt die Beiträge, User2 testet das Markieren

#     0   =>             1,           2,        3
# ([ Zufälliger Text => Beitrags-Id, Topic-Id, SpäterLesen-Flag ])
my @data = ( 
    map( {;[Testinit::test_randstring() => $_, 1, 0]} 1 .. 3 ), 
    map( {;[Testinit::test_randstring() => $_, 2, 0]} 4 .. 6 ), 
);

# Themenlistenzuordnung
my @topics = ([@data[0,1,2]],[@data[3,4,5]]);

# Beiträge anlegen
for my $tix ( 0 .. $#topics ) {
    my $tid = $tix + 1;
    $t->post_ok('/topic/new', 
        form => {
            titlestring => "Testtopic $tid",
            textdata => $topics[$tix][0][0],
        })->status_is(302)->content_is('');
    note qq~Thema $tid mit Beitrag $topics[$tix][0][1] wurde angelegt~;
    for my $d ( @{$topics[$tix]}[1,2] ) {
        $t->post_ok("/topic/$d->[2]/new", 
            form => {
                textdata => $d->[0],
            })->status_is(302)->content_is('');
        note qq~Beitrag $d->[1] wurde zu Thema $d->[2] hinzu gefuegt~;
    }
}



###############################################################################
note q~Pruefungen in Subroutinen giessen~;
###############################################################################
my $rlcnt = 0; # Anzahl wieviele in der Readlater-Liste sind

sub check_posts {
    my ( $empty ) = @_; # for user without anything on readlater list
    $t->get_ok('/forum')->status_is(200);
    if ( $empty or not $rlcnt ) {
        $t->content_unlike(qr~href="/forum/readlater/list"~)
          ->content_unlike(qr~später lesen: \d+</a>~);
    }
    else {
        $t->content_like(qr~href="/forum/readlater/list"~)
          ->content_like(qr~später lesen: $rlcnt</a>~);
    }
    for my $tix ( 0 .. $#topics ) {
        my $tid = $tix + 1;
        $t->get_ok("/topic/$tid")->status_is(200);
        for my $p ( @{$topics[$tix]} ) {
            $t->content_like(qr~$p->[0]~);
            unless ( $empty ) {
                unless ( $p->[3] ) {
                    $t->content_like(qr~später lesen</a>~)
                      ->content_like(qr~href="/forum/readlater/$p->[2]/mark/$p->[1]"~);
                }
                else {
                    $t->content_like(qr~für später vorgemerkt</a>~);
                }
            }
        }
    }
}

sub check_readlaterlist {
    my ( $empty ) = @_; # for user without anything on readlater list
    $t->get_ok('/forum/readlater/list')->status_is(200);
    for my $p ( @data ) {
        if ( $p->[3] and not $empty ) {
            $t->content_like(qr~$p->[0]~)
              ->content_like(qr~Vormerkung entfernen</a>~)
              ->content_like(qr~href="/forum/readlater/unmark/$p->[1]"~);
        }
        else {
            $t->content_unlike(qr~$p->[0]~)
              ->content_unlike(qr~href="/forum/readlater/unmark/$p->[1]"~);
        }
    }
}

sub mark_readlater {
    my ( $p ) = @_;
    $t->get_ok("/forum/readlater/$p->[2]/mark/$p->[1]")->status_is(302)
      ->content_is('')->header_is(Location => "/topic/$p->[2]");
    $t->get_ok("/topic/$p->[2]")->status_is(200);
    info($p->[3] ? 'Vormerkung besteht bereits' : 'Beitrag wurde vorgemerkt');
    $rlcnt = $rlcnt + 1 if not $p->[3];
    $p->[3] = 1;
    check_posts();
    check_readlaterlist();
}

sub unmark_readlater {
    my ( $p ) = @_;
    $t->get_ok("/forum/readlater/unmark/$p->[1]")->status_is(302)
      ->content_is('')->header_is(Location => '/forum/readlater/list');
    $t->get_ok('/forum/readlater/list')->status_is(200);
    info('Vormerkung wurde aufgehoben');
    $rlcnt = $rlcnt - 1 if $p->[3];
    $p->[3] = 0;
    check_posts();
    check_readlaterlist();
}

###############################################################################
note q~Lass uns das ganze mal testen~;
###############################################################################
login_user2();
check_posts();
check_readlaterlist();
mark_readlater($data[2]);
mark_readlater($data[5]);
login_user1();
check_posts(1);
check_readlaterlist(1);
login_user2();
mark_readlater($data[2]);
mark_readlater($data[5]);
login_user1();
check_posts(1);
check_readlaterlist(1);
login_user2();
unmark_readlater($data[1]);
unmark_readlater($data[4]);
unmark_readlater($data[2]);
unmark_readlater($data[5]);
login_user1();
check_posts(1);
check_readlaterlist(1);

