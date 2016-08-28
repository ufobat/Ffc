use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use Ffc::Plugin::Config;
use File::Temp qw~tempfile tempdir~;
use File::Spec::Functions qw(catfile catdir splitdir);
use Mojo::Util 'xml_escape';

use Test::Mojo;
use Test::More tests => 177;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my ( $user2, $pass2 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my ( $user3, $pass3 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1, $user2, $pass2, $user3, $pass3 );
sub login1 { Testinit::test_login($t, $user1, $pass1) }
sub login2 { Testinit::test_login($t, $user2, $pass2) }
sub login3 { Testinit::test_login($t, $user3, $pass3) }

my %pmsgs = (
    p_2_to_3 => Testinit::test_randstring(),
    p_3_to_2 => Testinit::test_randstring(),

    p_2_to_4 => Testinit::test_randstring(),
    p_4_to_2 => Testinit::test_randstring(),

    p_3_to_4 => Testinit::test_randstring(),
    p_4_to_3 => Testinit::test_randstring(),
);

sub add_post {
    my ( $tuid, $str ) = @_;
    $t->post_ok("/pmsgs/$tuid/new", form => { textdata => $str })
      ->status_is(302)->content_is('')
      ->header_like(location => qr~/pmsgs/$tuid~);
    $t->get_ok("/pmsgs/$tuid")->status_is(200)->content_like(qr~$str~);
}

login1();
add_post(3, $pmsgs{p_2_to_3});
add_post(4, $pmsgs{p_2_to_4});

login2();
add_post(2, $pmsgs{p_3_to_2});
add_post(4, $pmsgs{p_3_to_4});

login3();
add_post(2, $pmsgs{p_4_to_2});
add_post(3, $pmsgs{p_4_to_3});

sub checkse {
    my $url = shift;
    $t->get_ok($url)->status_is(200);
    for my $k ( keys %pmsgs ) {
        if ( grep { $k eq $_ } @_ ) {
            $t->content_like(   qr~$pmsgs{$k}~ );
        }
        else {
            $t->content_unlike( qr~$pmsgs{$k}~ );
        }
    }
    unless ( $t->success ) {
        note 'HERKUNFT: ' . join ' ; ', map {; join ', ', (caller($_))[1,2] } 0 .. 3; 
    }
}

login1();
checkse('/pmsgs/3', qw(p_2_to_3 p_3_to_2));
checkse('/pmsgs/4', qw(p_2_to_4 p_4_to_2));

login2();
checkse('/pmsgs/2', qw(p_3_to_2 p_2_to_3));
checkse('/pmsgs/4', qw(p_3_to_4 p_4_to_3));

login3();
checkse('/pmsgs/2', qw(p_4_to_2 p_2_to_4));
checkse('/pmsgs/3', qw(p_4_to_3 p_3_to_4));

