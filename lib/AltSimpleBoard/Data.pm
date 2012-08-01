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
our $AvatarSalt = '';
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
        $AvatarSalt = dbh()->selectrow_arrayref(
            'SELECT config_value FROM '.$AltSimpleBoard::Data::PhpBBPrefix.'config WHERE config_name=?'
            , undef, 'avatar_salt')->[0];
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

