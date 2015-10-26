use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use utf8;

use Carp;
use Data::Dumper;
use Test::Mojo;
use Test::More tests => 1668;

###############################################################################
note q~Testsystem vorbereiten~;
###############################################################################
my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
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
        textdata => $scores[1][1],
    })->status_is(302)->content_is('');
$t->post_ok('/topic/new', 
    form => {
        titlestring => "Testtopic 2",
        textdata => $scores[1][1],
    })->status_is(302)->content_is('');


#     0   =>             1,           2,        3
# ([ Zufälliger Text => Beitrags-Id, Topic-Id, SpäterLesen-Flag ])
my @data = ( 
    map( {;[Testinit::randstring() => $_, 1, 0]} 1 .. 3 ), 
    map( {;[Testinit::randstring() => $_, 2, 0]} 4 .. 6 ), 
);
for my $d ( @data ) {
    $t->post_ok("/topic/$d->[2]/new", 
        form => {
            textdata => $d->[0],
        })->status_is(302)->content_is('');
}

###############################################################################
note q~Pruefungen in Subroutinen giessen~;
###############################################################################
sub check_posts {

}

sub check_readlaterlist {
    my ( $empty ) = @_; # for user without anything on readlater list

}

sub mark_readlater {
    my ( $error ) = @_;

}

sub unmark_readlater {
    my ( $error ) = @_;

}
