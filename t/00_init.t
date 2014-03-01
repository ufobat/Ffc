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

use Test::More tests => 37;

use_ok('Ffc::Config');
use_ok('Ffc::Auth');

my $script = $Testinit::Script;
note "testing init script '$script'";

my $testpath = File::Temp::tempdir( CLEANUP => 1 );

note "using path '$testpath' for tests";
my $pw = '';
sub check_pw {
    local $ENV{FFC_DATA_PATH} = $testpath;
    is(DBI->connect(
        "DBI:SQLite:database=$testpath/database.sqlite3"
        ,'','',{AutoCommit => 1, RaiseError => 1})
       ->selectall_arrayref(
        'SELECT COUNT(id) FROM users WHERE name=? AND password=?'
        , undef, 'admin', Ffc::Auth::password($pw))
       ->[0]->[0], 1, 'admin password ok');
}

my $out1 = qx($script 2>&1);
like $out1,
    qr'error: please provide a "FFC_DATA_PATH" environment variable',
    'error message for env var ok';

my $out2 = qx(FFC_DATA_PATH=$testpath $script 2>&1);
like $out2, $_, 'first run content ok' for (
    qr~ok: using '\d+' as data path owner and '\d+' as data path group~,
    qr~ok: using '$testpath/avatars' as avatar store~,
    qr~ok: using '$testpath/uploads' as upload store~,
    qr~ok: using '$testpath/database\.sqlite3' as database store~,
    qr~ok: using '$testpath/config' as config store~,
    qr~ok: check user and group priviledges of the data path!~,
    qr~ok: remember to alter config file '$testpath/config'~,
    qr~ok: initial admin user created:~,
);
$pw = (split /\n+/, $out2 )[-1];
chomp $pw;
note "password supplied is '$pw'";
check_pw();

my $out3 = qx(FFC_DATA_PATH=$testpath $script 2>&1);
like $out3, $_, 'second run content ok' for (
    qr~ok: using '\d+' as data path owner and '\d+' as data path group~,
    qr~ok: using '$testpath/avatars' as avatar store~,
    qr~ok: path '$testpath/avatars' as avatar allready exists~,
    qr~ok: using '$testpath/uploads' as upload store~,
    qr~ok: path '$testpath/uploads' as upload allready exists~,
    qr~ok: using '$testpath/database\.sqlite3' as database store~,
    qr~ok: path '$testpath/database\.sqlite3' as database allready exists~,
    qr~ok: using '$testpath/config' as config store~,
    qr~ok: path '$testpath/config' as config allready exists~,
    qr~ok: check user and group priviledges of the data path!~,
    qr~ok: remember to alter config file '$testpath/config'~,
    qr~ok: database allready existed, no admin user created~,
);
check_pw();

for my $path ( 
    [ qq'$testpath/avatars',          1 ],
    [ qq'$testpath/uploads',          1 ],
    [ qq'$testpath/database.sqlite3', 0 ],
    [ qq'$testpath/config',           0 ],
) {
    my ( $p, $d ) = @$path;
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


