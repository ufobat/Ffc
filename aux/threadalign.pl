#!/usr/bin/perl 
use strict;
use warnings;
use 5.10.1;

for my $i ( 0..99 ) {
    printf 
        ".c%02d{margin-left:%dem}\n"
        , $i + 1, 2*$i
}

