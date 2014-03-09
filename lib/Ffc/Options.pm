package Ffc::Options;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;

sub options_form {
    my $c = shift;
    $c->stash(act => 'options');
    $c->stash(fontsizes => \%Ffc::Plugin::Config::FontSizeMap);
    $c->stash(colors    => \@Ffc::Plugin::Config::Colors);
    if ( $c->session->{admin} ) {
        $c->stash(userlist => 
            $c->dbh->selectall_arrayref(
                'SELECT u.id, u.name, u.active, u.admin FROM users u ORDER BY u.active DESC, u.name ASC'));
    }
    else {
        $c->stash(userlist => []);
    }
    $c->render(template => 'board/optionsform');
}

sub switch_theme {
    my $c = shift;
    my $s = $c->session();
    $s->{style} = $s->{style} ? 0 : 1;
    $c->set_info('Ansicht gewechselt');
    $c->options_form();
}

sub font_size {
    my $c = shift;
    my $fs = $c->param('fontsize');
    $c->session()->{fontsize} = $fs
        if defined $c->fontsize($fs);
    $c->set_info('Schriftgröße geändert');
    $c->options_form();
}

sub no_bg_color {
    my $c = shift;
    my $s = $c->session();
    delete $s->{backgroundcolor};
    $c->dbh()->do(
        'UPDATE users SET bgcolor=? WHERE UPPER(name)=UPPER(?)',
        undef, '', $s->{user});
    $c->set_info('Hintergrundfarbe zurück gesetzt');
    $c->options_form();
}

sub bg_color {
    my $c = shift;
    unless ( $c->config()->{fixbackgroundcolor} ) {
        my $bgcolor = $c->param('bgcolor');
        my $s = $c->session();
        $c->dbh()->do(
            'UPDATE users SET bgcolor=? WHERE UPPER(name)=UPPER(?)',
            undef, $bgcolor, $s->{user});
        $s->{backgroundcolor} = $bgcolor;
        $c->set_info('Hintergrundfarbe angepasst');
    }
    $c->options_form();
}

sub set_password {
    my $c = shift;
    my $opw  = $c->param('oldpw');
    my $npw1 = $c->param('newpw1');
    my $npw2 = $c->param('newpw2');

    unless ( $opw ) {
        $c->set_error('Altes Passwort nicht angegeben');
        return $c->options_form();
    }
    unless ( $npw1 and $npw2 ) {
        $c->set_error('Neues Passwort nicht angegeben');
        return $c->options_form();
    }
    if ( $npw1 ne $npw2 ) {
        $c->set_error('Neue Passworte stimmen nicht überein');
        return $c->options_form();
    }

    my $u = $c->session->{user};
    my $p = $c->hash_password($npw1);

    $c->dbh->do(
        'UPDATE users SET password=? WHERE UPPER(name)=UPPER(?) AND password=?'
        , undef, $p, $u, $c->hash_password($opw));

    my $i = $c->dbh->selectall_arrayref(
        'SELECT COUNT(id) FROM users WHERE UPPER(name)=UPPER(?) AND password=?'
        , undef, $u, $p)->[0]->[0];

    if ( $i ) {
        $c->set_info('Passwortwechsel erfolgreich');
    }
    else {
        $c->set_error('Passwortwechsel fehlgeschlagen')
    }

    $c->options_form();
}

sub useradmin {
    my $c        = shift;
    my $admin    = $c->session()->{user};

    my $username = $c->param('username');
    my $newpw1   = $c->param('newpw1');
    my $newpw2   = $c->param('newpw2');
    my $isadmin  = $c->param('admin')  ? 1 : 0;
    my $isactive = $c->param('active') ? 1 : 0;
    my $overok   = $c->param('overwriteok');

    unless ( $c->session->{admin} ) {
        $c->set_error('Nur Administratoren dürfen dass');
        return $c->options_form();
    }
    unless ( $username ) {
        $c->set_error('Benutzername nicht angegeben');
        return $c->options_form();
    }
    if ( $newpw1 and $newpw2 and $newpw1 ne $newpw2 ) {
        $c->set_error('Passworte stimmen nicht überein');
        return $c->options_form();
    }

    my $exists = $c->dbh->selectall_arrayref(
        'SELECT COUNT(id) FROM users WHERE UPPER(name) = UPPER(?)'
        , undef, $username)->[0]->[0];

    if ( $exists and not $overok ) {
        $c->set_error('Benutzer existiert bereits, das Überschreiben-Häkchen ist allerdings nicht gesetzt');
        return $c->options_form();
    }
    unless ( $exists or $newpw1 ) {
        $c->set_error('Neuen Benutzern muss ein Passwort gesetzt werden');
        return $c->options_form();
    }

    my @pw = ( $newpw1 ? $c->hash_password($newpw1) : () );
    if ( $exists ) {
        my $sql = 'UPDATE users SET active=?, admin=?';
        $sql .= ', password=?' if @pw;
        $sql .= ' WHERE UPPER(name)=UPPER(?)';
        $c->dbh->do($sql, undef, $isactive, $isadmin, @pw, $username);
        $c->set_info(qq~Benutzer "$username" geändert~);
    }
    else {
        $c->dbh->do(
            'INSERT INTO users SET (name, password, active, admin) VALUES (?,?,?,?)'
            , undef, $username, @pw, $isactive, $isadmin);
        $c->set_info(qq~Benutzer "$username" angelegt~);
    }

    $c->options_form();
}

1;

