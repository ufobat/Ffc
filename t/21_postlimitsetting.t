use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use Ffc::Plugin::Config;
use File::Temp qw~tempfile tempdir~;
use File::Spec::Functions qw(catfile catdir splitdir);

use Test::Mojo;
use Test::More tests => 2148;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my ( $user2, $pass2 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my $postid = 1;
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1, $user2, $pass2 );
sub login1 { Testinit::test_login($t, $user1, $pass1) }
sub login2 { Testinit::test_login($t, $user2, $pass2) }

sub setup_user {
    my ( $loginsub, $userfrom, $pmsgs_login, $with_forum ) = @_;
    $loginsub->();
    my $post_forum = [];
    my $post_pmsgs = [];
    
    $t->get_ok('/topic/1')->status_is(200); # reset wegen neuer Beiträge

    if ( $with_forum ) {
        $post_forum = [ map { ["$user1 forum '$_$_$_'", $postid++] } 'a' .. 'p' ];
        $t->post_ok('/topic/new', 
            form => {
                titlestring => "user $userfrom topic", 
                textdata => $post_forum->[0]->[0]
            })
          ->status_is(302)->content_is('');

        $t->post_ok("/topic/1/new", 
            form => { textdata => $_->[0] })
          ->status_is(302)->content_is('')
                for @{$post_forum}[1 .. $#$post_forum];

        $pmsgs_login->();
        $post_pmsgs = [ map { ["$user2 pmsgs '$_$_$_'", $postid++] } 'a' .. 'p' ]; # Sortierung wichtig!
        $t->post_ok("/pmsgs/$userfrom/new", 
            form => { textdata => $_->[0] })
          ->status_is(302)->content_is('')
                for @$post_pmsgs;
    }

    $loginsub->();
    my $post_notes = [ map { ["$user1 notiz '$_$_$_'", $postid++] } 'a' .. 'p' ];
    $t->post_ok("/notes/new", 
        form => { textdata => $_->[0] })
      ->status_is(302)->content_is('')
            for @$post_notes;

    return $post_forum, $post_pmsgs, $post_notes;
}

sub check_post {
    my ( $posts, $i, $start, $end, $location ) = @_;
    return if $i < 0 or $i > $#$posts;
    my ( $post, $id ) = @{ $posts->[$i] };
    if ( $i >= $start and $i <= $end ) {
        $t->content_like(qr~"$location/display/$id"~)
          ->content_like(qr~$post~);
    }
    else {
        $t->content_unlike(qr~"$location/display/$id"~)
          ->content_unlike(qr~$post~);
    }
};

sub check_postlimit {
    my ( $posts, $postlimit, $location ) = @_;
    my ( $start, $end ) = (0, 0);

    note 'check page 1';
    $t->get_ok($location)->status_is(200)
      ->content_like(qr~<span class="limitsetting postlimit">$postlimit</span>~);
    $start = $#$posts - $postlimit + 1;
    $start = 0 if $start < 0;
    $end   = $#$posts;
    $end   = 0 if $end < 0;
    note "indizes range from $start to $end";
    check_post($posts, $_, $start, $end, $location) 
        for 0 .. $#$posts;

    note 'check page 2';
    $t->get_ok("$location/2")->status_is(200)
      ->content_like(qr~<span class="limitsetting postlimit">$postlimit</span>~);
    $start = $#$posts - $postlimit - $postlimit + 1;
    $start = 0 if $start < 0;
    $end   = $#$posts - $postlimit;
    $end   = 0 if $end < 0;
    note "indizes range from $start to $end";
    check_post($posts, $_, $start, $end, $location) 
        for 0 .. $#$posts;
}

sub set_postlimit_ok {
    my $postlimit = shift;
    my $location = shift;
    $t->get_ok("$location/limit/$postlimit")->status_is(302)
      ->content_is('')->header_is(Location => $location);
    $t->get_ok($location)->status_is(200);
    Testinit::test_info($t, 
        "Anzahl der auf einer Seite der Liste angezeigten Beiträge auf $postlimit geändert.");
}

sub set_postlimit_error {
    my $postlimit = shift;
    my $location = shift;
    $t->get_ok("$location/limit/$postlimit")->status_is(302)
      ->content_is('')->header_is(Location => $location);
    $t->get_ok($location)->status_is(200);
    Testinit::test_error($t, 
        'Die Anzahl der auf einer Seite in der Liste angezeigten Beiträge muss eine ganze Zahl kleiner 128 sein.');
}

sub check_error_in_setting {
    my ( $posts, $postlimit, $location ) = @_;
    check_postlimit($posts, $postlimit, $location);
    set_postlimit_error(0, $location);
    check_postlimit($posts, $postlimit, $location);
    set_postlimit_error(128, $location);
    check_postlimit($posts, $postlimit, $location);
}

sub check_ok_in_setting {
    my ( $posts1, $posts2, $location1, $location2 ) = @_;
    $location2 = $location1 unless $location2;
    login1();
    my $postlimit = 5;
    set_postlimit_ok($postlimit, $location1);
    check_postlimit($posts1, $postlimit, $location1);
    $postlimit = 7;
    set_postlimit_ok($postlimit, $location1);
    check_postlimit($posts1, $postlimit, $location1);
    login2(); # implizites Logout
    check_postlimit($posts2, 10, $location2);
    login1(); # implizites Logout
    check_postlimit($posts1, $postlimit, $location1);
    login1(); # implizites Logout
    check_postlimit($posts1, $postlimit, $location1);
}

my ( $posts_forum_1, $posts_pmsgs_1, $posts_notes_1 ) = setup_user( \&login1, 2, \&login2, 1 );
my ( $posts_forum_2, $posts_pmsgs_2, $posts_notes_2 ) = setup_user( \&login2, 3, \&login1 );
$posts_forum_2 = $posts_forum_1;
$posts_pmsgs_2 = $posts_pmsgs_1;

login1();
check_error_in_setting( $posts_forum_1, 10, '/topic/1' );
check_error_in_setting( $posts_pmsgs_1, 10, '/pmsgs/3' );
check_error_in_setting( $posts_notes_1, 10, '/notes'   );
check_ok_in_setting(    $posts_forum_1, $posts_forum_2, '/topic/1' );
check_ok_in_setting(    $posts_pmsgs_1, $posts_pmsgs_2, '/pmsgs/3', '/pmsgs/2' );
check_ok_in_setting(    $posts_notes_1, $posts_notes_2, '/notes'   );

