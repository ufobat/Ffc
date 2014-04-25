package Ffc::Options; # AdminCategories
use strict; use warnings; use utf8;

sub categoryadmin {
    my $c       = shift;
    my $admin   = $c->session()->{user};

    my $catid   = $c->param('catid');
    my $catname = $c->param('catname');
    my $overok  = $c->param('overwriteok');
    my $hidden  = $c->param('visible') ? 0 : 1;

    unless ( $c->session->{admin} ) {
        $c->set_error('Nur Administratoren dürfen das');
        return $c->options_form();
    }
    if ( $catid and $catid !~ m/\A$Ffc::Digqr\z/xmso ) {
        $c->set_error('Kategorieid ist ungültig');
        return $c->options_form();
    }
    if ( $catid and not $overok ) {
        $c->set_error('Der Überschreiben-Check zum Ändern einer Kategorie ist nicht gesetzt');
        return $c->options_form();
    }
    unless ( $catname and $catname =~ m/\A$Ffc::Catqr\z/xmso ) {
        $c->set_error('Kategoriename nicht angegeben');
        return $c->options_form();
    }
    unless ( $catid ) {
        my $r = $c->dbh()->selectall_arrayref(
            'SELECT id FROM categories WHERE UPPER(name)=UPPER(?)',
            undef, $catname
        );
        if ( !$r or ( 'ARRAY' eq ref($r) and @$r ) ) {
            $c->set_error('Die neue Kategorie gibt es bereits');
            return $c->options_form();
        }
    }

    if ( $catid ) {
        my $sql = 'UPDATE categories SET name=?, hidden=? WHERE id=?';
        $c->dbh()->do($sql, undef, $catname, $hidden, $catid);
        $c->set_info(qq~Kategorie "$catname" geändert~);
    }
    else {
        my $sql = 'INSERT INTO categories (name, hidden) VALUES (?,?)';
        $c->dbh()->do($sql, undef, $catname, $hidden);
        $c->set_info(qq~Kategorie "$catname" erstellt~);
    }
    $c->options_form();
}

1;


