package Testinit;

use strict;
use warnings;
use 5.010;

use File::Spec::Functions qw(catfile splitdir catdir);
use File::Basename;
use File::Temp;
use Data::Dumper;
use Test::More;
use DBI;
use lib 
  catdir(splitdir(File::Basename::dirname(__FILE__)), '..', '..', 'lib');

our $Script 
    = catfile( splitdir(File::Basename::dirname(__FILE__)),
        '..', '..', 'script', 'init.pl' );
our @Chars = ('a' .. 'z', 'A' .. 'C', 'E' .. 'O', 'Q' .. 'X', 'Y', 'Z'); # 'D' und so wird in Smilies verwendet, das geht für Tests blöd, Smilies werden extra getestet
{
    my $scnt = 1;
    my $ts = sub { join '', map { $Chars[int rand @Chars] } 1 .. $_[0] };
    sub test_randstring { sprintf "%s%04d%s", $ts->($_[0]//3), $scnt++, $ts->($_[0]//3) }
}

our $CookieName = test_randstring(6);
our @Users; our %Users;

sub start_test {
    my $testpath = File::Temp::tempdir( CLEANUP => 1 );
    note "using test data dir '$testpath'";
    $ENV{FFC_DATA_PATH} = $testpath;
    my ( $csecret, $salt, $user, $pw ) 
        = (split /\n+/, qx($Script '-d' '$CookieName' 2>&1) )[-4,-3,-2,-1];
    chomp $user; chomp $salt; chomp $pw; chomp $csecret;
    note "user '$user':'$pw' (salt $salt, secret $csecret) created";
    my $t = Test::Mojo->new('Ffc');
    note "CONFIG:\n" . Dumper($t->app->configdata);
    @Users = ( $user ); $Users{$user} = 1;
    return $t, $testpath, $user, $pw, test_dbh($testpath), $salt, $csecret;
}

sub test_logout {
    $_[0]->get_ok('/logout')
         ->status_is(200)
         ->content_like(qr/Angemeldet als "\&lt;noone\&gt;"/);
}

sub test_login {
    my ( $t, $u, $p ) = @_;

    test_logout($t);
    note "try to login in as '$u'" . ( exists $Users{$u} ? " (id=$Users{$u})" : '' );
    #diag "login as user '$u'";

    $t->post_ok('/login', form => { username => $u, password => $p })
      ->status_is(302)
      ->header_like(location => qr~/~);
    $t->get_ok('/')
      ->status_is(200)
      ->content_like(qr/Angemeldet als "$u"/);

    note "logged in as '$u'" . ( exists $Users{$u} ? " (id=$Users{$u})" : '' );

    return $t;
}

sub test_dbh {
    my ( $path ) = shift;
    DBI->connect('dbi:SQLite:database='.catfile($path, 'database.sqlite3')
        , { AutoCommit => 1, RaiseError => 1 });
}

sub test_get_userid {
    my $dbh = shift;
    my $user = shift;
    $dbh->selectall_arrayref('SELECT id FROM users WHERE UPPER(name)=UPPER(?)', undef, $user)->[0]->[0];
}

1;
