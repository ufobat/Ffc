#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Test::Mojo;
use Test::General;

use Test::More tests => 1;

my $t = Test::General::test_prepare_frontend('Ffc');

$t->get_ok('/')->status_is(200)->content_like(qr{Bitte melden Sie sich an});


