package Ffc::Pmsgs;
use 5.18.0;
use strict; use warnings; use utf8;

###############################################################################
# Die Benutzerliste kommt direkt aus dem Plugin
sub show_userlist {
    $_[0]->session->{query} = '';
    $_[0]->counting
         ->stash( queryurl => $_[0]->url_for('search_pmsgs_posts') );
    $_[0]->render(template => 'userlist');
}

###############################################################################
# Ein Benutzername wird über die User-To-Id aus privaten Nachrichten ermittelt
sub _get_username {
    my $utid = $_[0]->param('usertoid');
    my $name = $_[0]->dbh_selectall_arrayref(
        'SELECT "name" FROM "users" WHERE "id"=?', $utid);
    unless ( @$name ) {
        $_[0]->set_error( qq~Benutzername für Benutzerid "$utid" konnte nicht ermittelt werden~);
        return 'Unbekannt';
    }
    return $name->[0]->[0];
}

1;
