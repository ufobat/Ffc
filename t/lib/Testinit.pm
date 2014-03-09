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
    my ( $csecret, $salt, $user, $pw ) 
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

sub test_logout {
    $_[0]->get_ok('/logout')
         ->status_is(200)
         ->content_like(qr/Nicht angemeldet/);
}

sub test_login {
    my ( $t, $u, $p ) = @_;

    t_logout($t);

    $t->post_ok('/login', form => { username => $u, password => $p })
      ->status_is(302)
      ->header_like(location => qr~https?://localhost:\d+/~);
    $t->get_ok('/')
      ->status_is(200)
      ->content_like(qr/Angemeldet als "$u"/);

    return $t;
}

sub test_dbh {
    my ( $path ) = shift;
    DBI->connect('dbi:SQLite:database='.catfile($path, 'database.sqlite3')
        , { AutoCommit => 1, RaiseError => 1 });
}

