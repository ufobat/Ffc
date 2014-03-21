use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use Testinit;

use Test::More tests => 42;
use File::Spec::Functions qw(splitdir);
use Test::Mojo;

my @Tests;
for my $i ( 0 .. 2 ) {
    my $test = {};
    @{$test}{qw(t path admin pass dbh)} = Testinit::start_test();
    Testinit::test_login(@{$test}{qw(t admin pass)});
    Testinit::test_logout($test->{t});
    is_deeply [splitdir($test->{path})], $test->{t}->app->datapath, 'datapath set correct';
    push @Tests, $test;
}

isnt $Tests[0]{path}, $Tests[1]{path}, 'paths distinct';
isnt $Tests[1]{path}, $Tests[2]{path}, 'paths distinct';
isnt $Tests[0]{path}, $Tests[2]{path}, 'paths distinct';


