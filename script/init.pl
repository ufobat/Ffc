#!/usr/bin/perl 
use 5.010;
use strict;
use warnings;
use File::Spec::Functions qw(catdir splitdir);
use File::Basename;
use File::Path qw(make_path);
use File::Copy;
use lib catdir(splitdir(File::Basename::dirname(__FILE__)), '..', 'lib');
use Ffc::Config;
use Ffc::Auth;
srand;

die 'error: please provide a "FFC_DATA_PATH" environment variable'
    unless $ENV{FFC_DATA_PATH};
die 'error: "FFC_DATA_PATH" environment variable needs to be a directory'
    unless -e -d $ENV{FFC_DATA_PATH};
my @BasePath = splitdir $ENV{FFC_DATA_PATH};
my $BasePath = catdir @BasePath;
my @BaseRoot 
    = (splitdir(File::Basename::dirname(__FILE__)),'..','dbpathtmpl');

my ( $uid, $gid ) = (stat($BasePath))[4,5];
say "ok: using '$uid' as data path owner and '$gid' as data path group";

my $AvatarPath     = catdir @BasePath, 'avatars';
my $UploadPath     = catdir @BasePath, 'uploads';
my $DatabasePath   = catdir @BasePath, 'database.sqlite3';
my $DatabaseSource = catdir @BaseRoot, 'database.sqlite3';
my $ConfigPath     = catdir @BasePath, 'config';
my $ConfigSource   = catdir @BaseRoot, 'config';

my $dbexists;
for my $d ( 
    [ avatar   => $AvatarPath,   1, 0770, '',              0 ],
    [ upload   => $UploadPath,   1, 0770, '',              0 ],
    [ database => $DatabasePath, 0, 0660, $DatabaseSource, 1 ],
    [ config   => $ConfigPath,   0, 0640, $ConfigSource,   0 ],
) {
    my ( $name, $path, $isdir, $mode, $copy, $db ) = @$d;

    say "ok: using '$path' as $name store";
    if ( -e $path ) {
        say "ok: path '$path' as $name allready exists";
        $dbexists = 1 if $db;
        next;
    }

    if ( $isdir ) {
        make_path $path 
            or die qq{error: could not create $name path '$path': $!};
    }
    if ( $copy ) {
        copy $copy, $path
            or die qq{error: could not copy '$copy' to '$path': $!};
    }
    chown $uid, $gid, $path
        or die qq{error: could not chown($uid, $gid, '$path'): $!};
    chmod $mode, $path
        or die qq{error: could not chmod($mode, '$path'): $!};
}

say q"ok: check user and group priviledges of the data path!";
say "ok: remember to alter config file '$ConfigPath'";

if ( $dbexists ) {
    say 'ok: database allready existed, no admin user created';
}
else {
    my @c = ('a'..'z','A'..'Z');
    my @ca = (@c,0..9,' ',split '',q~-_()!?$%&":,.;=#*+<>/~);
    my $pw = join ''
        , map( {; $c[  int rand scalar @c  ] } 1 .. 2 )
        , map( {; $ca[ int rand scalar @ca ] } 1 .. 4 )
        , map( {; $c[  int rand scalar @c  ] } 1 .. 2 );
    Ffc::Auth::add_user('admin', $pw, 1);
    say 'ok: initial admin user created:';
    say 'admin';
    say $pw;
}

