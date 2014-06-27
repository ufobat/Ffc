use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use Testinit;

use Test::More tests => 42;
use File::Spec::Functions qw(splitdir);
use Test::Mojo;

my ( $t, $path, $admin, $pass, $dbh ) = Testinit::start_test();

my @Users = map {["User$_", "Password$_"]} 0 .. 2;
Testinit::test_add_users($t, $admin, $pass, map {@$_} @Users);

my @Tests = map { 
    my $t = Test::Mojo->new('Ffc');
    Testinit::test_login($t, @{$Users[$_]});
    $t->get_ok('/notes')
      ->status_is(200)
      ->content_like(qr~<!-- Angemeldet als "$Users[$_][0]" !-->~);
    $t;
} 0 .. 2;

