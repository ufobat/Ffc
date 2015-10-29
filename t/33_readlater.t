use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use utf8;

use Carp;
use Data::Dumper;
use Test::Mojo;
use Test::More tests => 59;

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

login_user1();

$t->post_ok('/topic/new', 
    form => {
        titlestring => "Testtopic 1",
        textdata => Testinit::test_randstring(),
    })->status_is(302)->content_is('');
$t->post_ok('/topic/new', 
    form => {
        titlestring => "Testtopic 2",
        textdata => Testinit::test_randstring(),
    })->status_is(302)->content_is('');


#     0   =>             1,           2,        3
# ([ Zufälliger Text => Beitrags-Id, Topic-Id, SpäterLesen-Flag ])
my @data = ( 
    map( {;[Testinit::test_randstring() => $_, 1, 0]} 1 .. 3 ), 
    map( {;[Testinit::test_randstring() => $_, 2, 0]} 4 .. 6 ), 
);
for my $d ( @data ) {
    $t->post_ok("/topic/$d->[2]/new", 
        form => {
            textdata => $d->[0],
        })->status_is(302)->content_is('');
}
# Unechte Beiträge
my @dummy = ( [Testinit::test_randstring() => 7, 1, 0] );

###############################################################################
note q~Pruefungen in Subroutinen giessen~;
###############################################################################
sub check_posts {

}

sub check_readlaterlist {
    my ( $empty ) = @_; # for user without anything on readlater list

}

sub mark_readlater {
    my ( $post ) = @_;
    $t->get_ok()->status_is(302);
    info($post->[3] ? 'Vormerkung besteht bereits' : 'Beitrag wurde vorgemerkt');
    $post->[3] = 1;
}

sub unmark_readlater {
    my ( $post, $error ) = @_;
    $post->[3] = 1;

}
