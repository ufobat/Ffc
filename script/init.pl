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
use Ffc::Config;
srand;

my $uname = 'admin'; # name of initial first user

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

generate_paths();

sub generate_paths {
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
        generate_random_security();
    }

}

sub generate_random_security {
    my $config = Ffc::Config::Config();
    my $salt = $config->{cryptsalt};
    if ( $salt ) {
        say "ok: using preconfigured salt '$salt'";
    }
    else {
        $salt = $config->{cryptsalt} = 1000 + int rand 99999999;
        alter_configfile(cryptsalt => $salt);
    }
    my $csecret = $config->{cookiesecret};
    if ( $csecret ) {
        say "ok: using preconfigured cookiesecret '$csecret'";
    }
    else {
        $csecret = $config->{cookiesecret} = generate_random(28);
        alter_configfile(cookiesecret => $csecret);
    }
    my $pw = generate_random(4);
    Ffc::Config::Dbh()->do(
        'INSERT INTO users (name, password, admin) VALUES (?,?,?)',
        undef, $uname, sha512_base64($pw, $salt), 1);

    say 'ok: initial admin user created with salt and password:';
    say $uname;
    say $salt;
    say $pw;
}

sub alter_configfile {
    my $key = shift;
    my $value = shift;
    my $confcont = do { 
        open my $fh, '<', $ConfigPath
            or die "error: could not read config file '$ConfigPath': $!";
        local $/;
        my $out = <$fh>;
        close $fh;
        $out;
    };
    unless ( 
        $confcont 
          =~ s~(\A|\n)(\s*$key\s*=\s*)~$1# auto generated:\n$2$value\n#$2\n~gsmx
    ) {
        $confcont .= "\n# auto generated:\n$key = $value\n";
    }

    {
        open my $fh, '>', $ConfigPath
            or die "error: could not write config file '$ConfigPath': $!";
        print $fh $confcont;
    }

    say "ok: $key set to random '$value'";
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
