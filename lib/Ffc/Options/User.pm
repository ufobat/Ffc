package Ffc::Options; # User
use 5.18.0;
use strict; use warnings; use utf8;

###############################################################################
# Autorefresh-Zeiteinstellung
sub set_autorefresh {
    my $c = $_[0];
    my $ar = $c->param('refresh') // '';

    # Parameter ermitteln und prüfen
    unless ( $ar =~ m/(\d+)/xoms ) { # das so weil ich brauch den Capture
        $c->set_error_f('Zeit für das automatische Neuladen der Seite konnte nicht geändert werden');
        return $c->redirect_to('options_form');
    }
    $ar = $1;
    
    # Refresh-Zeit umsetzen
    $c->session->{autorefresh} = $ar;
    $c->dbh_do('UPDATE "users" SET "autorefresh"=? WHERE "id"=?',
        $ar, $c->session->{userid});
    $c->set_info_f( 'Zeit für das automatische Neuladen der Seite '. (
        $ar ? 'auf '.$ar.' Sekunden eingestellt' : 'deaktiviert' ) );
    $c->redirect_to('options_form');
}

###############################################################################
# Hintergrundfarbe setzen
sub bg_color {
    my $c = $_[0];
    my $bgcolor = $c->param('bgcolor') // '';

    # Eingabeprüfungen
    if ( $bgcolor !~ $Ffc::Options::ColorRe ) {
        $c->set_error_f('Die Hintergrundfarbe für die Webseite muss in hexadezimaler Schreibweise mit führender Raute oder als Webfarbenname angegeben werden');
        $c->redirect_to('options_form');
        return
    }

    # Informationsupdate
    $c->dbh_do(
        'UPDATE users SET bgcolor=? WHERE id=?', $bgcolor, $c->session->{userid});
    $c->session->{backgroundcolor} = $bgcolor;
    $c->set_info_f($bgcolor ? 'Hintergrundfarbe angepasst' : 'Hintergrundfarbe zurück gesetzt' );
    $c->redirect_to('options_form');
}

###############################################################################
# Hintergrundfarbe auf den Standard zurück setzen
sub no_bg_color {
    my $c = $_[0];
    delete $c->session->{backgroundcolor};
    $c->dbh_do(q~UPDATE users SET bgcolor='' WHERE id=?~, $c->session->{userid});
    $c->set_info_f('Hintergrundfarbe zurück gesetzt');
    $c->redirect_to('options_form');
}

###############################################################################
# Email-Adresse ändern oder zurück setzen
sub set_email {
    my $c = $_[0];
    my $email     = $c->param('email');
    my $newsmail  = $c->param('newsmail')  ? 1 : 0;
    my $hideemail = $c->param('hideemail') ? 1 : 0;

    # Eingabeprüfungen
    unless ( $email ) {
        $c->set_info_f('Email-Adresse entfernt');
        $c->dbh_do( q~UPDATE users SET email='' WHERE id=?~, $c->session->{userid} );
        return $c->redirect_to('options_form');
    }
    if ( 1024 < length $email ) {
        $c->set_error_f('Email-Adresse darf maximal 1024 Zeichen lang sein');
        return $c->redirect_to('options_form');
    }
    if ( $email !~ m/.+\@.+\.\w+/xmso ) {
        $c->set_error_f('Email-Adresse sieht komisch aus');
        return $c->redirect_to('options_form');
    }

    # Informationsupdate
    $c->dbh_do(
        'UPDATE users SET email=?, newsmail=?, hideemail=? WHERE id=?'
        , $email, $newsmail, $hideemail, $c->session->{userid});
    $c->set_info_f('Email-Adresse geändert');
    $c->redirect_to('options_form');
}

###############################################################################
# Einstellen, ob der Zeitpunkt der letzten "Sichtung" von einem selbst mitgetrackt werden soll, oder nicht
sub set_hidelastseen {
    my $c = $_[0];
    my $hide = $c->param('hidelastseen') ? 1 : 0;
    $c->dbh_do('UPDATE "users" SET "hidelastseen"=?, "lastonline"=NULL WHERE "id"=?', $hide, $c->session->{userid});
    $c->set_info_f($hide ? 'Letzer Online-Zeitpunkt wird versteckt': 'Letzer Online-Zeitpunkt wird für andere Benutzer angezeigt');
    $c->redirect_to('options_form');
}

###############################################################################
# Zusätzliche eigene Benutzerinformationen eintragen
sub set_infos {
    my $c = $_[0];
    
    # Übergebene Daten ermitteln und auswerten
    my ($birthdate, $bdmsg, $bderr) = _set_birthdate( $c );
    my ($infos,     $iomsg, $ioerr) = _set_addinfos(  $c );

    # Datenbank-Updates
    my @params = ( ($birthdate // ()), ($infos // ()) );
    if ( @params ) {
        my $sql = 'UPDATE "users" SET '
                . join( ', ',
                    ( defined $birthdate ? 'birthdate=?' : ()),
                    ( defined $infos     ? 'infos=?'     : ()),
                )
                . ' WHERE "id"=?';
        $c->dbh_do($sql, @params, $c->session->{userid});
    }

    # Benachrichtungen und Formular erzeugen
    my @msginfo = ( $bdmsg || (), $iomsg || () );
    my @errors  = ( $bderr || (), $ioerr || () );

    @msginfo and $c->set_info_f(  @msginfo );
    @errors  and $c->set_error_f( @errors  ); 

    $c->redirect_to('options_form');
}

###############################################################################
# Geburtstdatum umsetzen
sub _set_birthdate {
    my $c = $_[0];
    my $birthdate = $c->param('birthdate') || '';

    # Geburtsdatum kann hier entfernt werden
    $birthdate or return '', 'Geburtsdatum entfernt', undef;
    
    # Das angegebene Geburtstdatum passt leider nicht ins Schema
    if ( 
        ( not $birthdate =~ m~$Ffc::Dater~ )
        or ( 
               ( $+{jahr}  and  not $+{jahr}  > 0  )
            or ( $+{tag}   == 0 or  $+{tag}   > 31 )
            or ( $+{monat} == 0 or  $+{monat} > 12 ) 
        ) 
    ) {
        $c->flash(birthdate => $birthdate);
        return undef, undef, 
            qq~Geburtsdatum muss gültig sein und die Form "##.##.####" bzw. "####-##-##" haben, wobei das Jahr weggelassen werden kann.~;
    }

    # Das mit dem Geburtstdatum passt für mich, muss nur noch in Form gebracht werden
    return 
        sprintf( $+{jahr} ? '%04d-%02d-%02d' : '%02d-%02d.', $+{jahr} || (), $+{monat}, $+{tag} ),
        'Geburtsdatum aktualisiert', undef;
}

###############################################################################
# Zusatzinformationen umsetzen
sub _set_addinfos {
    my $c = $_[0];
    my $infos = $c->param('infos') || '';

    # Infos dürfen nicht zu lang sein
    if ( $infos and 1024 < length $infos ) {
        $c->flash(infos => $infos);
        return undef, undef, 'Benutzerinformationen dürfen maximal 1024 Zeichen enthalten.'; 
    }
    return $infos, 'Informationen ' . ( $infos ? 'aktualisiert' : 'entfernt' ), undef;
}

1;
