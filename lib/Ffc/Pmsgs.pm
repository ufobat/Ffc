package Ffc::Pmsgs;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

sub install_routes { 
    my $l = shift;
    $l->route('/pmsgs')->via('get')
      ->to(controller => 'pmsgs', action => 'show_userlist')
      ->name('show_pmsgs_userlist');
    $l->route('/pmsgs/search')->via('post')
      ->to(controller => 'pmsgs', action => 'search')
      ->name('search_pmsgs_posts');
    Ffc::Plugin::Posts::install_routes_posts($l, 'pmsgs', '/pmsgs/:userid', userid => $Ffc::Digqr);
}

sub where_select {
    my $uid = $_[0]->session->{userid};
    my $cid = $_[0]->param('userid');
    my $sql = 'p."userto" IS NOT NULL AND p."userfrom"<>p."userto" AND (p."userfrom"=? OR p."userto"=?)';
    if ( $cid ) {
        return 
            $sql . ' AND (p."userfrom"=? OR p."userto"=?)', 
            $uid, $uid, $cid, $cid;
    }
    else {
        return $sql, $uid, $uid;
    }
}

sub where_modify {
    my $uid = $_[0]->session->{userid};
    my $cid = $_[0]->param('userid');
    return 
        '"userto" IS NOT NULL AND "userfrom"<>"userto" AND ("userfrom"=? OR "userto"=?) AND ("userfrom"=? OR "userto"=?)', 
        $uid, $uid, $cid, $cid;
}

sub additional_params {
    return userid => $_[0]->param('userid');
}

sub search { 
    $_[0]->stash( queryurl => $_[0]->url_for('search_forum_posts') );
    $_[0]->search_posts;
}

sub show_userlist {
    my $c = shift;
    $c->counting;
    $c->session->{query} = '';
    $c->stash( queryurl => $c->url_for('search_forum_posts') );
    $c->render(template => 'userlist');
}

sub _get_username {
    my $c = shift;
    my $name = $c->dbh->selectall_arrayref(
        'SELECT "name" FROM "users" WHERE "id"=?', undef, $c->param('userid'));
    unless ( @$name ) {
        $c->set_error(
            'Benutzername für Benutzerid "'.($c->param('userid') // '<NULL>').'" konnte nicht ermittelt werden');
        return 'Unbekannt';
    }
    return $name->[0]->[0];
}

sub show {
    my $c = shift;
    $c->counting;
    $c->stash(
        backurl  => $c->url_for('show_pmsgs_userlist'),
        backtext => 'zur Benutzerliste',
        heading  => 
            'Private Nachrichten mit "' . $c->_get_username . '"',
    );
    my ( $dbh, $uid, $utoid ) = ( $c->dbh, $c->session->{userid}, $c->param('userid') );
    my $lastseen = $dbh->selectall_arrayref(
        'SELECT "lastseen"
        FROM "lastseenmsgs"
        WHERE "userid"=? AND "userfromid"=?',
        undef, $uid, $utoid
    );
    my $newlastseen = $dbh->selectall_arrayref(
        'SELECT "id" FROM "posts" WHERE "userto"=? AND "userfrom"=? ORDER BY "id" DESC LIMIT 1',
        undef, $uid, $utoid);
    $newlastseen = @$newlastseen ? $newlastseen->[0]->[0] : -1;

    if ( @$lastseen ) {
        $c->stash( lastseen => $lastseen->[0]->[0] );
        $dbh->do(
            'UPDATE "lastseenmsgs" SET "lastseen"=? WHERE "userid"=? AND "userfromid"=?',
            undef, $newlastseen, $uid, $utoid );
    }
    else {
        $c->stash( lastseen => -1 );
        $dbh->do(
            'INSERT INTO "lastseenmsgs" ("userid", "userfromid", "lastseen") VALUES (?,?,?)',
            undef, $uid, $utoid, $newlastseen );
    }
    $c->show_posts();
}

sub query { $_[0]->query_posts }

sub add { $_[0]->add_post($_[0]->param('userid'), undef) }

=pod

=head1 das folgende brauchen wir bei privatnachrichten nicht!!!

sub edit_form {
    my $c = shift;
    $c->counting;
    $c->stash( heading => 
        'Private Nachricht mit "' . $c->_get_username . '" ändern' );
    $c->edit_post_form();
}

sub edit_do { $_[0]->edit_post_do() }

sub delete_check {
    my $c = shift;
    $c->counting;
    $c->stash( heading => 
        'Private Nachricht mit "' . $c->_get_username . '" entfernen' );
    $c->delete_post_check();
}

sub delete_do { $_[0]->delete_post_do() }

=cut

sub upload_form {
    my $c = shift;
    $c->counting;
    $c->stash( heading => 
        'Eine Datei zur privaten Nachrichten mit "' . $c->_get_username . '" anhängen' );
    $c->upload_post_form();
}

sub upload_do { $_[0]->upload_post_do() }

sub download {  $_[0]->download_post() }

sub delete_upload_check {
    my $c = shift;
    $c->counting;
    $c->stash( heading => 
        'Einen Dateianhang der privaten Nachrichten mit "' . $c->_get_username . '" löschen' );
    $c->delete_upload_post_check();
}

sub delete_upload_do { $_[0]->delete_upload_post_do() }

1;

