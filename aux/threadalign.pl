#!/usr/bin/perl 
use strict;
use warnings;
use 5.10.1;

my @colorchars = qw(f 9 3);
my @colors;

for my $h ( 0..$#colorchars ) {
    for my $j ( 0..$#colorchars ) {
        for my $k ( 0..$#colorchars ) {
            push @colors, [ [ map {$colorchars[$_]} $k, $j, $h], $h+$j+$k ];
        }
    }
}

@colors = map {join '', @{$_->[0]}} sort {$a->[1] <=> $b->[1]} @colors;

for my $i ( 0..$#colors ) {
    printf 
        ".c%02d{border-color:#%s;margin-left:%dem}\n"
        , $i + 1, $colors[$i], 2*$i
}

