use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use Ffc::Plugin::Config;
use File::Temp qw~tempfile tempdir~;
use File::Spec::Functions qw(catfile catdir splitdir);

use Test::Mojo;
use Test::More tests => 625;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my ( $user2, $pass2 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1, $user2, $pass2 );
Testinit::test_login($t, $user1, $pass1);

my @topics = map { $_ x 2 } 'a' .. 'u';
for my $c ( @topics ) {
    $t->post_ok('/topic/new', form => {titlestring => $c, textdata => $c x 2});
}

sub check_topics {
    my ( $start, $end, $topiclimit ) = @_;
    for my $i ( 0 .. $#topics ) {
        my $id = $i + 1;
        my $sp = $topics[$i] x 2;
        $sp = qq~<div class="otherspopup popup topiclistpopup summarypopup">\\s*<p>$sp ...</p>\\s*</div>\\s*</a>\\s*</span>\\s*~;
        $sp = qq~<h2(?:\\s+class="newpost")?>\\s*<span\\s+class="menuentry">\\s*<a href="/topic/$id">$topics[$i]\\s*$sp~;
        if ( $i >= $start and $i <= $end ) {
            $t->content_like(qr~$sp~);
        }
        else {
            $t->content_unlike(qr~$sp~);
        }
    }
    note 'check popup topics';
    my $topicpopup = join "\\s*\n\\s*", 
        '<div class="topicpopup popup otherspopup">',
        map( {; 
            my $id = $_ + 1; my $text = $topics[$_];
            qq~<p(?:\\s+class="[\\w\\s]+")?><a href="/topic/$id">$text</a>...~
                . qq~(?: \\(<span class="mark">\[1\]</span>\\))?~
                . qq~</p>~ 
        } $#topics - $topiclimit + 1 .. $#topics ),
        '</div>';
    $t->content_like(qr~$topicpopup~);
}
sub check_topiclimit {
    my $topiclimit = shift;

    $t->get_ok('/forum')->status_is(200)
      ->content_like(qr~<span class="limitsetting topiclimit">$topiclimit</span>~);
    my $start = $#topics - $topiclimit + 1;
    $start = 0 if $start < 0;
    my $end   = $#topics;
    $end = 0 if $end < 0;
    note "page=1, topiclimit=$topiclimit, indizes: start=$start, end=$end";
    check_topics( $start, $end, $topiclimit );

    $t->get_ok('/forum/2')->status_is(200)
      ->content_like(qr~<span class="limitsetting topiclimit">$topiclimit</span>~);
    $start = $#topics - $topiclimit - $topiclimit + 1;
    $start = 0 if $start < 0;
    $end   = $#topics - $topiclimit;
    $end = 0 if $end < 0;
    note "page=2, topiclimit=$topiclimit, indizes: start=$start, end=$end";
    check_topics( $start, $end, $topiclimit );
}

sub set_topiclimit_ok {
    my $topiclimit = shift;
    $t->get_ok("/topic/limit/$topiclimit")->status_is(302)
      ->content_is('')->header_is(Location => '/forum');
    $t->get_ok('/forum')->status_is(200);
    Testinit::test_info($t, 
        "Anzahl der auf einer Seite der Liste angezeigten Überschriften auf $topiclimit geändert.");
}

sub set_topiclimit_error {
    my $topiclimit = shift;
    $t->get_ok("/topic/limit/$topiclimit")->status_is(302)
      ->content_is('')->header_is(Location => '/forum');
    $t->get_ok('/forum')->status_is(200);
    Testinit::test_error($t, 
        'Die Anzahl der auf einer Seite in der Liste angezeigten Überschriften muss eine ganze Zahl kleiner 128 sein.');
}

my $topiclimit = 15; # Default
check_topiclimit($topiclimit);
$topiclimit = 5;
set_topiclimit_ok($topiclimit);
check_topiclimit($topiclimit);
set_topiclimit_error(0);
check_topiclimit($topiclimit);
set_topiclimit_error(128);
check_topiclimit($topiclimit);
$topiclimit = 10;
set_topiclimit_ok($topiclimit);
check_topiclimit($topiclimit);
$topiclimit = 5;
set_topiclimit_ok($topiclimit);
check_topiclimit($topiclimit);
Testinit::test_login($t, $user1, $pass1);
check_topiclimit($topiclimit);

$topiclimit = 15; # Default wieder
Testinit::test_login($t, $user2, $pass2);
check_topiclimit($topiclimit);
$topiclimit = 10;
set_topiclimit_ok($topiclimit);
check_topiclimit($topiclimit);
$topiclimit = 5;
Testinit::test_login($t, $user1, $pass1);
check_topiclimit($topiclimit);

