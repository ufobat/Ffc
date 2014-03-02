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
    $ENV{FFC_DATA_PATH} = $testpath;
    my ( $csecret, $user, $salt, $pw ) 
        = (split /\n+/, qx($Script 2>&1) )[-4,-3,-2,-1];
    chomp $user; chomp $salt; chomp $pw; chomp $csecret;
    note "user '$user':'$pw' (salt $salt, secret $csecret) created";
    note "CONFIG:\n" . do {
        local $/;
        open my $fh, '<', catfile($testpath, 'config')
            or die "could not open config file: $!";
        <$fh>;
    };
    my $t = Test::Mojo->new('Ffc');
    return $t, $testpath, $user, $pw, $salt, $csecret;
}


