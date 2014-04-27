package Ffc::Options; # AdminUser
use strict; use warnings; use utf8;

sub useradmin {
    my $c        = shift;
    my $admin    = $c->session()->{user};

    my $username = $c->param('username');
    my $newpw1   = $c->param('newpw1');
    my $newpw2   = $c->param('newpw2');
    my $isadmin  = $c->param('admin')  ? 1 : 0;
    my $isactive = $c->param('active') ? 1 : 0;
    my $overok   = $c->param('overwriteok');

    unless ( $username ) {
        $c->set_error('Benutzername nicht angegeben');
        return $c->options_form();
    }
    if ( $username !~ m/\A$Ffc::Usrqr\z/xmso) {
        $c->set_error('Benutzername passt nicht (muss zwischen 2 und 32 Buchstaben haben)');
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
    unless ( $exists or ( $newpw1 and $newpw2 ) ) {
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
            'INSERT INTO users (name, password, active, admin) VALUES (?,?,?,?)'
            , undef, $username, @pw, $isactive, $isadmin);
        $c->set_info(qq~Benutzer "$username" angelegt~);
    }

    $c->options_form();
}

1;

