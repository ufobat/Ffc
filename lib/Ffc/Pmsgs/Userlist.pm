package Ffc::Pmsgs;
use strict; use warnings; use utf8;

sub show_userlist {
    my $c = shift;
    $c->counting;
    $c->session->{query} = '';
    $c->stash( queryurl => $c->url_for('search_pmsgs_posts') );
    $c->render(template => 'userlist');
}

sub _get_username {
    my $c = shift;
    my $name = $c->dbh->selectall_arrayref(
        'SELECT "name" FROM "users" WHERE "id"=?', undef, $c->param('usertoid'));
    unless ( @$name ) {
        $c->set_error(
            'Benutzername für Benutzerid "'.($c->param('usertoid') // '<NULL>').'" konnte nicht ermittelt werden');
        return 'Unbekannt';
    }
    return $name->[0]->[0];
}

1;

