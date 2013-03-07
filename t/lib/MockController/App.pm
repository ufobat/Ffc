package MockController::App;
use strict;
use warnings;
use utf8;
use 5.010;
use MockController::Log;

sub new { bless { log => MockController::Log->new() }, shift }
sub log { shift->{log} }

1;

