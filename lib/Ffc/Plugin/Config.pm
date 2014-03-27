package Ffc::Plugin::Config;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Plugin';

use strict;
use warnings;
use 5.010;
use DBI;
use File::Spec::Functions qw(splitdir catdir);
use Digest::SHA 'sha512_base64';

our @Styles = (
    '/theme/normal.css', 
    '/theme/breit.css',
);
our %Defaults = (
    favicon        => '/theme/img/favicon.png',
    commoncattitle => 'Allgemein',
    title          => 'Ffc Forum',
    cookiename     => 'Ffc_Forum',
    urlshorten     => 30,
    sessiontimeout => 259200,
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
our @Colors = qw(
    White Azure MintCream Ivory LightCyan Honeydew Snow LightYellow
    GhostWhite FloralWhite AliceBlue WhiteSmoke Seashell Cornsilk LightGoldenrodYellow LemonChiffon
    OldLace LavenderBlush Beige Linen PapayaWhip Aquamarine AntiqueWhite Lavender
    BlanchedAlmond PaleTurquoise MistyRose PaleGreen Bisque Moccasin PaleGoldenrod PowderBlue
    Gainsboro NavajoWhite Wheat Khaki Yellow PeachPuff GreenYellow LightGreen
    LightBlue LightGray LightSkyBlue Chartreuse SkyBlue LawnGreen Cyan Aqua
    Turquoise Pink LightSteelBlue SpringGreen Thistle MediumSpringGreen MediumTurquoise Lime
    Silver LightPink MediumAquamarine Gold BurlyWood YellowGreen DarkSeaGreen Tan
    Plum DarkKhaki DarkGray LimeGreen LightSalmon DarkTurquoise SandyBrown MediumSeaGreen
    CornflowerBlue Violet DeepSkyBlue DarkSalmon LightSeaGreen CadetBlue Goldenrod Orange
    RosyBrown HotPink LightCoral Salmon Orchid LightSlateGray Coral SteelBlue
    MediumPurple DarkOrange DodgerBlue Peru SlateGray Gray PaleVioletRed Tomato
    MediumSlateBlue OliveDrab SeaGreen DarkGoldenrod DeepPink MediumOrchid ForestGreen RoyalBlue
    OrangeRed DarkCyan IndianRed Olive SlateBlue Magenta Fuchsia Chocolate
    DimGray Teal DarkOrchid Red MediumVioletRed Crimson Green DarkOliveGreen
    BlueViolet Sienna FireBrick Brown DarkSlateGray DarkGreen DarkSlateBlue SaddleBrown
    DarkViolet DarkMagenta Purple DarkRed Maroon Blue Indigo MidnightBlue
    MediumBlue DarkBlue Navy Black
);

sub register {
    my ( $self, $app ) = @_;
    $self->reset();
    my $datapath  = $self->_datapath();
    my $config    = $self->_config();
    my $secconfig = $self->{secconfig} = {};

    $app->helper(datapath     => sub { $datapath    });
    $app->helper(dbh          => sub { $self->dbh() });
    $app->helper(configdata   => sub { $config      });
    for my $c ( qw(cookiesecret cryptsalt) ) {
        $secconfig->{$c} = $config->{$c};
        delete $config->{$c};
    }

    $app->secrets([$secconfig->{cookiesecret}]);
    $app->sessions->cookie_name(
        $config->{cookiename} || $Defaults{cookiename});
    $app->sessions->default_expiration(
        $config->{sessiontimeout} || $Defaults{sessiontimeout});

    unless ( $config->{urlshorten} and $config->{urlshorten} =~ m/\A\d+\z/xmso ) {
        $config->{urlshorten} = $Defaults{urlshorten};
    }

    $app->defaults({
        act => 'forum',
        map( {;$_.'count' => 0} qw(newmsgs newpost note) ),
        map( {;$_ => ''} qw(error info warning) ),
        map( {;$_ => $config->{$_} || $Defaults{$_}} 
            qw(favicon commoncattitle title) ),
    });

    for my $w ( qw(info error warning ) ) {
        $app->helper( "set_$w" => 
            sub { shift()->stash($w => join ' ', @_) } );
    }

    $app->helper( fontsize =>
        sub { $FontSizeMap{$_[1]} || 1 } );
    $app->helper( stylefile => 
        sub { $Styles[$_[0]->session()->{style} ? 1 : 0] } );
    $app->helper( hash_password  => 
        sub { sha512_base64 $_[1], $secconfig->{cryptsalt} } );

    $app->hook( before_render => sub { 
        my $c = $_[0];
        my $s = $c->session;
        $c->stash(fontsize => $s->{fontsize} // 0);
        $c->stash(backgroundcolor => 
            $config->{fixbackgroundcolor}
                ? $config->{backgroundcolor}
                : ( $s->{backgroundcolor} || $config->{backgroundcolor} )
        );
    });

    return $self;
}

sub _datapath {
    my $self = $_[0];
    return $self->{datapath} if $self->{datapath};
    die qq~need a directory as "FFC_DATA_PATH" environment variable ('~.($ENV{FFC_DATA_PATH}//'').q~')~
        unless $ENV{FFC_DATA_PATH} and -e -d -r $ENV{FFC_DATA_PATH};
    return $self->{datapath} = [ splitdir $ENV{FFC_DATA_PATH} ];
}

sub _config {
    my $self = $_[0];
    open my $fh, '<', catdir @{$self->_datapath()}, 'config'
        or die q~could not open config file '~.catdir(@{$self->_datapath()}, 'config').qq~': $!~;
    return { map { m/\A\s*(\w+)\s*=\s*([^\n]*)\s*\z/xmso ? ( $1 => $2 ) : () } <$fh> };
}

sub dbh {
    my $self = $_[0];
    return $self->{dbh} if $self->{dbh};
    $self->{dbfile} = catdir @{ $self->_datapath() }, 'database.sqlite3';
    return $self->{dbh} = DBI->connect("DBI:SQLite:database=$self->{dbfile}", { AutoCommit => 1, RaiseError => 1 })
        or die qq~could not connect to database "$self->{dbfile}": $DBI::errstr~;
}

sub reset {
    @{$_[0]}{qw(datapath configdata dbh dbfile)} = (undef,undef,undef,undef);
}

1;

