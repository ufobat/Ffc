package Ffc::Data;

use 5.010;
use strict;
use warnings;
use utf8;

use File::Spec;
use File::Basename;
use FindBin;
use Encode;
use DBI;
use Carp;

our $PasswordRegex = qr/.{8,64}/xmso;
our $UsernameRegex = qr/\w{4,64}/xmso;
our $CategoryRegex = qr/\w{1,64}/xmso;

our $FileBase = join '/', File::Spec->splitdir( File::Basename::dirname(__FILE__) ), '..', '..';

our $DefaultConfigPath = "$FileBase/etc/ffc.json";
our $DataDir           = 'data';
our $FileDir           = "$FileBase/$DataDir";
our $AvatarDir         = "$FileDir/avatars";
our $AvatarUrl         = "../$DataDir/avatars";
our $UploadDir         = "$FileDir/uploads";
our $UploadUrl         = "../$DataDir/uploads";
our $Themedir          = 'themes';
our $Themebasedir      = "$FileBase/public/$Themedir";
our $DbTemplate        = "$FileBase/doc/db-schemas/database_sqlite.sql";
our $DbTestdata        = "$FileBase/t/var/testdata.sql";

our $Prefix         = '';
our $Fullpostnumber = 7;
our $Limit;
our $Pagelinkpreview;
our %Acttitles;
our $Title;
our $Debug = 0;
our $SessionTimeout;
our $URLShorten = 30;
our $Theme;
our $FixTheme = 0;
our $Testing = 0;
our $RefreshInterval = 10 * 60 * 1000;
our $Footerlinks = [];
our $CommonCatTitle = 'Allgemeine Beiträge';
our $BgColor;
our $FixBgColor = 0;
our $Mode = 'development';
our $Favicon;
our @Colors = qw(Maroon DarkRed FireBrick Red Salmon Tomato Coral OrangeRed Chocolate SandyBrown DarkOrange Orange DarkGoldenrod Goldenrod Gold Olive Yellow YellowGreen GreenYellow Chartreuse LawnGreen Green Lime LimeGreen SpringGreen MediumSpringGreen Turquoise LightSeaGreen MediumTurquoise Teal DarkCyan Aqua Cyan DarkTurquoise DeepSkyBlue DodgerBlue RoyalBlue Navy DarkBlue MediumBlue Blue BlueViolet DarkOrchid DarkViolet Purple DarkMagenta Fuchsia Magenta MediumVioletRed DeepPink HotPink Crimson Brown IndianRed RosyBrown LightCoral Snow MistyRose DarkSalmon LightSalmon Sienna SeaShell SaddleBrown Peachpuff Peru Linen Bisque Burlywood Tan AntiqueWhite NavajoWhite BlanchedAlmond PapayaWhip Moccasin Wheat Oldlace FloralWhite Cornsilk Khaki LemonChiffon PaleGoldenrod DarkKhaki Beige LightGoldenrodYellow LightYellow Ivory OliveDrab DarkOliveGreen DarkSeaGreen DarkGreen ForestGreen LightGreen PaleGreen Honeydew SeaGreen MediumSeaGreen Mintcream MediumAquamarine Aquamarine DarkSlateGray PaleTurquoise LightCyan Azure CadetBlue PowderBlue LightBlue SkyBlue LightskyBlue SteelBlue AliceBlue SlateGray LightSlateGray LightsteelBlue CornflowerBlue Lavender GhostWhite MidnightBlue SlateBlue DarkSlateBlue MediumSlateBlue MediumPurple Indigo MediumOrchid Plum Violet Thistle Orchid LavenderBlush PaleVioletRed Pink LightPink Black DimGray Gray DarkGray Silver LightGray Gainsboro WhiteSmoke White); 
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
our $DefaultConfig = {
    "cryptsalt"    => 1984,
    "dsn"          => "DBI:SQLite:database=:memory:",
    "user"         => "",
    "password"     => "",
    "title"        => "Ffc",
    "dbprefix"     => '',
    "cookiename"   => 'FfcCookies',
    "cookiesecret" => 'FfcCookieSecret',
    "postlimit"       => 16,
    "pagelinkpreview" => 3,
    "sessiontimeout"  => 3600,
    "refreshinterval" => 5,
    "debug"           => 1,
    "theme"           => '',
    "fixtheme"        => '0',
    "commoncattitle"  => 'Allgemeine Beiträge',
    "backgroundcolor" => '',
    "fixbackgroundcolor" => '0',
    "mode"            => 'development',
    "acttitles"       => {
        "forum"   => 'Forum',
        "notes"   => 'Notizen',
        "msgs"    => 'Privatnachrichten',
        "auth"    => 'Anmeldung',
        "options" => 'Einstellungen',
    },
    "footerlinks" => [
        ["Projektwebseite" => "https://github.com/4FriendsForum/Ffc","Zur Projektwebseite dieser Forensoftware"],
        ["Bugtracker" => "https://github.com/4FriendsForum/Ffc/issues","zum Bug- und Issuetracker der Forensoftware"],
        ["Created with Mojolicious" => "http://mojolicio.us/","Zur Webseite des hier verwendeten Frameworks Mojolicious"],
        ["Powered by Perl" => "http://www.perl.org/","Zur Webseite der hier verwendeten Programmiersprache Perl"]
    ]
};
{
    my $dbh;
    my $dbconfig;
    my $cryptsalt;

    sub cryptsalt { $cryptsalt }

    sub set_config {
        my $app = shift;
        my $config = $ENV{FFC_CONFIG} // $DefaultConfigPath;
        if ( -e -r $config ) {
            $config =
              $app->plugin( JSONConfig => { file => $config } );
        }
        else {
            $config =
              $app->plugin( JSONConfig => { default => $DefaultConfig } );
        }
        $app->secrets( [delete $config->{cookiesecret}] );
        $app->sessions->secure($Testing ? 1 : 0);
        $cryptsalt = delete $config->{cryptsalt};

        ( $Limit, $Pagelinkpreview, $Title, $SessionTimeout, $Theme, $Debug, $Prefix, $FixBgColor, $FixTheme )
          = @{ $config }{qw(postlimit pagelinkpreview title sessiontimeout theme debug dbprefix fixbackgroundcolor fixtheme)};
        croak q(Prefix invalid, needs to be something like /\\w{0,10}/)
          unless $Prefix =~ m/\A\w{0,10}/xms;
        $BgColor         = $config->{backgroundcolor} if exists $config->{backgroundcolor};
        $Favicon         = $config->{favicon} if exists $config->{favicon};
        $Footerlinks     = $config->{footerlinks} if exists $config->{footerlinks};
        $RefreshInterval = $config->{refreshinterval} * 60 * 1000 if exists $config->{refreshinterval};
        $CommonCatTitle  = encode( 'UTF-8', $config->{commoncattitle} || $CommonCatTitle);
        $URLShorten      = $config->{urlshorten} if exists $config->{urlshorten};
        $Mode            = $config->{mode} if exists $config->{mode};
        $app->sessions->cookie_name($config->{cookiename} // 'Ffc');
        $app->mode($Mode);

        $dbconfig = {
            map {
                $_ => delete $config->{$_};
            } qw(dsn user password)
        };
        %Acttitles = (
            map( { $_ => "\u$_" } qw(auth forum notes msgs) ),
            %{ $config->{acttitles} }
        );
        $app->defaults(error => '');
        $app->defaults(info => '');
        $app->defaults( $_ => '' ) for qw(notecount newpostcount newmsgscount);
        $app->defaults( categories => [] );
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

