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

note('just some relay methods that are allready tested in "01_aux______01_errorhandling.t"');
use_ok('Ffc::Board::Errors');

