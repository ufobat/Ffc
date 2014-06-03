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
    = catfile splitdir(File::Basename::dirname(__FILE__)),
        '..', '..', 'script', 'init.pl';
our @Chars = ('a' .. 'z', 'A' .. 'Z', 0 .. 9);
{
    my %Strings;
    my $ts = sub { join '', map { $Chars[int rand @Chars] } 1 .. 10 };
    sub test_randstring {
        my $str = $ts->();
        while ( exists $Strings{$str} ) {
            $str = $ts->();
        }
        $Strings{$str} = 1;
        return $str;
    }
}

sub start_test {
    my $testpath = File::Temp::tempdir( CLEANUP => 1 );
    note "using test data dir '$testpath'";
    $ENV{FFC_DATA_PATH} = $testpath;
    my ( $csecret, $salt, $user, $pw ) 
        = (split /\n+/, qx($Script 2>&1) )[-4,-3,-2,-1];
    chomp $user; chomp $salt; chomp $pw; chomp $csecret;
    note "user '$user':'$pw' (salt $salt, secret $csecret) created";
    my $t = Test::Mojo->new('Ffc');
    note "CONFIG:\n" . Dumper($t->app->configdata);
    return $t, $testpath, $user, $pw, test_dbh($testpath), $salt, $csecret;
}

sub test_logout {
    $_[0]->get_ok('/logout')
         ->status_is(200)
         ->content_like(qr/Nicht angemeldet/);
}

sub test_login {
    my ( $t, $u, $p ) = @_;

    test_logout($t);

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

sub test_error {
    my ( $t, $error ) = @_;
    $t->content_like(
        qr~<div\s+class="error">\s*<h1>Fehler</h1>\s*$error\s*</div>~);
}

sub test_info {
    my ( $t, $info ) = @_;
    $t->content_like(
        qr~<div\s+class="info">\s*<h1>Hinweis</h1>\s*$info\s*</div>~);
}

sub test_warning {
    my ( $t, $warning ) = @_;
    $t->content_like(
        qr~<div\s+class="info">\s*<h1>Warnung</h1>\s*$warning\s*</div>~);
}

sub test_add_user { &test_add_users } # Alias
sub test_add_users {
    my $t = shift; my $admin = shift; my $apass = shift;
    test_login($t, $admin, $apass);
    my $cnt = 0;
    while ( @_ ) {
        my $user = shift;
        my $pass = shift;
        last unless $user and $pass;
        $t->post_ok('/options/admin/useradd', form => {username => $user, newpw1 => $pass, newpw2 => $pass, active => 1})
          ->content_like(qr~Benutzer \&quot;$user\&quot; angelegt~);
        $cnt++;
    }
    test_logout($t);
    if ( $cnt ) {
        note $cnt == 1
            ? 'one user created'
            : "$cnt users created";
    }
    else {
        diag 'no users created';

    }
    return $t;
}

sub test_get_userid {
    my $dbh = shift;
    my $user = shift;
    $dbh->selectall_arrayref('SELECT id FROM users WHERE UPPER(name)=UPPER(?)', undef, $user)->[0]->[0];
}

