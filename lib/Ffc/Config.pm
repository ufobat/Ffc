package Ffc;
use strict;
use warnings;
use 5.016;
use DBI;
use File::Spec qw(splitpath catdir);

{
    my @Datapath;
    sub Datapath {
        return @Datapath if @Datapath;
        die qq~need a directory as "FFC_DATA_PATH" environment variable ('~.($ENV{FFC_DATA_PATH}//'').q~')~
            unless $ENV{FFC_DATA_PATH} and -e -d -r $ENV{FFC_DATA_PATH};
        @Datapath = splitpath $ENV{FFC_DATA_PATH};
        return @Datapath;
    }

    my %Config;
    sub Config {
        return \%Config if %Config;
        open my $fh, '<', catdir Datapath(), 'config'
            or die q~could not open config file '~.catdir(Datapath(), 'config').qq~': $!~;
        %Config = map { m/\A\s*(\w+)\s*(.+?)\s*/xmso ? ( $1 => $2 ) : () } <$fh>;
        close $fh;
        return \%Config;
    }

    my $Dbh;
    my $DBFile;
    sub Dbh {
        return $Dbh if $Dbh;
        $DBFile = catdir Datapath(), 'database.sqlite3';
        return $Dbh = DBI->connect("DBI:SQLite:database=$DBFile", { AutoCommit => 1, RaiseError => 1 });
            or die qq~could not connect to database "$DBFile": $DBI::errstr~;
    }
}

1;

