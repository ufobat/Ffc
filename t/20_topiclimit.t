use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use Ffc::Plugin::Config;
use File::Temp qw~tempfile tempdir~;
use File::Spec::Functions qw(catfile catdir splitdir);

use Test::Mojo;
use Test::More tests => 420;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my ( $user2, $pass2 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1, $user2, $pass2 );
Testinit::test_login($t, $user1, $pass1);

my @topics = map { $_ x 2 } 'a' .. 'z';
for my $c ( @topics ) {
    $t->post_ok('/topic/new', form => {titlestring => $c, textdata => $c x 2});
}

sub check_topiclimit {
    my $topiclimit = shift;
    $t->get_ok('/forum')->status_is(200)
      ->content_like(qr~\(derzeit $topiclimit\)~);
    for my $i ( $#topics - $topiclimit + 1 .. $#topics ) {
        my $id = $i + 1;
        $t->content_like(qr~<a href="/topic/$id">$topics[$i]</a>~);
    }
    for my $i ( 0 .. $#topics - $topiclimit ) {
        my $id = $i + 1;
        $t->content_unlike(qr~<a href="/topic/$id">$topics[$i]</a>~);
    }
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

my $topiclimit = 21;
check_topiclimit($topiclimit);
$topiclimit = 2;
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

$topiclimit = 21;
Testinit::test_login($t, $user2, $pass2);
check_topiclimit($topiclimit);
$topiclimit = 3;
set_topiclimit_ok($topiclimit);
check_topiclimit($topiclimit);
$topiclimit = 5;
Testinit::test_login($t, $user1, $pass1);
check_topiclimit($topiclimit);

