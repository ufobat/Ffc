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
use Mock::Testuser;
use Ffc::Data::Board::Views;

use Test::More tests => 1;

my $t = Test::General::test_prepare_frontend('Ffc');

my $user1 = Mock::Testuser->new_active_user();
my $user2 = Mock::Testuser->new_active_user();
my %cats  = map { $_->[2] => $_->[0] } @Test::General::Categories;

my @testmatrix;

{
    my @usertable = (

        #     from    to    cat(s.u.)
        [ $user1, $user2 ],
        [ $user2, $user1 ],
        [ $user1, $user1 ],
        [ $user2, $user2 ],
    );

    for my $cat ( undef, keys %cats ) {
        push @testmatrix, map { my @tbl = @$_; push @tbl, $cat; \@tbl } @usertable;
    }
}

for my $test ( @testmatrix ) {
    my ( $from, $to, $cat ) = @$test;
}
