package Ffc::Config;
use strict;
use warnings;
use 5.010;
use DBI;
use File::Spec::Functions qw(splitdir catdir);

our @Styles = ( '/theme/normal.css', '/theme/breit.css' );

our %Defaults = (
    favicon        => '/theme/img/favicon.png',
    commoncattitle => 'Allgemein',
    title          => 'Ffc Forum',
    cookiename     => 'Ffc_Forum',
);

our %FontSizeMap = (
    -3, 0.25,
    -2, 0.5,
    -1, 0.75,
     0, 1,
     1, 1.25,
     2, 1.5,
     3, 1.75,
     4, 2,
);

our @Colors = qw(Maroon DarkRed FireBrick Red Salmon Tomato Coral OrangeRed
  Chocolate SandyBrown DarkOrange Orange DarkGoldenrod Goldenrod Gold Olive 
  Yellow YellowGreen GreenYellow Chartreuse LawnGreen Green Lime LimeGreen 
  SpringGreen MediumSpringGreen Turquoise LightSeaGreen MediumTurquoise 
  Teal DarkCyan Aqua Cyan DarkTurquoise DeepSkyBlue DodgerBlue RoyalBlue 
  Navy DarkBlue MediumBlue Blue BlueViolet DarkOrchid DarkViolet 
  Purple DarkMagenta Fuchsia Magenta MediumVioletRed DeepPink HotPink Crimson 
  Brown IndianRed RosyBrown LightCoral Snow MistyRose DarkSalmon 
  LightSalmon Sienna SeaShell SaddleBrown Peachpuff Peru Linen Bisque 
  Burlywood Tan AntiqueWhite NavajoWhite BlanchedAlmond PapayaWhip Moccasin 
  Wheat Oldlace FloralWhite Cornsilk Khaki LemonChiffon PaleGoldenrod 
  DarkKhaki Beige LightGoldenrodYellow LightYellow Ivory OliveDrab 
  DarkOliveGreen DarkSeaGreen DarkGreen ForestGreen LightGreen 
  PaleGreen Honeydew SeaGreen MediumSeaGreen Mintcream 
  MediumAquamarine Aquamarine DarkSlateGray PaleTurquoise LightCyan Azure 
  CadetBlue PowderBlue LightBlue SkyBlue LightskyBlue SteelBlue AliceBlue 
  SlateGray LightSlateGray LightsteelBlue CornflowerBlue Lavender 
  GhostWhite MidnightBlue SlateBlue DarkSlateBlue MediumSlateBlue 
  MediumPurple Indigo MediumOrchid Plum Violet Thistle Orchid 
  LavenderBlush PaleVioletRed Pink LightPink Black DimGray Gray DarkGray 
  Silver LightGray Gainsboro WhiteSmoke White);

{
    my @Datapath;
    sub Datapath {
        return @Datapath if @Datapath;
        die qq~need a directory as "FFC_DATA_PATH" environment variable ('~.($ENV{FFC_DATA_PATH}//'').q~')~
            unless $ENV{FFC_DATA_PATH} and -e -d -r $ENV{FFC_DATA_PATH};
        @Datapath = splitdir $ENV{FFC_DATA_PATH};
        return @Datapath;
    }

    my %Config;
    sub Config {
        return \%Config if %Config;
        open my $fh, '<', catdir Datapath(), 'config'
            or die q~could not open config file '~.catdir(Datapath(), 'config').qq~': $!~;
        %Config = map { m/\A\s*(\w+)\s*=\s*([^\n]*)\s*\z/xmso ? ( $1 => $2 ) : () } <$fh>;
        close $fh;
        return \%Config;
    }

    my $Dbh;
    my $DBFile;
    sub Dbh {
        return $Dbh if $Dbh;
        $DBFile = catdir Datapath(), 'database.sqlite3';
        return $Dbh = DBI->connect("DBI:SQLite:database=$DBFile", { AutoCommit => 1, RaiseError => 1 })
            or die qq~could not connect to database "$DBFile": $DBI::errstr~;
    }
}

1;

