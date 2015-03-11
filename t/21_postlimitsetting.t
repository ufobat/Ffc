use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use Ffc::Plugin::Config;
use File::Temp qw~tempfile tempdir~;
use File::Spec::Functions qw(catfile catdir splitdir);

use Test::Mojo;
use Test::More tests => 1487;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my ( $user2, $pass2 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my $postid = 1;
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1, $user2, $pass2 );
sub login1 { Testinit::test_login($t, $user1, $pass1) }
sub login2 { Testinit::test_login($t, $user2, $pass2) }

sub setup_user {
    my ( $loginsub, $userfrom, $pmsgs_login ) = @_;
    $loginsub->();
    my $post_forum = [ map { ["$user1 forum '$_$_$_'", $postid++] } 'a' .. 'o' ];
    my $post_notes = [ map { ["$user1 notiz '$_$_$_'", $postid++] } 'a' .. 'o' ];
    my $post_pmsgs = [ map { ["$user2 pmsgs '$_$_$_'", $postid++] } 'a' .. 'o' ]; # Sortierung wichtig!

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

    $t->post_ok("/notes/new", 
        form => { textdata => $_->[0] })
      ->status_is(302)->content_is('')
            for @$post_notes;

    $pmsgs_login->();
    $t->post_ok("/pmsgs/$userfrom/new", 
        form => { textdata => $_->[0] })
      ->status_is(302)->content_is('')
            for @$post_pmsgs;

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
      ->content_like(qr~Beiträge \($postlimit\)~);
    $start = $#$posts - $postlimit + 1;
    $start = 0 if $start < 0;
    $end   = $#$posts;
    $end   = 0 if $end < 0;
    note "indizes range from $start to $end";
    check_post($posts, $_, $start, $end, $location) 
        for 0 .. $#$posts;

    note 'check page 2';
    $t->get_ok("$location/2")->status_is(200)
      ->content_like(qr~Beiträge \($postlimit\)~);
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
    my ( $posts, $location ) = @_;
    my $postlimit = 3;
    set_postlimit_ok($postlimit, $location);
    check_postlimit($posts, $postlimit, $location);
    $postlimit = 4;
    set_postlimit_ok($postlimit, $location);
    check_postlimit($posts, $postlimit, $location);
    login1(); # implizites Logout
    check_postlimit($posts, $postlimit, $location);
}

my ( $posts_forum_1, $posts_pmsgs_1, $posts_notes_1 ) = setup_user( \&login1, 2, \&login2 );

login1();
check_error_in_setting( $posts_forum_1, 14, '/topic/1' );
check_error_in_setting( $posts_pmsgs_1, 14, '/pmsgs/3' );
check_error_in_setting( $posts_notes_1, 14, '/notes'   );
check_ok_in_setting(    $posts_forum_1, '/topic/1'     );
check_ok_in_setting(    $posts_pmsgs_1, '/pmsgs/3'     );
check_ok_in_setting(    $posts_notes_1, '/notes'       );

