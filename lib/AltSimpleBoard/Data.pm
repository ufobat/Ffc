package AltSimpleBoard::Data;

use 5.010;
use strict;
use warnings;
use File::Spec;
use File::Basename;
use utf8;
use DBI;
use AltSimpleBoard::Data::Board;

our $DefaultConfig = join '/',
  File::Spec->splitdir( File::Basename::dirname(__FILE__) ), '..', '..', 'etc',
  'altsimpleboard.json';
our $Prefix = '';
our $Fullpostnumber = 7;
our %Users;
our $CryptSalt;
our $Limit;
our $Pagelinkpreview;
our %Acttitles;
our $Title;
{
    my $dbh;
    my $config;

    sub set_config {
        my $app = shift;
        $config = $app->plugin(
            JSONConfig => { file => $ENV{ASB_CONFIG} // $DefaultConfig } );
        $app->secret( $config->{cookie_secret} );
        $Prefix = $config->{dbprefix};
        $CryptSalt = $config->{cryptsalt};
        $Limit = $config->{postlimit};
        $Pagelinkpreview = $config->{pagelinkpreview};
        $Title = $config->{title};
        %Users = map {
                $_->[1] => {
                    userid => $_->[0],
                    lastseen => $_->[2],
                }
            } 
            @{
                dbh()->selectall_arrayref(
                    "select id, name, lastseen from ${Prefix}users"
                    )
            };
        %Acttitles = ( map({$_ => "\u$_"} qw(auth forum notes msgs)), %{ $config->{acttitles} });
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

