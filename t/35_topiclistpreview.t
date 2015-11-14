use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use utf8;

use Carp;
use Data::Dumper;
use Test::Mojo;
use Test::More tests => 170;

#################################################
# Vorbereitungstreffen
#################################################

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
Testinit::test_login($t, $admin, $apass);

