package Ffc::Admin; # AdminBoardsettings
use 5.18.0;
use strict; use warnings; use utf8;

###############################################################################
# Verschiedene Board-Einstellungen vornehmen (Schema F)
sub boardsettingsadmin {
    my $c = $_[0];
    my $optkey   = $c->param('optionkey'); # Kommt fest aus der Route, geht also nicht anders
    my $optvalue = $c->param('optionvalue') // '';

    # Einstellungs-Parameter aus der Liste selektieren
    my @setting = grep {$optkey eq $_->[0]} @Ffc::Admin::Settings;
    my ( $tit, $re, $rechk, $err, $sub ) = @{$setting[0]}[1,2,3,7,8];
    
    # Die zentrale FarbRegex steht erst zur Laufzeit zur Verfügung und kann deswegen nicht oben schon in die
    # Array-Ref beim use hinein kopiert werden, deswegen hier der Umweg über die Sub:
    'CODE' eq ref $re and $re = $re->(); 

    if ( 
           ( $rechk and $optvalue =~ $re )                          # Prüfen gegen RegEx
        or ( not $rechk and ( $optvalue eq '1' or not $optvalue ) ) # Prüfen auf Wahr/Falsch-Wert
    ) {
        # Einstellung in der Datenbank hinterlegen
        $c->dbh_do('UPDATE "config" SET "value"=? WHERE "key"=?',
            $optvalue, $optkey);
        # Einstellung in der aktuell verwendeten programminternen Konfiguration eintragen
        #$c->configdata->{$optkey} = $optvalue;
        $c->update_config_hard;
        # Eine optionale Subroutine nachschieben für die Einstellungsoption
        $sub and $sub->($c, $optkey, $optvalue);
        # Info für den Benutzer
        $c->set_info_f("$tit geändert");
    }
    else {
        $c->set_error_f($err);
    }

    $c->redirect_to('admin_options_form');
}

###############################################################################
# Optionales Thema für die Startseite setzen oder zurücksetzen (dann startet das Forum in die Themenliste)
sub set_starttopic {
    my $c = $_[0];
    my $tid = $c->param('topicid');
    $tid = 0 unless $tid; # Default == 0 == Themenliste statt Startthema auf der Startseite
    if ( $tid =~ $Ffc::Digqr ) {
        $c->dbh_do(q~UPDATE "config" SET "value"=? WHERE "key"='starttopic'~,
            $tid);
        $c->dbh_do(q~UPDATE "topics" SET "starttopic"=0~);
        $c->dbh_do(q~UPDATE "topics" SET "starttopic"=1 WHERE "id"=?~, $tid) if $tid;
        $c->configdata->{starttopic} = $tid;
        if ( $tid ) { $c->set_info_f('Startseitenthema geändert') }
        else        { $c->set_info_f('Startseitenthema zurückgesetzt') }
    }
    else {
        $c->set_error_f('Fehler beim Setzen der Startseite');
    }
    $c->redirect_to('admin_options_form');
}

1;
