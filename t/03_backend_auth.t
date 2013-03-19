#!/usr/bin/perl
use 5.010;
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Mojolicious;
use Mock::Config;
use Ffc::Data;

use Test::More tests => 1;

srand;

sub r { '>>> ' . rand(10000) . ' <<<' }

BEGIN { use_ok('Ffc::Data::Auth') }

note('doing some preparations');
my $config = Mock::Config->new->{config};
my $app = Mojolicious->new();
$app->log->level('error');
Ffc::Data::set_config($app);
