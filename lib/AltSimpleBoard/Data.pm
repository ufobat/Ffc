package AltSimpleBoard::Data;

use 5.010;
use strict;
use warnings;
use File::Spec;
use File::Basename;
use utf8;
use DBI;

our $DefaultConfig = join '/',
  File::Spec->splitdir( File::Basename::dirname(__FILE__) ), '..', '..', 'etc',
  'altsimpleboard.json';
our $Prefix = '';
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
our $Themebasedir = File::Basename::dirname(__FILE__).'/../../public'.$Themedir;
{
    my $dbh;
    my $config;
    my $dbconfig;
    my $cryptsalt;

    sub cryptsalt { $cryptsalt }

    sub set_config {
        my $app = shift;
        $config = $app->plugin(
            JSONConfig => { file => $ENV{ASB_CONFIG} // $DefaultConfig } );
        $app->secret( $config->{cookie_secret} );
        $Prefix = $config->{dbprefix};
        die q(Prefix invalid, needs to be something like /\\w{0,10}/) unless $Prefix =~ m/\A\w{0,10}/xms;
        $Limit = $config->{postlimit};
        $Pagelinkpreview = $config->{pagelinkpreview};
        $Title = $config->{title};
        $SessionTimeout = $config->{sessiontimeout};
        $Theme = $config->{theme};
        $Debug = $config->{debug};
        {
            opendir my $dh, $Themebasedir or die qq(could not open theme directory $Themedir: $!);
            while ( my $d = readdir $dh ) {
                next if $d =~ m/\A\./xms;
                next unless -d "$Themebasedir/$d";
                push @Themes, $d;
            }
            closedir $dh;
        }

        $dbconfig = {map {
                my $v = $config->{$_};
                delete $config->{$_};
                $_ => $v;
            } qw(dsn user password)};
        $cryptsalt = $config->{cryptsalt};
        delete $config->{cryptsalt};
        delete $config->{cookie_secret};
        %Acttitles = ( map({$_ => "\u$_"} qw(auth forum notes msgs)), %{ $config->{acttitles} });
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

