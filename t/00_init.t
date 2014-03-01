use Mojo::Base -strict;

use Test::Mojo;

use 5.010;
use strict;
use warnings;

use File::Spec::Functions qw(catfile splitdir catdir);
use File::Basename;
use File::Temp;
use DBI;
use lib catdir(splitdir(File::Basename::dirname(__FILE__)), '..', 'lib');

use Test::More tests => 25;

use_ok('Ffc::Config');
use_ok('Ffc::Auth');

my $script 
    = catfile splitdir(File::Basename::dirname(__FILE__)),
        '..', 'script', 'init.pl';

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

