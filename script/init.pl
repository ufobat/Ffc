#!/usr/bin/perl 
use 5.010;
use strict;
use warnings;
use File::Spec::Functions qw(catdir splitdir);
use File::Basename;
use File::Path qw(make_path);
use File::Copy;
use Digest::SHA 'sha512_base64';
use lib catdir(splitdir(File::Basename::dirname(__FILE__)), '..', 'lib');
srand;

my $uname = 'admin'; # name of initial first user
my $debug = 0;
my $cookie;

if ( @ARGV ) {
    $cookie = $ARGV[-1] if $ARGV[-1] ne '-d';
    if ( 1 < @ARGV and grep { $_ eq '-d' } @ARGV ) {
        $debug = 1;
    }
}

die 'error: please provide a cookie name as last parameter (not "-d")'
    unless $cookie;
die 'error: please provide a "FFC_DATA_PATH" environment variable'
    unless $ENV{FFC_DATA_PATH};
die 'error: "FFC_DATA_PATH" environment variable needs to be a directory'
    unless -e -d $ENV{FFC_DATA_PATH};
my @BasePath = splitdir $ENV{FFC_DATA_PATH};
my $BasePath = catdir @BasePath;
my @BaseRoot = splitdir File::Basename::dirname(__FILE__);
my @DBRoot   = ( @BaseRoot, '..', 'dbpathtmpl' );
my @FavRoot  = ( @BaseRoot, '..', 'public', 'theme', 'img' );

my ( $uid, $gid ) = (stat($BasePath))[4,5];
say "ok: using '$uid' as data path owner and '$gid' as data path group";

my $AvatarPath     = catdir @BasePath, 'avatars';
my $UploadPath     = catdir @BasePath, 'uploads';
my $FavIconSource  = catdir @FavRoot,  'favicon.png';
my $FavIconPath    = catdir @BasePath, 'favicon';
my $DatabasePath   = catdir @BasePath, 'database.sqlite3';
my $DatabaseSource = catdir @DBRoot,   'database.sqlite3';

generate_paths();

sub generate_paths {
    my $dbexists;

    for my $d ( 
        [ avatar   => $AvatarPath,   1, 0770, '',              0 ],
        [ upload   => $UploadPath,   1, 0770, '',              0 ],
        [ database => $DatabasePath, 0, 0660, $DatabaseSource, 1 ],
        [ favicon  => $FavIconPath,  0, 0660, $FavIconSource,  0 ],
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

    if ( $dbexists ) {
        say 'ok: database allready existed, no admin user created';
    }
    else {
        generate_random_security();
    }

}

sub generate_random_security {
    my $Config = do {
        use Mojolicious::Lite;
        plugin 'Ffc::Plugin::Config';
    };
    my $config = $Config->{secconfig};
    my $salt = $config->{cryptsalt};
    if ( $salt ) {
        say "ok: using preconfigured salt '$salt'";
    }
    else {
        $salt = $config->{cryptsalt} = 1000 + int rand 99999999;
        alter_configfile($Config, cryptsalt => $salt);
    }
    my $csecret = $config->{cookiesecret};
    if ( $csecret ) {
        say "ok: using preconfigured cookiesecret '$csecret'";
    }
    else {
        $csecret = $config->{cookiesecret} = generate_random(28);
        alter_configfile($Config, cookiesecret => $csecret);
    }
    alter_configfile($Config, 'cookiename', $cookie);
    my $pw = generate_random(4);
    $Config->dbh()->do(
        'INSERT INTO users (name, password, admin, active) VALUES (?,?,?,1)',
        undef, $uname, sha512_base64($pw, $salt), 1);

    if ( $debug ) {
        say 'ok: initial cookiesecret, salt, admin user and password:';
        say $csecret;
        say $salt;
    }
    else {
        say 'ok: initial admin user and password:';
    }
    say $uname;
    say $pw;
}

sub alter_configfile {
    my $config = shift;
    my $key = shift;
    my $value = shift;
    my $say = shift;
    $config->dbh()->do(
        'UPDATE "config" SET "value"=? WHERE "key"=?',
        undef, $value, $key);
}

sub generate_random {
    my $length = shift() || 4;
    my @c = ('a'..'z','A'..'Z');
    my @ca = (@c,0..9,' ',split '',q~-_()!?$%&":,.;=#*+<>/~);
    my $pw = join ''
        , map( {; $c[  int rand scalar @c  ] } 1 .. 2       )
        , map( {; $ca[ int rand scalar @ca ] } 1 .. $length )
        , map( {; $c[  int rand scalar @c  ] } 1 .. 2       );
    return $pw;
}
