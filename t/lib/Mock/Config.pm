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
        "cookiesecret" => r(),
        "dsn"           => "DBI:SQLite:database=",
        "user"          => "",
        "password"      => "",
        "dbprefix"      => join( '',
            map { ( 'a' .. 'z' )[ int rand 26 ] } ( 0 .. int( rand 15 ) ) )
          . '_',
        "cryptsalt"       => int( rand 100000 ),
        "postlimit"       => int( rand 30 ),
        "title"           => r(),
        "pagelinkpreview" => int( rand 15 ),
        "sessiontimeout"  => int( rand 10000 ),
        "theme"           => r(),
        "debug"           => 0,
        "acttitles"       => {
            "forum"   => r(),
            "notes"   => r(),
            "msgs"    => r(),
            "auth"    => r(),
            "options" => r(),
        }
    }};
    return bless( $config, $class )->_generate_configfile;
}

sub _generate_configfile {
    my $config = shift;
    ( my($dbfh), $config->{dbfile} ) = File::Temp::tempfile();
    $config->{config}->{dsn} .= $config->{dbfile};
    close $dbfh; unlink $config->{dbfile};
    DBI->connect($config->{config}->{dsn}, $config->{config}->{username}, $config->{config}->{password} )
      or die qq(could not create database "$config->{config}->{dsn}": ).DBI->errstr;
    ( my($cfh), $config->{configfile} ) = File::Temp::tempfile();
    print $cfh j($config->{config});
    close $cfh;
    ( $ENV{ASB_CONFIG}, $ENV{ASB_DATABASE} ) = ( $config->{configfile}, $config->{dbfile} );
    return $config;
}

END {
    for (qw(ASB_CONFIG ASB_DATABASE)) {
        unlink $ENV{$_} if exists $ENV{$_};
    }
}

1;

