use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use Testinit;

use Test::More tests => 36;
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
    urlshorten => 27,
    backgroundcolor => '#cc9933',
    fixbackgroundcolor => 1,
    favicon => 'favicon3.ico',
});

sub test_config {
    my $cookiename = Testinit::test_randstring();
    my $testpath = $ENV{FFC_DATA_PATH} = File::Temp::tempdir( CLEANUP => 1 );
    my $out = qx(FFC_DATA_PATH=$testpath $Testinit::Script -d '$cookiename' 2>&1);
    my ( $csecret, $salt, $user, $pw ) = (split /\n+/, $out )[-4,-3,-2,-1];
    chomp $user; chomp $salt; chomp $pw; chomp $csecret;

    my $Config = do {
        use Mojolicious::Lite;
        use File::Spec::Functions qw(catfile);
        my $config = plugin 'Ffc::Plugin::Config';
        any '/config'   => sub { $_[0]->render(json => $_[0]->configdata) };
        any '/datapath' => sub { $_[0]->render(text => catfile(@{$_[0]->datapath})) };
        $config;
    };
    my $t = Test::Mojo->new;
    $t->get_ok('/datapath')->status_is(200)->content_is($testpath);
    $t->get_ok('/config')
      ->status_is(200)
      ->json_hasnt('/cookiesecret')
      ->json_hasnt('/cryptsalt');

    my $dbh = $Config->dbh();
    ok $dbh, 'database handle received';
    my $config = { map {@$_} @{ 
        $dbh->selectall_arrayref(
            'SELECT "key", "value" FROM "config"'
        )
    } };
    is_deeply $config, $Config->_config(), 'config data ok';
    for my $c (qw( fixbackgroundcolor favicon
    cookiename postlimit title sessiontimeout
    urlshorten backgroundcolor)) {
        $t->json_is("/$c", $config->{$c});
    }
    my $r = $dbh->selectall_arrayref(
        'SELECT name, password FROM users ORDER BY name');

    is_deeply [[$user, sha512_base64($pw, $salt)]], $r, 'database handle ok';
    return $config;
}

sub test_configsecrets {
    my $testpath = $ENV{FFC_DATA_PATH} = File::Temp::tempdir( CLEANUP => 1 );
    my $out = qx(FFC_DATA_PATH=$testpath $Testinit::Script 2>&1);
    my ( $csecret, $salt, $user, $pw ) = (split /\n+/, $out )[-4,-3,-2,-1];
    chomp $user; chomp $salt; chomp $pw; chomp $csecret;
}

