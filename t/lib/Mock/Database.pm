package Mock::Database;
use 5.010;
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Test::General;
use Ffc::Data;
srand;

sub prepare_testdatabase {
    setup_database();
    setup_testdata();
}

sub setup_database {
    $ENV{ASB_CONFIG} = Test::General::test_r()
        while !$ENV{ASB_CONFIG} or -e -r $ENV{ASB_CONFIG};
    Ffc::Data::set_config(Mojolicious->new());
    run_sqlscript( $Ffc::Data::DbTemplate );
}

sub setup_testdata {
    my $dbh = Ffc::Data::dbh();
    for ( 0 .. 8 ) {
        my $short = Test::General::test_r();
        my $name = qq(Kategorie "$short");
        my $sql = qq~insert into "${Ffc::Data::Prefix}categories" ("name", "short", "sort") values ('$name', '$short', '$_')~;
        $dbh->do( $sql );
    }
    run_sqlscript( $Ffc::Data::DbTestdata );
}

sub run_sqlscript {
    my $file = shift;
    my $dbh = Ffc::Data::dbh();
    my @sql = do {
       open my $dbt, '<', $file
        or die qq(could not read database template file "$file": $!);
       local $/; 
       my $template = <$dbt>;
       close $dbt;
       $template =~ s/\${Prefix}/$Ffc::Data::Prefix/gmxs;
       split /;/, $template;
    };
    return unless @sql;
    $dbh->do( $_ ) for @sql;
}

1;

