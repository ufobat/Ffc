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
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1, $user2, $pass2 );
sub ladmin { Testinit::test_login($t, $admin, $apass) }
sub login1 { Testinit::test_login($t, $user1, $pass1) }
sub login2 { Testinit::test_login($t, $user2, $pass2) }

my $id = 0; my @forums; my @pmsgss;

# Forenbeitrag erstellen
sub add_forum {
    my $cnt = $_[0] // 1;
    my $str = Testinit::test_randstring();
    note "add to forum: $str";
    push @forums, map {[$id++,$str]} 1..$cnt;
    $t->post_ok("/topic/1/new", form => { textdata => $str })
      ->status_is(302)->content_is('')
      ->header_like(location => qr~/topic/1~);
    $t->get_ok("/topic/1")->status_is(200)->content_like(qr~$str~);
}

# Privatnachricht erstellen
sub add_pmsgs {
    my ( $tuid, $cnt ) = ( $_[0], $_[0] // 1 );
    my $str = Testinit::test_randstring();
    note "add to pmsgs: $str";
    push @pmsgss, map {[$id++,$str]} 1..$cnt;
    $t->post_ok("/pmsgs/$tuid/new", form => { textdata => $str })
      ->status_is(302)->content_is('')
      ->header_like(location => qr~/pmsgs/$tuid~);
    $t->get_ok("/pmsgs/$tuid")->status_is(200)->content_like(qr~$str~);
}

# Prüfen, ob was da ist, oder ob gerade das nicht da ist
sub _check_ajax {
    my ( $usertoid, $ok, @new ) = @_;
    $t->get_ok( ($usertoid ? "/pmsgs/$usertoid": '/topic/1') . '/fetch/new' );
    $t->status_is(200);
    $ok ? $t->json_has( "/$#new" ) : $t->json_hasnt( "/$#new" );
    for my $r ( 0 .. $#new ) {
        my $p = $new[$r];
        my ( $id, $str ) = @$p;
        if ( $ok ) {
            $t->json_like( "/$r", qr~<a href="/topic/1/display/$id"~ );
            $t->json_like( "/$r", qr~<p>$str</p>~ );
        }
        else {
            $t->json_unlike( "/$r", qr~<a href="/topic/1/display/$id"~ );
            $t->json_unlike( "/$r", qr~<p>$str</p>~ );
        }
    }
}
sub check_forum_has { _check_ajax( undef,   1, @_ ) }
sub check_forum_not { _check_ajax( undef,   0, @_ ) }
sub check_pmsgs_has { _check_ajax( shift(), 1, @_ ) }
sub check_pmsgs_not { _check_ajax( shift(), 0, @_ ) }

# Neues Thema - wir benutzen immer das selbe, warum auch nicht
ladmin();
$t->post_ok('/topic/new', 
    form => {
        titlestring => 'Topic1',
        textdata => 'Testbeitrag1',
    })->status_is(302)->content_is('');


# Forenbeiträge und Privatnachrichten erstellen
login1();

add_forum(3);
add_pmsgs(3,3);

check_forum_not(   reverse @forums);
check_pmsgs_not(3, reverse @pmsgss);

__END__
# Neue Forenbeiträge und Privatnachrichten im AJAX-Fetch prüfen
login2();

check_forum_has(   reverse @forums);
check_pmsgs_has(2, reverse @pmsgss);

check_forum_not(   reverse @forums);
check_pmsgs_not(2, reverse @pmsgss);
