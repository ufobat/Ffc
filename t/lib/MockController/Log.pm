package MockController::Log;
use strict;
use warnings;
use utf8;
use 5.010;

sub new { bless { error => [] }, shift }

sub error {
    my $l = shift;
    my $m = shift;
    push @{ $l->{error} }, $m if $m;
    return $l->{error};
}

1;

