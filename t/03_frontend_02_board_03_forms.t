#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use List::Util;
use Test::Mojo;
use Test::General;
use Mock::Testuser;

use Test::More tests => 1;

my $t = Test::General::test_prepare_frontend('Ffc');



