package Ffc::Options; # User
use 5.18.0;
use strict; use warnings; use utf8;

sub set_autorefresh {
    my $c = $_[0];
    my $ar = $c->param('refresh') // '';
    if ( $ar =~ m/(\d+)/xms ) {
        $ar = $1;
    }
    else {
        $c->set_error_f('Automatisches Neuladen der Seite konnte nicht geändert werden');
        return $c->redirect_to('options_form');
    }
    $c->session->{autorefresh} = $ar;
    $c->dbh_do('UPDATE "users" SET "autorefresh"=? WHERE "id"=?',
        $ar, $c->session->{userid});
    $c->set_info_f( 'Automatisches Neuladen der Seite '. (
        $ar ? 'auf '.$ar.' Minuten eingestellt' : 'deaktiviert' ) );
    $c->redirect_to('options_form');
}

my $ColorRe = qr(\A(?:|\#[0-9a-f]{6}|\w{2,128})\z)xmsio;

sub no_bg_color {
    my $c = shift;
    my $s = $c->session();
    delete $s->{backgroundcolor};
    $c->dbh_do(
        'UPDATE users SET bgcolor=? WHERE UPPER(name)=UPPER(?)',
        '', $s->{user});
    $c->set_info_f('Hintergrundfarbe zurück gesetzt');
    $c->redirect_to('options_form');
}

sub bg_color {
    my $c = shift;
    my $bgcolor = $c->param('bgcolor') // '';
    if ( $bgcolor !~ $ColorRe ) {
        $c->set_error_f('Die Hintergrundfarbe für die Webseite muss in hexadezimaler Schreibweise mit führender Raute oder als Webfarbenname angegeben werden');
        $c->set_warning_f($bgcolor);
    }
    else {
        my $s = $c->session();
        $c->dbh_do(
            'UPDATE users SET bgcolor=? WHERE UPPER(name)=UPPER(?)',
            $bgcolor, $s->{user});
        $s->{backgroundcolor} = $bgcolor;
        if ( $bgcolor ) {
            $c->set_info_f('Hintergrundfarbe angepasst');
        }
        else {
            $c->set_info_f('Hintergrundfarbe zurück gesetzt');
        }
    }
    $c->redirect_to('options_form');
}

sub set_email {
    my $c = shift;
    my $email = $c->param('email');
    my $newsmail = $c->param('newsmail') ? 1 : 0;
    my $hideemail = $c->param('hideemail') ? 1 : 0;
    unless ( $email ) {
        $c->set_info_f('Email-Adresse entfernt');
        $c->dbh_do( q~UPDATE users SET email='' WHERE id=?~, $c->session->{userid} );
        return $c->redirect_to('options_form');
    }
    if ( 1024 < length $email ) {
        $c->set_error_f('Email-Adresse darf maximal 1024 Zeichen lang sein');
        return $c->redirect_to('options_form');
    }
    unless ( $email =~ m/.+\@.+\.\w+/xmso ) {
        $c->set_error_f('Email-Adresse sieht komisch aus');
        return $c->redirect_to('options_form');
    }
    $c->dbh_do(
        'UPDATE users SET email=?, newsmail=?, hideemail=? WHERE id=?'
        , $email, $newsmail, $hideemail, $c->session->{userid});
    $c->set_info_f('Email-Adresse geändert');
    $c->redirect_to('options_form');
}

sub set_password {
    my $c = shift;
    my $opw  = $c->param('oldpw');
    my $npw1 = $c->param('newpw1');
    my $npw2 = $c->param('newpw2');

    unless ( $opw ) {
        $c->set_error_f('Altes Passwort nicht angegeben');
        return $c->redirect_to('options_form');
    }
    unless ( $npw1 and $npw2 ) {
        $c->set_error_f('Neues Passwort nicht angegeben');
        return $c->redirect_to('options_form');
    }
    if ( $npw1 ne $npw2 ) {
        $c->set_error_f('Neue Passworte stimmen nicht überein');
        return $c->redirect_to('options_form');
    }

    my $u = $c->session->{user};
    my $p = $c->hash_password($npw1);

    $c->dbh_do(
        'UPDATE users SET password=? WHERE UPPER(name)=UPPER(?) AND password=?'
        , $p, $u, $c->hash_password($opw));

    my $i = $c->dbh_selectall_arrayref(
        'SELECT COUNT(id) FROM users WHERE UPPER(name)=UPPER(?) AND password=?'
        , $u, $p)->[0]->[0];

    if ( $i ) {
        $c->set_info_f('Passwortwechsel erfolgreich');
    }
    else {
        $c->set_error_f('Passwortwechsel fehlgeschlagen')
    }

    $c->redirect_to('options_form');
}

sub set_infos {
    my $c = shift;
    my $birthdate = $c->param('birthdate') // '';
    my $infos = $c->param('infos') // '';
    my $errors = 0;
    my @msginfo;
    my @errors;
    if ( $birthdate =~ m~$Ffc::Dater~ ) {
        if ( $+{jahr}  and  not $+{jahr}  > 0  ) { $errors++ }
        if ( $+{tag}   == 0 or  $+{tag}   > 31 ) { $errors++ }
        if ( $+{monat} == 0 or  $+{monat} > 12 ) { $errors++ }
        unless ( $errors ) {
            push @msginfo, 'Geburtsdatum aktualisiert';
            if ( $+{jahr} ) { 
                $birthdate = sprintf '%04d-%02d-%02d', $+{jahr}, $+{monat}, $+{tag} 
            }
            else { 
                $birthdate = sprintf '%02d-%02d.', $+{monat}, $+{tag} 
            }
        }
    }
    elsif ( $birthdate eq '' ) {
        push @msginfo, 'Geburtsdatum entfernt';
    }
    else {
        $errors++;
    }
    if ( $errors > 0 ) {
        push @errors, qq~Geburtsdatum muss gültig sein und die Form "##.##.####" bzw. "####-##-##" haben, wobei das Jahr weggelassen werden kann.~;
        $c->flash(birthdate => $birthdate);
        $birthdate = undef;
        $errors++;
    }
    if ( $infos and 1024 < length $infos ) {
        push @errors, 'Benutzerinformationen dürfen maximal 1024 Zeichen enthalten.';
        $c->flash(infos => $infos);
        $infos = undef;
        $errors++;
    }
    else {
        push @msginfo, $infos ? 'Informationen aktualisiert' : 'Informationen entfernt';
    }
    my @params = (($birthdate//()),($infos//()));
    if ( @params ) {
        my $sql = 'UPDATE "users" SET '
                . join(', ',
                    ( defined $birthdate ? 'birthdate=?' : ()),
                    ( defined $infos     ? 'infos=?'     : ()))
                . ' WHERE "id"=?';
        $c->dbh_do($sql, @params, $c->session->{userid});
    }
    $c->set_info_f(@msginfo) if @msginfo;
    $c->set_error_f(@errors) if @errors;
    $c->redirect_to('options_form');
}

sub set_hidelastseen {
    my $c = shift;
    my $hide = $c->param('hidelastseen') ? 1 : 0;
    $c->dbh_do('UPDATE "users" SET "hidelastseen"=?, "lastonline"=NULL WHERE "id"=?', $hide, $c->session->{userid});
    $c->set_info_f($hide ? 'Letzer Online-Zeitpunkt wird versteckt': 'Letzer Online-Zeitpunkt wird für andere Benutzer angezeigt');
    $c->redirect_to('options_form');
}

1;

