use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use Testinit;

use Test::More tests => 8;
use Test::Mojo;

use DBI;
use File::Temp;
use File::Spec::Functions qw(catfile);
use Digest::SHA 'sha512_base64';

test_config();
test_config({
    cookiename => 'Ffc-Forum-NEU',
    cookiesecret => '',
    cryptsalt => '',
    postlimit => 10,
    title => 'Neues Ffc-Forum',
    sessiontimeout => 3600,
    commoncattitle => 'Allgemeines',
    urlshorten => 27,
    backgroundcolor => '#cc9933',
    fixbackgroundcolor => 1,
    favicon => 'favicon3.ico',
});

sub test_config {
    my $config_data = shift;
    my $testpath = $ENV{FFC_DATA_PATH} = File::Temp::tempdir( CLEANUP => 1 );
    generate_config($config_data);
    my $out = qx(FFC_DATA_PATH=$testpath $Testinit::Script 2>&1);
    my ( $csecret, $salt, $user, $pw ) = (split /\n+/, $out )[-4,-3,-2,-1];
    chomp $user; chomp $salt; chomp $pw; chomp $csecret;

    my $Config = do {
        use Mojolicious::Lite;
        plugin 'Ffc::Plugin::Config';
    };
    $Config->reset;

    is catfile(@{$Config->datapath()}), $testpath, 'data path ok';
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
    is_deeply $config, $Config->config(), 'config data ok';
    my $dbh = $Config->dbh();
    ok $dbh, 'database handle received';
    my $r = $dbh->selectall_arrayref(
        'SELECT name, password FROM users ORDER BY name');

    is_deeply [[$user, sha512_base64($pw, $salt)]], $r, 'database handle ok';
    return $config;
}

sub generate_config {
    my $config_data = shift or return;
    open my $fh, '>', catfile($ENV{FFC_DATA_PATH}, 'config')
        or die qq(could not write config file ).catfile($ENV{FFC_DATA_PATH}, 'config').": $!";
    print $fh "$_ = $config_data->{$_}\n"
        for sort keys %$config_data;
    close $fh;
    return 1;
}

