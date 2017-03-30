package Ffc::Plugin::Config;
use 5.18.0;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Plugin';

use DBI;
use File::Spec::Functions qw(splitdir catdir catfile);
use Digest::SHA 'sha512_base64';

###############################################################################
# Default-Vorbelegung für bestimmte Konfigurationsvariablen
my %Defaults = (
    title           => 'Ffc Forum',
    urlshorten      => 30,
    inlineimage     => 0,
    sessiontimeout  => 259200,
    backgroundcolor => '',
    starttopic      => 0,
    starttopiccount => 0,
    maxscore        => 10,
    cookiename      => 'ffc_cookie',
    chatloglength   => 50,
);

###############################################################################
# Plugin-Registrierung für Konfigurationshelper
sub register {
    my ( $self, $app ) = @_;
    $self->_reset_envconfig();

    # Variablenvorbelegung für weitere Verwendung
    my $datapath  = $self->_get_datapath();  # Pfad zu den Daten
    my $dbh       = $self->_get_dbh();       # Datenbankhandle
    my $config    = {%Defaults};
    my $secconfig = $self->{secconfig} = {}; # Besonders gesicherte Konfigurationseinstellungen

    # Sicherheitsrelevante Einstellungen werden aus der normalen Konfiguration heraus gelöscht
    # und stehen nur noch innerhalb dieser Subroutine zur Verfügung
    my $gotconfig = 0;
    my $get_config = sub {
        return if $gotconfig and not $_[0];
        $config = { map { @$_ } 
            @{ $self->{dbh}->selectall_arrayref(
                'SELECT "key", "value" FROM "config"') } };
        $secconfig->{$_} = delete $config->{$_} for qw(cookiesecret cryptsalt);
        $gotconfig = 1;
        return $config;
    };

    $get_config->();
    $app->secrets([$secconfig->{cookiesecret}]);
    $app->sessions->cookie_name(
        $config->{cookiename} || $Defaults{cookiename});
    $app->sessions->default_expiration(
        $config->{sessiontimeout} || $Defaults{sessiontimeout});
    # Session-Einstellungen
    

    # Konfigurierte Voreinstellungen, falls bei diesen Parametern nichts brauchbares angegeben ist
    for ( qw(urlshorten starttopic starttopiccount inlineimage chatloglength) ) {
        unless ( $config->{$_} and $config->{$_} =~ m/\A\d+\z/xmso ) {
            $config->{$_} = $Defaults{$_};
        }
    }

    # Konfigurationshelper
    $app->helper(datapath            => sub { $datapath }      );
    $app->helper(configdata          => $get_config            );
    $app->helper(data_return         => \&_data_return         );
    $app->helper(user_session_config => \&_user_session_config );

    $app->helper(update_config       => sub { $get_config->($_[1]) } );

    # Datenbankhelper
    $app->helper(dbh                    => sub{ $dbh }               );
    $app->helper(dbh_selectall_arrayref => \&_dbh_selectall_arrayref );
    $app->helper(dbh_do                 => \&_dbh_do                 );

    # Besondere Default-Werte
    for ( qw(title backgroundcolor) ) {
        $config->{$_} ||= $Defaults{$_};
    }

    # Default-Vorbelegungen für Template-Variablen
    $app->defaults({
        configdata      => $config,
        page            => 1,
        lastseen        => -1,
        starttopic      => 0,
        starttopiccount => 0,
        map( {; $_ => undef }
            qw(postid topicid) ),
        map( {; $_ => [] }
            qw(additional_params topics users attachements chat_users topicchanges pmsgschanges) ),
        map( {;$_.'count' => 0} 
            qw(newmsgs newpost note readlater chatotherscnt) ),
        map( {;$_ => ''} 
            qw(error info warning query textdata heading description backtext queryurl 
               pageurl queryreset dourl returl editurl moveurl msgurl delurl uplurl 
               delupl downld backurl topicediturl fetchnewurlfocused fetchnewurlunfocused
               isinchat menulinktarget menulinkdisplay) ),
    });

    # Benutzer-Benachrichtigungs-Helper
    for my $w ( qw(info error warning ) ) {
        $app->helper( "set_$w" => 
            sub { $_[0]->stash($w => join ' ', ($_[0]->stash($w) // ()), @_[1 .. $#_]); $_[0] } );
        $app->helper( "set_${w}_f" => 
            sub { $_[0]->flash($w => join ' ', ($_[0]->stash($w) // ()), @_[1 .. $#_]); $_[0] } );
    }

    # Helper für verschlüsselte Passwortprüfung
    $app->helper( hash_password  => 
        sub { sha512_base64 $_[1], $secconfig->{cryptsalt} } );

    return $self;
}

###############################################################################
# Sessionabhängige Konfigurationen setzen
sub _user_session_config {
    my ( $c, $top, $conf, $def, $set ) = @_;
    my $s = $c->session; my $userid = $s->{userid};

    # Datenstruktur vorbereiten
    if ( ( not exists $s->{$top} ) or ( 'HASH' ne ref $s->{$top} ) ) {
        $s->{$top} = {$userid => {$conf => $def } };
    }
    elsif ( ( not exists $s->{$top}->{$userid} ) or ( 'HASH' ne ref $s->{$top}->{$userid} ) ) {
        $s->{$top}->{$userid} = {$conf => $def};
    }
    elsif ( ( not exists $s->{$top}->{$userid}->{$conf} ) or ( '' ne ref $s->{$top}->{$userid}->{$conf} ) ) {
        $s->{$top}->{$userid}->{$conf} = $def;
    }

    # Set oder Get
    if   ( defined $set ) { $s->{$top}->{$userid}->{$conf} = $set }
    else                  { $set = $s->{$top}->{$userid}->{$conf} }
    return $s->{$conf} = $set;
}

###############################################################################
# Datenpfad zurück geben, und bei Bedarf ermitteln
sub _get_datapath {
    $_[0]->{datapath} and return $_[0]->{datapath};
    die qq~need a directory as "FFC_DATA_PATH" environment variable ('~.($ENV{FFC_DATA_PATH}//'').q~')~
        unless $ENV{FFC_DATA_PATH} and -e -d -r $ENV{FFC_DATA_PATH};
    return $_[0]->{datapath} = [ splitdir $ENV{FFC_DATA_PATH} ];
}

###############################################################################
# Konfigurationsdaten aus der Datenbank ermitteln
sub _get_config {
    return { map { @$_ } 
        @{ $_[0]->{dbh}->selectall_arrayref(
            'SELECT "key", "value" FROM "config"') } };
}

###############################################################################
# Datenbank-Handle erzeugen
sub _get_dbh {
    return $_[0]->{dbh} if $_[0]->{dbh};
    my $self = $_[0];
    $self->{dbfile} = catdir @{ $self->_get_datapath() }, 'database.sqlite3';
    $self->{dbh} = DBI->connect("DBI:SQLite:database=$self->{dbfile}", 
        '', '', { AutoCommit => 1, RaiseError => 1 })
        or die qq~could not connect to database "$self->{dbfile}": $DBI::errstr~;
    $self->{dbh}->{sqlite_unicode} = 1;
    return $self->{dbh};
}

###############################################################################
# Konfig für die Instanz-Umgebung zurücksetzen
sub _reset_envconfig {
    @{$_[0]}{qw(datapath dbh dbfile)} = (undef,undef,undef);
}

###############################################################################
# Datenbank-Handling inkl. Caching von Prepared-Statements
{
    my %sths;
###############################################################################
# SELECT mit Datenrückgabe
    sub _dbh_selectall_arrayref {
        my $c = shift; my $sql = shift;
        my $sth = exists $sths{$sql}
            ? $sths{$sql}
            : $sths{$sql} = $c->dbh->prepare($sql)
                || die $sths{$sql}->errstr;
#        my $sth = $c->dbh->prepare($sql) || die $sths{$sql}->errstr;
        $sth->execute( @_ ) or die $sth->errstr;
#        return $sth->fetchall_arrayref || die $sth->errstr;
        my $r = $sth->fetchall_arrayref || die $sth->errstr;
        $sth->finish();
        return $r;
    }

###############################################################################
# SQL-Abfrage ohne Datenrückgabe
    sub _dbh_do {
        my $c = shift; my $sql = shift;
        my $sth = exists $sths{$sql}
            ? $sths{$sql}
            : $sths{$sql} = $c->dbh->prepare($sql)
                || die $sths{$sql}->errstr;
#        my $sth = $c->dbh->prepare($sql) || die $sths{$sql}->errstr;
        $sth->execute( @_ ) or die $sth->errstr;
        $sth->finish;
    }
}

1;
