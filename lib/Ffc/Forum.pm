package Ffc::Forum;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

use Ffc::Forum::Topics;

sub install_routes { 
    my $l = shift;
    $l->route('/forum')->via('get')
      ->to(controller => 'forum', action => 'show_topiclist')
      ->name('show_forum_topiclist');

    # Neue Themen erstellen
    $l->route('/topic/new')->via('get')
      ->to(controller => 'forum', action => 'add_topic_form')
      ->name('add_forum_topic_form');
    $l->route('/topic/new')->via('post')
      ->to(controller => 'forum', action => 'add_topic_do')
      ->name('add_forum_topic_do');

    # Ignorieren von Überschriften
    $l->route('/topic/:topicid/ignore', topicid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'ignore_topic_do')
      ->name('ignore_forum_topic_do');
    $l->route('/topic/:topicid/unignore', topicid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'unignore_topic_do')
      ->name('unignore_forum_topic_do');

    # Pinnen (anheften oder favorisieren) von Überschriften
    $l->route('/topic/:topicid/pin', topicid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'pin_topic_do')
      ->name('pin_forum_topic_do');
    $l->route('/topic/:topicid/unpin', topicid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'unpin_topic_do')
      ->name('unpin_forum_topic_do');

    # Themenlistensortierung anpassen
    $l->route('/topic/sort/chronological')
      ->to(controller => 'forum', action => 'sort_order_chronological')
      ->name('topic_sort_chronological');
    $l->route('/topic/sort/alphabetical')
      ->to(controller => 'forum', action => 'sort_order_alphabetical')
      ->name('topic_sort_alphabetical');

    # Anzahl angezeigter Überschriften anpassen
    $l->route('/topic/limit/:topiclimit', topiclimit => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'set_topiclimit')
      ->name('topic_set_topiclimit');

    # Überschriften ändern
    $l->route('/topic/:topicid/edit', topicid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'edit_topic_form')
      ->name('edit_forum_topic_form');
    $l->route('/topic/:topicid/moveto/:topicidto', topicid => $Ffc::Digqr, topicidto => $Ffc::Digqr)
      ->via('get')
      ->to(controller => 'forum', action => 'move_topic_do')
      ->name('move_forum_topic_do');
    $l->route('/topic/:topicid/edit', topicid => $Ffc::Digqr)->via('post')
      ->to(controller => 'forum', action => 'edit_topic_do')
      ->name('edit_forum_topic_do');

    # Seitenweiterschaltung
    $l->route('/forum/:page', page => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'show_topiclist')
      ->name('show_forum_topiclist_page');
    Ffc::Plugin::Posts::install_routes_posts($l, 'forum', '/topic/:topicid', topicid => $Ffc::Digqr);
}

sub where_select { 
    my $topicid = $_[0]->param('topicid');
    if ( $topicid ) {
        my $action = $_[0]->stash('action');
        if ( $action =~ m~\A(?:delete|edit|upload)~xmsio ) {
            return 
                'p."userto" IS NULL AND p."topicid"=? AND p."userfrom"=?',
                $topicid, $_[0]->session->{userid};
        }
        return 
            'p."userto" IS NULL AND p."topicid"=?',
            $topicid;
    }
    else {
        return 'p."userto" IS NULL';
    }
}
sub where_modify {
    return
        '"userto" IS NULL AND "topicid"=? AND "userfrom"=?',
        $_[0]->param('topicid'), $_[0]->session->{userid};
}

sub additional_params {
    return topicid => $_[0]->param('topicid');
}

sub search { $_[0]->search_posts(); }

sub show_startuppage {
    if ( $_[0]->configdata->{starttopic} ) {
        $_[0]->redirect_to('show_forum', topicid => $_[0]->configdata->{starttopic});
    }
    else {
        $_[0]->show_topiclist;
    }
}

sub show {
    my $c = shift;
    my ( $uid, $topicid ) = ( $c->session->{userid}, $c->param('topicid') );
    my ( $heading, $userfrom ) = $c->_get_title_from_topicid;
    return unless $heading;
    $c->stash(
        topicid      => $topicid,
        backurl      => $c->url_for('show_forum_topiclist'),
        backtext     => 'zur Themenliste',
        msgurl       => 'show_pmsgs',
        heading      => $heading,
    );
    $c->stash( topicediturl => $c->url_for('edit_forum_topic_form', topicid => $topicid) )
        if $uid eq $userfrom or $c->session->{admin};
    my $lastseen = $c->dbh_selectall_arrayref(
        'SELECT "lastseen"
        FROM "lastseenforum"
        WHERE "userid"=? AND "topicid"=?',
        $uid, $topicid
    );
    my $newlastseen = $c->dbh_selectall_arrayref(
        'SELECT "id" FROM "posts" WHERE "userto" IS NULL AND "topicid"=? ORDER BY "id" DESC LIMIT 1',
        $topicid);
    $newlastseen = @$newlastseen ? $newlastseen->[0]->[0] : -1;
    if ( @$lastseen ) {
        $c->stash( lastseen => $lastseen->[0]->[0] );
        $c->dbh_do(
            'UPDATE "lastseenforum" SET "lastseen"=? WHERE "userid"=? AND "topicid"=?',
            $newlastseen, $uid, $topicid );
    }
    else {
        $c->stash( lastseen => -1 );
        $c->dbh_do(
            'INSERT INTO "lastseenforum" ("userid", "topicid", "lastseen") VALUES (?,?,?)',
            $uid, $topicid, $newlastseen );
    }
    $c->counting;
    $c->show_posts();
}

sub query { $_[0]->query_posts }

sub add { $_[0]->add_post( undef, $_[0]->param('topicid') ) }

sub edit_form {
    my $c = shift;
    $c->counting;
    $c->stash( heading => 
        'Beitrag zum Thema "' . $c->_get_title_from_topicid . '" ändern' );
    $c->edit_post_form();
}

sub edit_do { $_[0]->edit_post_do() }

sub delete_check {
    my $c = shift;
    $c->counting;
    $c->stash( heading => 
        'Beitrag zum Thema "' . $c->_get_title_from_topicid . '" entfernen' );
    $c->delete_post_check();
}

sub delete_do { $_[0]->delete_post_do() }

sub upload_form {
    my $c = shift;
    $c->counting;
    $c->stash( heading => 
        'Eine Datei zum Beitrag zum Thema "' . $c->_get_title_from_topicid . '" anhängen' );
    $c->upload_post_form();
}

sub set_postlimit { $_[0]->set_post_postlimit() }

sub upload_do { $_[0]->upload_post_do() }

sub download {  $_[0]->download_post() }

sub delete_upload_check {
    my $c = shift;
    $c->counting;
    $c->stash( heading => 
        'Eine Datei zum Beitrag zum Thema "' . $c->_get_title_from_topicid . '" löschen' );
    $c->delete_upload_post_check();
}

sub delete_upload_do { $_[0]->delete_upload_post_do() }

sub inc_highscore { $_[0]->inc_post_highscore() }
sub dec_highscore { $_[0]->dec_post_highscore() }

1;

