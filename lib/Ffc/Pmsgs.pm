package Ffc::Pmsgs;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

use Ffc::Pmsgs::Userlist;

sub install_routes { 
    my $l = shift;
    $l->route('/pmsgs')->via('get')
      ->to(controller => 'pmsgs', action => 'show_userlist')
      ->name('show_pmsgs_userlist');
    Ffc::Plugin::Posts::install_routes_posts($l, 'pmsgs', '/pmsgs/:usertoid', usertoid => $Ffc::Digqr);
}

sub where_select {
    my $uid = $_[0]->session->{userid};
    my $cid = $_[0]->param('usertoid');
    my $sql = 'p."userto" IS NOT NULL AND p."userfrom"<>p."userto" AND (p."userfrom"=? OR p."userto"=?)';
    if ( $cid ) {
        return 
            $sql . ' AND (p."userfrom"=? OR p."userto"=?) AND (?<>?)', 
            $uid, $uid, $cid, $cid, $uid, $cid;
    }
    else {
        return $sql, $uid, $uid;
    }
}

sub where_modify {
    my $uid = $_[0]->session->{userid};
    my $cid = $_[0]->param('usertoid');
    return 
        '"userto" IS NOT NULL AND "userfrom"<>"userto" AND ("userfrom"=? OR "userto"=?) AND ("userfrom"=? OR "userto"=?) AND (?<>?)', 
        $uid, $uid, $cid, $cid, $uid, $cid;
}

sub additional_params {
    return usertoid => $_[0]->param('usertoid');
}

sub search { $_[0]->search_posts(); }

sub show {
    my $c = shift;
    $c->stash(
        backurl  => $c->url_for('show_pmsgs_userlist'),
        backtext => 'zur Benutzerliste',
        heading  => 
            'Private Nachrichten mit "' . $c->_get_username . '"',
    );
    my ( $uid, $utoid ) = ( $c->session->{userid}, $c->param('usertoid') );
    my $lastseen = $c->dbh_selectall_arrayref(
        'SELECT "lastseen"
        FROM "lastseenmsgs"
        WHERE "userid"=? AND "userfromid"=?',
        $uid, $utoid
    );
    my $newlastseen = $c->dbh_selectall_arrayref(
        'SELECT "id" FROM "posts" WHERE "userto"=? AND "userfrom"=? ORDER BY "id" DESC LIMIT 1',
        $uid, $utoid);
    $newlastseen = @$newlastseen ? $newlastseen->[0]->[0] : -1;

    if ( @$lastseen ) {
        $c->stash( lastseen => $lastseen->[0]->[0] );
        $c->dbh_do(
            'UPDATE "lastseenmsgs" SET "lastseen"=? WHERE "userid"=? AND "userfromid"=?',
            $newlastseen, $uid, $utoid );
    }
    else {
        $c->stash( lastseen => -1 );
        $c->dbh_do(
            'INSERT INTO "lastseenmsgs" ("userid", "userfromid", "lastseen") VALUES (?,?,?)',
            $uid, $utoid, $newlastseen );
    }
    $c->counting;
    $c->show_posts();
}

sub query { $_[0]->query_posts }

sub add { $_[0]->add_post($_[0]->param('usertoid'), undef) }

sub upload_form {
    my $c = shift;
    $c->counting;
    $c->stash( heading => 
        'Eine Datei zur privaten Nachrichten mit "' . $c->_get_username . '" anhängen' );
    $c->upload_post_form();
}

sub set_postlimit { $_[0]->set_post_postlimit() }

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

sub inc_highscore { $_[0]->show_posts() }
sub dec_highscore { $_[0]->show_posts() }

1;

