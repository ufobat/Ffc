#!/usr/bin/perl 
use 5.18.0;
use strict;
use warnings;
use File::Spec::Functions qw(catdir splitdir);
use File::Basename;
use File::Path qw(make_path);
use File::Copy;
use Digest::SHA 'sha512_base64';
use lib catdir(splitdir(File::Basename::dirname(__FILE__)), '..', 'lib');
srand;

###############################################################################
# Einstellungen für die Initialisierung eines neuen Forums

# Default-Variablen
my $uname = 'admin'; # name of initial first user
my $debug = 0;
my $cookie;

# Wir benötigen unbedingt bestimmte Eingabe-Variablen
if ( @ARGV ) {
    $cookie = $ARGV[-1] if $ARGV[-1] ne '-d';
    if ( 1 < @ARGV and grep { $_ eq '-d' } @ARGV ) {
        $debug = 1;
    }
}

# Prüfen der übergebenen Programmvariablen
die 'error: please provide a cookie name as last parameter (not "-d")'
    unless $cookie;
die 'error: please provide a "FFC_DATA_PATH" environment variable'
    unless $ENV{FFC_DATA_PATH};
die 'error: "FFC_DATA_PATH" environment variable needs to be a directory'
    unless -e -d $ENV{FFC_DATA_PATH};

# Basispfade vorberechnen
my @BasePath = splitdir $ENV{FFC_DATA_PATH};
my $BasePath = catdir @BasePath;
my @BaseRoot = splitdir File::Basename::dirname(__FILE__);
my @DBRoot   = ( @BaseRoot, '..', 'db_template' );
my @FavRoot  = ( @BaseRoot, '..', 'public', 'theme', 'img' );

# Die Benutzer- und Gruppeninformationen der Basispfade werden automatisch zum 
# Einrichten aller anderen Dateien und Verzeichnisse verwendet!
my ( $uid, $gid ) = (stat($BasePath))[4,5];
say "ok: using '$uid' as data path owner and '$gid' as data path group";

# Sämtliche notwendige Pfade errechnen
my $AvatarPath     = catdir @BasePath, 'avatars';
my $UploadPath     = catdir @BasePath, 'uploads';
my $ChatUploadPath = catdir @BasePath, 'chatuploads';
my $FavIconSource  = catdir @FavRoot,  'favicon.png';
my $FavIconPath    = catdir @BasePath, 'favicon';
my $DatabasePath   = catdir @BasePath, 'database.sqlite3';
my $DatabaseSource = catdir @DBRoot,   'database.sqlite3';

# Gegebenenfalls die untergeordneten Pfade erstellen und mit den notwendigen
# Konfigurationsoptionen im Bedarfsfall vorbelegen
generate_paths();

###############################################################################
# Hier erstellen wir sämtliche für diese anzulegende Foren-Instanz notwendigen
# initialen Pfade und Dateien
sub generate_paths {
    my $dbexists;

    # Alle Unterverzeichnisse durchgehen
    for my $d ( 
        # Bezeichnung => Pfad, Ist ein Verzeichnis?, Dateiberechtigung, Quelldatei?, Datenbankdatei? 
        [ avatar      => $AvatarPath,     1, 0770, '',              0 ],
        [ upload      => $UploadPath,     1, 0770, '',              0 ],
        [ chatuploads => $ChatUploadPath, 1, 0770, '',              0 ],
        [ database    => $DatabasePath,   0, 0660, $DatabaseSource, 1 ],
        [ favicon     => $FavIconPath,    0, 0660, $FavIconSource,  0 ],
    ) {
        my ( $name, $path, $isdir, $mode, $copy, $db ) = @$d;

        # Es werden keine bestehenden Pfade überschrieben, um bestehende Instanzen
        # nicht ausversehen zu zerstören!
        say "ok: using '$path' as $name store";
        if ( -e $path ) {
            say "ok: path '$path' as $name allready exists";
            $dbexists = 1 if $db;
            next;
        }

        # Verzeichnisse erstellen
        if ( $isdir ) {
            make_path $path 
                or die qq{error: could not create $name path '$path': $!};
        }
        # Dateien kopieren
        if ( $copy ) {
            copy $copy, $path
                or die qq{error: could not copy '$copy' to '$path': $!};
        }

        # Berechtigungen setzen: Der Benutzer und die Gruppe, denen das Stammverzeichnis
        # gehört, werden automatisch als Benutzer und Gruppe für Unterverzeichnisse und Dateien verwendet.
        # Die Berechtigungen dieser Dateien und Verzeichnisse wird hier nach Vorgaben festgelegt
        chown $uid, $gid, $path
            or die qq{error: could not chown($uid, $gid, '$path'): $!};
        chmod $mode, $path
            or die qq{error: could not chmod($mode, '$path'): $!};
    }

    say q"ok: check user and group priviledges of the data path!";

    # Wenn die Datenbankdatei bereits existiert, wird sie nicht neu erstellt oder kopiert,
    # um bestehende Instanzen nicht aus Versehen kaputt zu machen
    if ( $dbexists ) {
        say 'ok: database allready existed, no admin user created';
    }
    # Gibt es die Datenbankdatei noch nicht, ist auch keine Konfiguration vorhanden und muss
    # erst erzeugt werden!
    else {
        generate_random_security();
    }

}

###############################################################################
# Wir belegen die Konfiguration dieser Instanz des Forums vor, unter anderem um
# eine gewisse Grundsicherheit her zu stellen
sub generate_random_security {

    # Die Konfiguration wird über die Datenbank ausgelesen, in dem wir uns eine
    # kleine Instanz des Konfig-Plugins herbei cheaten ;-)
    my $Config = do {
        use Mojolicious::Lite;
        plugin 'Ffc::Plugin::Config';
    };
    my $config = $Config->{secconfig};
    my $salt = $config->{cryptsalt};

    # Gibt es in der Datenbank bereits ein Salt für die Passwörter, wird das natürlich
    # nicht überschrieben
    if ( $salt ) {
        say "ok: using preconfigured salt '$salt'";
    }
    # Gibt es noch kein Salt (Default), wird eines angelegt und in der Konfiguration
    # in der entsprechenden Datenbankdatei hinterlegt
    else {
        $salt = $config->{cryptsalt} = 1000 + int rand 99999999;
        alter_configfile($Config, cryptsalt => $salt);
    }

    # In ähnlicher Weise wie beim Salt erstellen wir hier im Bedarfsfall ein
    # Secret für die Cookies
    my $csecret = $config->{cookiesecret};
    if ( $csecret ) {
        say "ok: using preconfigured cookiesecret '$csecret'";
    }
    else {
        $csecret = $config->{cookiesecret} = generate_random(28);
        alter_configfile($Config, cookiesecret => $csecret);
    }

    # Wir legen fest, wie unsere Cookies benannt werden sollen, da es sonst zu Konflikten
    # kommt, wenn mehrere Instanzen des Forums unter der selben Domain laufen sollen!
    # Den Namen des Cookies muss der Admin bei dieser Einstellung beim init.pl-Aufruf natürlich
    # selber mit angeben, da wir ja nicht wissen, was für Foren-Instanzen auf der Kiste alles 
    # laufen sollen - da müssten wir ja Verzeichnisse scannen oder Webserver-Konfigurationen
    # parsen, was für eine Quatsch-Idee
    alter_configfile($Config, 'cookiename', $cookie);

    # Jetzt benötigen wir noch einen Administratoren-Account, der als erster User
    # in die Datenbankdatei eingetragen wird und ein zufälliges Passwort bekommt
    # (verschlüsselt mit dem vorgegebenen Salt)
    my $pw = generate_random(4);
    $Config->_get_dbh()->do(
        'INSERT INTO users (name, password, admin, active) VALUES (?,?,?,?)',
        undef, $uname, sha512_base64($pw, $salt), 1, 1);

    # Zu debugging-Zwecken kann man sich die Sicherheitsdaten ausgeben lassen,
    # was bei uns hauptsächlich in den Tests vorkommen sollte, da ich die Informationen
    # dort an einigen Stellen brauche, um zum Beispiel "init.pl" zu testen ;-)
    if ( $debug ) {
        say 'ok: initial cookiesecret, salt, admin user and password:';
        say $csecret;
        say $salt;
    }
    # Ansonsten müssen mindestens die Infos zum Admin-Account ausgegeben werden,
    # sonst kann man sich ja nicht für die weitere Foren-Einstellungen als
    # Admin gar nicht anmelden!
    else {
        say 'ok: initial admin user and password:';
    }
    say $uname;
    say $pw;
}

###############################################################################
# Konfigdaten nachträglich ändern
sub alter_configfile {
    my $config = shift;
    my $key = shift;
    my $value = shift;
    my $say = shift;
    # Da die wichtigen und oben verwendeten Config-Einträge bereits in der Datenbank 
    # mit Default-Belegungen eingetragen sind, reicht hier ein UPDATE zu
    $config->_get_dbh()->do(
        'UPDATE "config" SET "value"=? WHERE "key"=?',
        undef, $value, $key);
}

###############################################################################
# Zufälle gibts ...
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
