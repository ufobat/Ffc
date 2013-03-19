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
use Mock::Database;
use Mock::Config;
use Ffc::Data;

use Test::More tests => 1;

srand;

sub r { 
    my @chars = ('a'..'z', 'A'..'Z', 0..9, qw(- _));
    join '', map {$chars[int rand scalar @chars]} 0..7;
}


die r();

BEGIN { use_ok('Ffc::Data::Auth') }

note('doing some preparations');
my $config = Mock::Config->new->{config};
my $app = Mojolicious->new();
$app->log->level('error');
Ffc::Data::set_config($app);
Mock::Database::prepare_testdatabase();
my $username = r();
my $password = r();
my $useremail => "$username\@site";
Ffc::Data::dbh()->do(qq[INSERT INTO ${Ffc::Data::Prefix}users ("name", "password", "email", "admin") VALUES (?,?,?,1)], undef, $username, $password, $useremail);

