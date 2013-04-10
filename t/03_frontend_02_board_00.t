#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;

use Test::More tests => 1;

note('just some inheritance for the actual controller classes');
use_ok('Ffc::Board');

