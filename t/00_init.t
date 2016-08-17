use Mojo::Base -strict;

use Test::Mojo;

use 5.010;
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use Testinit;

use DBI;
use File::Temp;
use File::Spec::Functions qw(catfile);
use Digest::SHA 'sha512_base64';

use Test::More tests => 198;

my $script = $Testinit::Script;
note "testing init script '$script'";

my $testpath1 = File::Temp::tempdir( CLEANUP => 1 );
my $testpath2 = File::Temp::tempdir( CLEANUP => 1 );

note 'first test run';
test_path($testpath1);
note 'second test run';
test_path($testpath2);

sub check_pw {
    my ( $testpath, $user, $salt, $pw ) = @_;
    note "checking password for '$user' with '$pw' salted '$salt'";
    is(DBI->connect(
        "DBI:SQLite:database=$testpath/database.sqlite3"
        ,'','',{AutoCommit => 1, RaiseError => 1})
       ->selectall_arrayref(
        'SELECT COUNT(id) FROM users WHERE name=? AND password=? AND active=1'
        , undef, $user, sha512_base64($pw, $salt))
       ->[0]->[0], 1, 'admin password ok');
}

sub check_config {
    my ($testpath, $salt, $csecret, $cookie) = @_;
    my %zuo = map {@$_} @{ DBI->connect(
        "DBI:SQLite:database=$testpath/database.sqlite3"
        ,'','',{AutoCommit => 1, RaiseError => 1})
        ->selectall_arrayref(
            'SELECT "key", "value" FROM "config"'
        ) 
    };
    is $zuo{cryptsalt}, $salt, "auto config param cryptsalt set ok to $salt";
    is $zuo{cookiesecret}, $csecret, "auto config param cookiesecret set ok to $csecret";
    is $zuo{cookiename}, $cookie, "config for cookie name $cookie set ok";
}

sub check_paths {
    my $testpath = shift;
    my $noexist = shift;
    for my $path ( 
        [ qq'$testpath/avatars',          1 ],
        [ qq'$testpath/uploads',          1 ],
        [ qq'$testpath/database.sqlite3', 0 ],
        [ qq'$testpath/favicon',          0 ],
    ) {
        my ( $p, $d ) = @$path;
        if ( $noexist ) {
            ok !-e $p, "'$p' does not exist yet";
        }
        else {
            ok -e $p, "'$p' exists";
            if ( $d ) {
                ok -d $p, "'$p' is a directory";
                ok !-f $p, "'$p' is not a file";
            }
            else {
                ok !-d $p, "'$p' is not a directory";
                ok -f $p, "'$p' is a file";
            }
        }
    }
}

sub test_path {
    my $testpath = shift;

    note "using path '$testpath' for tests";
    my $csecret = '';
    my $user    = '';
    my $pw      = '';
    my $salt    = 0;
    my $cookie  = Testinit::test_randstring();

    my $out0 = qx($script 2>&1);
    note 'test error without cookie name and without -d';
    like $out0,
        qr'error: please provide a cookie name as last parameter',
        'error message for invalid cookie name ok';
    check_paths($testpath, 1);
    $out0 = '';
    $out0 = qx($script -d 2>&1);
    note 'test error without cookie name but with -d';
    like $out0, 
        qr'error: please provide a cookie name as last parameter',
        'error message for invalid cookie name ok';
    check_paths($testpath, 1);

    my $out1 = qx($script -d $cookie 2>&1);
    note 'test error without path env variable';
    like $out1,
        qr'error: please provide a "FFC_DATA_PATH" environment variable',
        'error message for env var ok';
    check_paths($testpath, 1);

    note 'test with new empty path';
    $cookie  = Testinit::test_randstring();
    my $out2 = qx(FFC_DATA_PATH=$testpath $script -d $cookie 2>&1);

    like $out2, $_, 'first run content ok' for (
        qr~ok: using '\d+' as data path owner and '\d+' as data path group~,
        qr~ok: using '$testpath/avatars' as avatar store~,
        qr~ok: using '$testpath/uploads' as upload store~,
        qr~ok: using '$testpath/database\.sqlite3' as database store~,
        qr~ok: check user and group priviledges of the data path!~,
        qr~ok: initial cookiesecret, salt, admin user and password:~,
    );

    ( $csecret, $salt, $user, $pw ) = (split /\n+/, $out2 )[-4,-3,-2,-1];
    chomp $user; chomp $salt; chomp $pw; chomp $csecret;
    is $user, 'admin', 'admin user received';
    like $salt, qr/\d+/, 'salt received';
    ok $csecret, 'cookiesecret provided';
    ok $pw, 'password received';
    note "adminuser supplied is '$user'";
    note "salt supplied is '$salt'";
    note "password supplied is '$pw'";
    check_pw($testpath, $user, $salt, $pw);
    check_paths($testpath);
    check_config($testpath, $salt, $csecret, $cookie);

    note 'test with allready existing path';
    my $out3 = qx(FFC_DATA_PATH=$testpath $script -d $cookie 2>&1);
    like $out3, $_, 'second run content existing ok' for (
        qr~ok: using '\d+' as data path owner and '\d+' as data path group~,
        qr~ok: using '$testpath/avatars' as avatar store~,
        qr~ok: path '$testpath/avatars' as avatar allready exists~,
        qr~ok: using '$testpath/uploads' as upload store~,
        qr~ok: path '$testpath/uploads' as upload allready exists~,
        qr~ok: using '$testpath/database\.sqlite3' as database store~,
        qr~ok: path '$testpath/database\.sqlite3' as database allready exists~,
        qr~ok: using '$testpath/favicon' as favicon store~,
        qr~ok: check user and group priviledges of the data path!~,
        qr~ok: database allready existed, no admin user created~,
    );
    unlike $out3, qr($_), "second run content ok"
        for qw(cookiesecret salt cookiename);

    check_pw($testpath, $user, $salt, $pw);
    check_paths($testpath);
    check_config($testpath, $salt, $csecret, $cookie);

    note 'test with allready existing path but without database';
    {
        local $ENV{FFC_DATA_PATH} = $testpath;
        do {
            use Mojolicious::Lite;
            plugin 'Ffc::Plugin::Config';
        }->_get_dbh()->disconnect() or die;
        unlink "$testpath/database.sqlite3";
    }
    $cookie  = Testinit::test_randstring();
    my $out4 = qx(FFC_DATA_PATH=$testpath $script -d $cookie 2>&1);
    like $out4, $_, 'third run content without database' for (
        qr~ok: using '\d+' as data path owner and '\d+' as data path group~,
        qr~ok: using '$testpath/avatars' as avatar store~,
        qr~ok: path '$testpath/avatars' as avatar allready exists~,
        qr~ok: using '$testpath/uploads' as upload store~,
        qr~ok: path '$testpath/uploads' as upload allready exists~,
        qr~ok: using '$testpath/database\.sqlite3' as database store~,
        qr~ok: using '$testpath/favicon' as favicon store~,
        qr~ok: check user and group priviledges of the data path!~,
        qr~ok: initial cookiesecret, salt, admin user and password:~,
    );

    ( $csecret, $salt, $user, $pw ) = (split /\n+/, $out4 )[-4,-3,-2,-1];
    chomp $user; chomp $salt; chomp $pw; chomp $csecret;
    is $user, 'admin', 'admin user received';
    like $salt, qr/\d+/, 'salt received';
    ok $csecret, 'cookiesecret provided';
    ok $pw, 'password received';
    note "adminuser supplied is '$user'";
    note "salt supplied is '$salt'";
    note "password supplied is '$pw'";
    check_pw($testpath, $user, $salt, $pw);
    check_paths($testpath);
    check_config($testpath, $salt, $csecret, $cookie);
}
