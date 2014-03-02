package Testinit;
use strict;
use warnings;
use 5.010;

use File::Spec::Functions qw(catfile splitdir catdir);
use File::Basename;
use File::Temp;
use Test::More;
use DBI;
use lib 
  catdir(splitdir(File::Basename::dirname(__FILE__)), '..', '..', 'lib');

our $Script 
    = catfile splitdir(File::Basename::dirname(__FILE__)),
        '..', '..', 'script', 'init.pl';

sub start_test {
    my $testpath = File::Temp::tempdir( CLEANUP => 1 );
    note "using test data dir '$testpath'";
    local $ENV{FFC_DATA_PATH} = $testpath;
    my $pw = ( split /\n+/, qx($Script 2>&1) )[-1];
    chomp $pw;
    note "user 'admin' with password '$pw' created";
    my $t = Test::Mojo->new('Ffc');
    return $t, $testpath, 'admin', $pw;
}


