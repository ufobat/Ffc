package Ffc::Pmsgs;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

sub install_routes { 
    my $l = shift;
    $l->route('/pmsgs')->via('get')
      ->to(controller => 'pmsgs', action => 'show_userlist')
      ->name('show_pmsgs_userlist');
    Ffc::Plugin::Posts::install_routes_posts($l, 'pmsgs', '/pmsgs/:userid', userid => $Ffc::Digqr);
}

sub where_select {
    my $uid = $_[0]->session->{userid};
    my $cid = $_[0]->param('userid');
    return 
        'p."userto" IS NOT NULL AND p."userfrom"<>p."userto" AND (p."userfrom"=? OR p."userto"=?) AND (p."userfrom"=? OR p."userto"=?)', 
        $uid, $uid, $cid, $cid;
}

sub lastseen { 
    return $_[0]->get_single_value(
        'SELECT "lastseen" FROM "lastseenmsgs" WHERE "userid"=? AND "userfromid"=?',
        $_[0]->session->{userid}, $_[0]->param('userid')
    );
}

sub where_modify {
    my $uid = $_[0]->session->{userid};
    my $cid = $_[0]->param('userid');
    return 
        '"userto" IS NOT NULL AND "userfrom"<>"userto" AND ("userfrom"=? OR "userto"=?) AND ("userfrom"=? OR "userto"=?)', 
        $uid, $uid, $cid, $cid;
}

sub show_userlist {
    my $c = shift;
    my $uid = $c->session->{userid};
    $c->stash( users => $c->dbh->selectall_arrayref(
        'SELECT u."id", u."name",
            (SELECT COUNT(p."id") 
                FROM "posts" p
                LEFT OUTER JOIN "lastseenmsgs" l ON l."userid"=? AND l."userfromid"=u."id"
                WHERE p."userfrom"=u."id" AND p."userto"=? AND p."id">COALESCE(l."lastseen",-1)
            ) AS "msgcount_newtome"
        FROM "users" u
        WHERE u."active"=1 AND u."id"<>? 
        GROUP BY u."id"
        ORDER BY "msgcount_newtome" DESC, UPPER(u."name") ASC',
        undef, $uid, $uid, $uid
    ) );

    $c->render(template => 'userlist');
}

sub _get_username {
    my $c = shift;
    my $name = $c->get_single_value(
        'SELECT "name" FROM "users" WHERE "id"=?', $c->param('userid'));
    unless ( $name ) {
        $c->set_error(
            'Benutzername für Benutzerid "'.($c->param('userid') // '<NULL>').'" konnte nicht ermittelt werden');
        return 'Unbekannt';
    }
    return $name;
}
sub show {
    my $c = shift;
    $c->stash(
        backurl => $c->url_for('show_pmsgs_userlist'),
        heading => 
            'Private Nachrichten mit "' . $c->_get_username . '"',
    );
    my ( $dbh, $uid, $utoid ) = ( $c->dbh, $c->session->{userid}, $c->param('userid') );
    my $lastseen = $c->get_single_value(
        'SELECT "lastseen"
        FROM "lastseenmsgs"
        WHERE "userid"=? AND "userfromid"=?',
        $uid, $utoid
    );
    $c->stash( lastseen => $lastseen // -1 );
    my $newlastseen = $c->get_single_value(
        'SELECT "id" FROM "posts" WHERE "userto"=? AND "userfrom"=? ORDER BY "id" DESC LIMIT 1',
        $uid, $utoid);
    if ( defined $lastseen ) {
        $dbh->do(
            'UPDATE "lastseenmsgs" SET "lastseen"=? WHERE "userid"=? AND "userfromid"=?',
            undef, $newlastseen, $uid, $utoid );
    }
    else {
        $dbh->do(
            'INSERT INTO "lastseenmsgs" ("userid", "userfromid", "lastseen") VALUES (?,?,?)',
            undef, $uid, $utoid, $newlastseen );
    }
    $c->show_posts();
}

sub query { $_[0]->query_posts }

sub add { $_[0]->add_post($_[0]->param('userid'), undef) }

sub edit_form {
    my $c = shift;
    $c->stash( heading => 
        'Private Nachricht mit "' . $c->_get_username . '" ändern' );
    $c->edit_post_form();
}

sub edit_do { $_[0]->edit_post_do() }

sub delete_check {
    my $c = shift;
    $c->stash( heading => 
        'Private Nachricht mit "' . $c->_get_username . '" entfernen' );
    $c->delete_post_check();
}

sub delete_do { $_[0]->delete_post_do() }

sub upload_form {
    my $c = shift;
    $c->stash( heading => 
        'Eine Datei zur privaten Nachrichten mit "' . $c->_get_username . '" anhängen' );
    $c->upload_post_form();
}

sub upload_do { $_[0]->upload_post_do() }

sub download {  $_[0]->download_post() }

sub delete_upload_check {
    my $c = shift;
    $c->stash( heading => 
        'Einen Dateianhang der privaten Nachrichten mit "' . $c->_get_username . '" löschen' );
    $c->delete_upload_post_check();
}

sub delete_upload_do { $_[0]->delete_upload_post_do() }

1;

