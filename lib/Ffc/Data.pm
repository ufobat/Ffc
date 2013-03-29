package Ffc::Data;

use 5.010;
use strict;
use warnings;
use File::Spec;
use File::Basename;
use utf8;
use DBI;

our $PasswordRegex = qr/\S{8,64}/xms;
our $UsernameRegex = qr/\w{4,64}/xms;
our $CategoryRegex = qr/\w{1,64}/xms;

our $DefaultConfigPath = join '/',
  File::Spec->splitdir( File::Basename::dirname(__FILE__) ), '..', '..', 'etc',
  'ffc.json';
our $Prefix         = '';
our $Fullpostnumber = 7;
our $Limit;
our $Pagelinkpreview;
our %Acttitles;
our $Title;
our $Debug = 0;
our $SessionTimeout;
our $Theme;
our @Themes;
our $Themedir = '/themes/';
our $Themebasedir =
  File::Basename::dirname(__FILE__) . '/../../public' . $Themedir;
our $DbTemplate =
  File::Basename::dirname(__FILE__) . '/../../t/var/database.sql';
our $DbTestdata =
  File::Basename::dirname(__FILE__) . '/../../t/var/testdata.sql';
our $Favicon;
our $DefaultConfig = {
    "cryptsalt"    => 1000 + int( rand 9999999 ),
    "dsn"          => "DBI:SQLite:database=",
    "user"         => "",
    "password"     => "",
    "dbprefix"     => '',
    "cookiesecret" => join( '',
        map { ( 'a' .. 'z', 'A' .. 'Z', 0 .. 9 )[ int rand 62 ] }
          ( 0 .. int( rand 128 ) ) ),
    "postlimit"       => 16,
    "pagelinkpreview" => 3,
    "sessiontimeout"  => 3600,
    "debug"           => 0,
    "acttitles"       => {
        "forum"   => 'Forum',
        "notes"   => 'Notizen',
        "msgs"    => 'Privatnachrichten',
        "auth"    => 'Anmeldung',
        "options" => 'Einstellungen',
    }
};
{
    my $dbh;
    my $config;
    my $dbconfig;
    my $cryptsalt;

    sub cryptsalt { $cryptsalt }

    sub set_config {
        my $app = shift;
        if ( -e -r ( $ENV{ASB_CONFIG} // $DefaultConfigPath ) ) {
            $config =
              $app->plugin( JSONConfig =>
                  { file => $ENV{ASB_CONFIG} // $DefaultConfigPath } );
        }
        else {
            $config =
              $app->plugin( JSONConfig => { default => $DefaultConfig } );
        }
        $app->secret( $config->{cookiesecret} );
        delete $config->{cookiesecret};
        $cryptsalt = $config->{cryptsalt};
        delete $config->{cryptsalt};

        $Prefix = $config->{dbprefix};
        die q(Prefix invalid, needs to be something like /\\w{0,10}/)
          unless $Prefix =~ m/\A\w{0,10}/xms;
        $Limit           = $config->{postlimit};
        $Pagelinkpreview = $config->{pagelinkpreview};
        $Title           = $config->{title};
        $SessionTimeout  = $config->{sessiontimeout};
        $Theme           = $config->{theme};
        $Debug           = $config->{debug};
        $Favicon         = $config->{favicon} if $config->{favicon};
        {
            opendir my $dh, $Themebasedir
              or die qq(could not open theme directory $Themebasedir: $!);
            while ( my $d = readdir $dh ) {
                next if $d =~ m/\A\./xms;
                next unless -d "$Themebasedir/$d";
                push @Themes, $d;
            }
            closedir $dh;
        }

        $dbconfig = {
            map {
                my $v = $config->{$_};
                delete $config->{$_};
                $_ => $v;
            } qw(dsn user password)
        };
        %Acttitles = (
            map( { $_ => "\u$_" } qw(auth forum notes msgs) ),
            %{ $config->{acttitles} }
        );
        return 1;
    }

    sub dbh {
        return $dbh if $dbh;
        $dbh = DBI->connect(
            $dbconfig->{dsn},
            $dbconfig->{user},
            $dbconfig->{password},
            {
                RaiseError => 1,
                AutoCommit => 1,
            }
        );
        $dbh->{'mysql_enable_utf8'} = 1;
        return $dbh;
    }
}

1;

## Please see file perltidy.ERR
