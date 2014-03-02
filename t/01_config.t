use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use Testinit;

use Test::More tests => 5;
use Test::Mojo;

use DBI;
use File::Temp;
use File::Spec::Functions qw(catfile);
use Digest::SHA 'sha512_base64';

my $testpath = $ENV{FFC_DATA_PATH} = File::Temp::tempdir( CLEANUP => 1 );
my $out = qx(FFC_DATA_PATH=$testpath $Testinit::Script 2>&1);
my ( $csecret, $user, $salt, $pw ) = (split /\n+/, $out )[-4,-3,-2,-1];
chomp $user; chomp $salt; chomp $pw; chomp $csecret;

use_ok('Ffc::Config');

is catfile(Ffc::Config::Datapath()), $testpath, 'data path ok';
my $config = do {
    my %c = ();
    open my $fh, '<', catfile($testpath, 'config')
        or die "could not open config file: $!";
    while ( my $l = <$fh> ) {
        next unless $l =~ m~(?:\A|\z)\s*(\w+)\s*=\s*([^\n]*)\s*~xmso;
        $c{$1} = $2;
    }
    \%c;
};
is_deeply $config, Ffc::Config::Config(), 'config data ok';
my $dbh = Ffc::Config::Dbh();
ok $dbh, 'database handle received';
my $r = $dbh->selectall_arrayref(
    'SELECT name, password FROM users ORDER BY name');

is_deeply [[$user, sha512_base64($pw, $salt)]], $r, 'database handle ok';

