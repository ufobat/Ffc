#!/usr/bin/perl 
use 5.016;
use strict;
use warnings;
use File::Spec::Functions qw(catdir splitpath);
use File::Basename;
use File::Path qw(make_path);
use File::Copy;
use lib catfile splitdir(File::Basename::basename(__FILE__)), '..', 'lib';
use Ffc::Config;

die 'please provide a "FFC_DATA_PATH" environment variable' unless $ENV{FFC_DATA_PATH};
die '"FFC_DATA_PATH" environment variable needs to be a directory' unless -e -d $ENV{FFC_DATA_PATH};
my @BasePath = splitpath $ENV{FFC_DATA_PATH};
my $BasePath = catdir @BasePath;
my @BaseRoot = splitpath( File::Basename::basename(__FILE__), '..', 'dbpathtmpl';

my ( $uid, $gid ) = (stat($BasePath))[4,5];
say "using '$uid' as data path owner and '$gid' as data path group";

my $AvatarPath     = catdir @BasePath, 'avatars';
my $UploadPath     = catdir @BasePath, 'uploads';
my $DatabasePath   = catdir @BasePath, 'database.sqlite3';
my $DatabaseSource = catdir @BaseRoot, 'database.sqlite3';
my $ConfigPath     = catdir @BasePath, 'config';
my $ConfigSource   = catdor @BaseRoot, 'config';

for my $d ( 
    [ avatar   => $AvatarPath,   1, 0770, ''              ],
    [ upload   => $UploadPath,   1, 0770, ''              ],
    [ database => $DatabasePath, 0, 0660, $DatabaseSource ],
    [ config   => $ConfigPath,   0, 0640, $ConfigSource   ],
) {
    my $name  = $d->[0];
    my $path  = $d->[1];
    my $isdir = $d->[2];
    my $mode  = $d->[3];
    my $copy  = $d->[4];

    say "using '$path' as $name store";
    if ( -e $path ) {
        say "path '$path' as $name allready exists, asuming it to be correct";
        next;
    }

    if ( $isdir ) {
        make_path $path 
            or die qq{could not create $name path '$path': $!};
    }
    if ( $copy ) {
        copy $copy, $path
            or die qq{could not copy '$copy' to '$path': $!};
        if ( $ENV{EDITOR} ) {
            system($ENV{EDITOR}, $path) == 0
                or die qq~could not launch editor '$ENV{EDITOR}' for '$path': $?~;
        }
        else {
            say "remember to alter the config file '$path' to your needs";
        }
    }
    chown $uid, $gid, $path
        or die qq{could not chown($uid, $gid, '$path'): $!};
    chmod $mode, $path
        or die qq{could not chmod($mode, '$path'): $!};
}

say q"check user and group priviledges of the data directories and it's content!";
 
