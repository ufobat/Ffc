package Mock::Config;

use 5.010;
use strict;
use warnings;
use utf8;

use File::Temp;
use Mojo::JSON 'j';
use Data::Dumper;
use DBI;

srand;

sub r { '>>> ' . rand(10000) . ' <<<' }

sub new {
    my $class  = shift;
    my $config =  {
    configfile => '',
    dbfile   => '',
    config => {
        "cookiename"   => r(),
        "cookiesecret" => r(),
        "dsn"           => "DBI:SQLite:database=",
        "user"          => "",
        "password"      => "",
        "dbprefix"      => join( '',
            map { ( 'a' .. 'z' )[ int rand 26 ] } ( 0 .. int( rand 15 ) ) )
          . '_',
        "cryptsalt"       => int( rand 100000 ),
        "postlimit"       => int( rand 30 ),
        "favicon"         => r(),
        "title"           => r(),
        "pagelinkpreview" => int( rand 15 ),
        "sessiontimeout"  => int( rand 10000 ),
        "refreshinterval" => int( 70000 + rand 10000 ),
        "theme"           => r(),
        "commoncattitle"  => r(),
        "urlshorten"      => 32 + int( rand 20 ),
        "debug"           => 0,
        "mode"            => r(),
        "acttitles"       => {
            "forum"   => r(),
            "notes"   => r(),
            "msgs"    => r(),
            "auth"    => r(),
            "options" => r(),
        },
        "footerlinks"     => [ map { [r() => r(), r()] } 0 .. 3 + int rand 5 ],
    }};
    return bless( $config, $class )->_generate_configfile;
}

sub _generate_configfile {
    my $config = shift;
    $config->{config}->{dsn} .= $config->{dbfile} = ':memory:';
    DBI->connect($config->{config}->{dsn}, $config->{config}->{username}, $config->{config}->{password} )
      or die qq(could not create database "$config->{config}->{dsn}": ).DBI->errstr;
    ( my($cfh), $config->{configfile} ) = File::Temp::tempfile(UNLINK => 1);
    print $cfh j($config->{config});
    close $cfh;

    ( $ENV{FFC_CONFIG}, $ENV{ASB_DATABASE} ) = ( $config->{configfile}, $config->{dbfile} );
    return $config;
}

END {
    for (qw(FFC_CONFIG ASB_DATABASE)) {
        unlink $ENV{$_} if exists $ENV{$_};
    }
}

1;

