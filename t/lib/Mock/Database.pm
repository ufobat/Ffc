package Mock::Database;
use 5.010;
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Ffc::Data;

sub prepare_testdatabase {
    setup_database();
    setup_testdata();
}

sub setup_database {
    run_sqlscript( $Ffc::Data::DbTemplate );
}

sub setup_testdata {
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
    for my $sql ( @sql ) {
        $dbh->do($sql);
    }
}

1;

