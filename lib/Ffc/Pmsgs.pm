package Ffc::Pmsgs;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

sub install_routes { 
    my $l = shift;
    $l->route('/pmsgs/query')->via('post')
      ->to(controller => 'pmsgs', action => 'query_userlist')
      ->name('query_pmsgs_userlist');
    $l->route('/pmsgs')->via('get')
      ->to(controller => 'pmsgs', action => 'show_userlist')
      ->name('show_pmsgs_userlist');
    Ffc::Plugin::Posts::install_routes_posts($l, 'pmsgs', '/pmsgs/:userid', userid => $Ffc::Digqr);
}

sub additional_params { return $_[0]->param('userid') }

sub where_select {
    my $uid = $_[0]->session->{userid};
    my $cid = $_[0]->param('userid');
    return 
        'p."userto" IS NOT NULL AND p."userfrom"<>p."userto" AND (p."userfrom"=? OR p."userto"=?) AND (p."userfrom"=? OR p."userto"=?)', 
        $uid, $uid, $cid, $cid;
}

sub where_modify {
    my $uid = $_[0]->session->{userid};
    my $cid = $_[0]->param('userid');
    return 
        '"userto" IS NOT NULL AND "userfrom"<>"userto" AND ("userfrom"=? OR "userto"=?) AND ("userfrom"=? OR "userto"=?)', 
        $uid, $uid, $cid, $cid;
}

sub query_userlist {
    my $c = shift;
    $c->session->{query} = $c->param('query');
    $c->show_userlist;
}

sub show_userlist {
    my $c = shift;
    $c->stash(queryurl => $c->url_for('query_pmsgs_userlist'));
    my $uid = $c->session->{userid};
    $c->stash( users => $c->dbh->selectall_arrayref(
        'SELECT u."id", u."name", COUNT(pn."id") AS "msgcount_new", COUNT(po."id") AS "msgcount_other", COUNT(pm."id") AS "msgcount_me" 
        FROM "users" u
        LEFT OUTER JOIN "posts" po ON po."userfrom"=u."id" AND po."userto"=?
        LEFT OUTER JOIN "posts" pm ON pm."userto"=u."id" AND pm."userfrom"=?
        LEFT OUTER JOIN "lastseenmsgs" l ON l."userfromid"=u."id" AND l."userid"=?
        LEFT OUTER JOIN "posts" pn ON pn."userfrom"=u."id" AND pn."userto"=? AND pn."id">COALESCE(l."lastseen",0)
        WHERE u."active"=1 AND u."id"<>? 
        GROUP BY u."id"
        ORDER BY "msgcount_new" DESC, UPPER(u."name") ASC',
        undef, $uid, $uid, $uid, $uid, $uid
    ) );
    $c->render(template => 'userlist');
}

sub _get_username {
    my $c = shift;
    my $name = $c->dbh->selectall_arrayref(
        'SELECT "name" FROM "users" WHERE "id"=?', undef, $c->param('userid'));
    unless ( $name and 'ARRAY' eq ref($name) and @$name ) {
        $c->set_error(
            'Benutzername für Benutzerid "'.($c->param('userid') // '<NULL>').'" konnte nicht ermittelt werden');
        return 'Unbekannt';
    }
    return $name->[0]->[0];
}
sub show {
    my $c = shift;
    $c->stash(backurl => $c->url_for('show_pmsgs_userlist'));
    $c->stash( heading => 
        'Private Nachrichten mit Benutzer "' . $c->_get_username . '"' );
    my ( $dbh, $uid, $utoid ) = ( $c->dbh, $c->session->{userid}, $c->param('userid') );
    my $lastseen = $dbh->selectall_arrayref(
        'SELECT "lastseen"
        FROM "lastseenmsgs"
        WHERE "userid"=? AND "userfromid"=?',
        undef, $uid, $utoid
    );
    $lastseen = $lastseen && 'ARRAY' eq ref($lastseen) && @$lastseen ? $lastseen->[0]->[0] : undef;
    $c->stash( lastseen => $lastseen // -1 );
    my $newlastseen = $dbh->selectall_arrayref(
        'SELECT "id" FROM "posts" WHERE "userto"=? AND "userfrom"=? ORDER BY "id" DESC LIMIT 1',
        undef, $uid, $utoid);
    $newlastseen = $newlastseen && 'ARRAY' eq ref($newlastseen) && @$newlastseen 
        ? $newlastseen->[0]->[0] : -1;
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
        'Private Nachrichten mit Benutzer "' . $c->_get_username . '" ändern' );
    $c->edit_post_form();
}

sub edit_do { $_[0]->edit_post_do() }

sub delete_check {
    my $c = shift;
    $c->stash( heading => 
        'Private Nachrichten mit Benutzer "' . $c->_get_username . '" entfernen' );
    $c->delete_post_check();
}

sub delete_do { $_[0]->delete_post_do() }

sub upload_form {
    my $c = shift;
    $c->stash( heading => 
        'Eine Datei zur privaten Nachrichten mit Benutzer "' . $c->_get_username . '" anhängen' );
    $c->upload_post_form();
}

sub upload_do { $_[0]->upload_post_do() }

sub download {  $_[0]->download_post() }

sub delete_upload_check {
    my $c = shift;
    $c->stash( heading => 
        'Einen Dateianhang der privaten Nachrichten mit Benutzer "' . $c->_get_username . '" löschen' );
    $c->delete_upload_post_check();
}

sub delete_upload_do { $_[0]->delete_upload_post_do() }

1;

