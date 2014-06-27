use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use Testinit;

use Test::More tests => 369;
use File::Spec::Functions qw(splitdir);
use Test::Mojo;

my $Users = 21;

my ( $t, $path, $admin, $pass, $dbh ) = Testinit::start_test();

my @Users = map {["User$_", "Password$_"]} 1 .. 21;
Testinit::test_add_users($t, $admin, $pass, map {@$_} @Users);

my @Tests = map { 
    my $t = Test::Mojo->new('Ffc');
    Testinit::test_login($t, @$_);
    $t->get_ok('/notes')
      ->status_is(200)
      ->content_like(qr~<!-- Angemeldet als "$_->[0]" !-->~);
    $t;
} @Users;

for my $i ( 0 .. $#Tests ) {
    my $t = $Tests[$i];
    my $u = $Users[$i];
    $t->get_ok('/forum')
      ->status_is(200)
      ->content_like(qr~<!-- Angemeldet als "$u->[0]" !-->~);
}

