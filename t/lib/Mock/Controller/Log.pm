package Mock::Controller::Log;
use strict;
use warnings;
use utf8;
use 5.010;

sub new { bless { level => '', error => [] }, shift }

sub error {
    my $l = shift;
    my $m = shift;
    push @{ $l->{error} }, $m if $m;
    return $l->{error};
}

sub level {
    my $l = shift;
    my $s = shift;
    return $l->{level} unless $s;
    return $l->{level} = $s;
}

1;

