package Ffc::Options; # UserPassword
use 5.18.0;
use strict; use warnings; use utf8;

###############################################################################
# Passwort setzen
sub set_password {
    my $c = $_[0];

    # Eingabe des alten Passworts prüfen
    my $opw  = $c->param('oldpw');
    unless ( $opw ) {
        $c->set_error_f('Altes Passwort nicht angegeben');
        return $c->redirect_to('options_form');
    }

    # Eingaben des neuen Passworts und dessen Wiederholung prüfen
    my $npw1 = $c->param('newpw1');
    my $npw2 = $c->param('newpw2');
    unless ( $npw1 and $npw2 ) {
        $c->set_error_f('Neues Passwort nicht angegeben');
        return $c->redirect_to('options_form');
    }
    if ( $npw1 ne $npw2 ) {
        $c->set_error_f('Neue Passworte stimmen nicht überein');
        return $c->redirect_to('options_form');
    }

    # Daten für Datenbank-Aktionen vorbereiten
    my $uid = $c->session->{userid};
    my $oph = $c->hash_password($opw);
    my $pwh = $c->hash_password($npw1);

    # Gibt es den Benutzer mit dem alten Passwort in der Datenbank?
    my $i = $c->dbh_selectall_arrayref( 
        'SELECT COUNT(id) FROM users WHERE id=? AND password=?'
        , $uid, $oph)->[0]->[0];
    unless ( $i ) {
        $c->set_info_f('Fehler bei Benutzeranmeldung für den Passwortwechsel');
        return $c->redirect_to('options_form');
    }

    # Passwort-Hash in der Datenbank ändern
    $c->dbh_do( 
        'UPDATE users SET password=? WHERE id=? AND password=?'
        , $pwh, $uid, $oph );
    # Passwortänderung noch einmal prüfen, ist immerhin wichtig
    $i = $c->dbh_selectall_arrayref(
        'SELECT COUNT(id) FROM users WHERE UPPER(name)=UPPER(?) AND password=?'
        , $uid, $pwh)->[0]->[0];

    
    # Info und weg
    $c->set_info_f('Passwortwechsel ' . ( $i ? 'fehlgeschlagen' : 'erfolgreich' ) );
    $c->redirect_to('options_form');
}

1;
