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
our $PhpBBPath = '';
our $Prefix = '';
our $PhpBBPrefix = '';
our $PhpBBURL = '';
our $SmiliePath = '';
{
    my $dbh;
    my $config;

    sub set_config {
        my $app = shift;
        $config = $app->plugin(
            JSONConfig => { file => $ENV{ASB_CONFIG} // $DefaultConfig } );
        $app->secret( $config->{cookie_secret} );
        $Prefix = $config->{dbprefix};
        $PhpBBPrefix = $config->{phpbbprefix};
        $PhpBBPath = $config->{phpbbpath};
        $PhpBBURL = $config->{phpbburl};
        $SmiliePath = dbh()->selectrow_arrayref("select config_value from ${PhpBBPrefix}config where config_name='smilies_path'")->[0];
    }

    sub dbh {
        return $dbh if $dbh;
        $dbh = DBI->connect(
            $config->{dsn},
            $config->{user},
            $config->{password},
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

