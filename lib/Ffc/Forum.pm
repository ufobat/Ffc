package Ffc::Forum;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

use Ffc::Forum::Topics;
use Ffc::Forum::Readlater;
use Ffc::Forum::Printpreview;

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
    $l->route('/topic/:topicid/printpreview/ignore', topicid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'ignore_ppv_topic_do')
      ->name('ignore_ppv_forum_topic_do');
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

    # Für Email-Notification vormerken
    $l->route('/topic/:topicid/newsmail', topicid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'newsmail_topic_do')
      ->name('newsmail_forum_topic_do');
    $l->route('/topic/:topicid/nonewsmail', topicid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'unnewsmail_topic_do')
      ->name('unnewsmail_forum_topic_do');

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

    # Überschrift als gelesen (eigentlich gesehen) markieren
    $l->route('/topic/:topicid/seen', topicid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'mark_seen')
      ->name('topic_mark_seen');
    $l->route('/topic/:topicid/printpreview/seen', topicid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'ppv_mark_seen')
      ->name('topic_ppv_mark_seen');

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

    # Druckvorschau
    $l->route('/forum/printpreview')->via('get')
      ->to(controller => 'forum', action => 'printpreview')
      ->name('printpreview');
    $l->route('/forum/printpreview/:topicid', topicid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'printpreview')
      ->name('printpreview_topic');
    $l->route('/forum/set_ppv_period/:days', days => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'set_period')
      ->name('set_printpreview_period');

    # Diese Route ist der Startpunkt, um im Forum Beiträge in andere Themen zu verschieben
    # Diese Route liefert eine Liste von Themen, in die ein Beitrag verschoben werden kann
    $l->route('/topic/:topicid/move/:postid', topicid => $Ffc::Digqr, postid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'moveto_topiclist_select')->name('move_forum_topiclist');
    # Diese Route verschiebt einen Beitrag in ein anderes Thema
    $l->route('/topic/:topicid/move/:postid', topicid => $Ffc::Digqr, postid => $Ffc::Digqr)->via('post')
      ->to(controller => 'forum', action => 'moveto_topiclist_do')->name('move_forum_topiclist_do');

    # Behandlung der Später-Lesen-Liste
    $l->route('/forum/readlater/list')->via('get')
      ->to(controller => 'forum', action => 'list_readlater')
      ->name('list_readlater');
    $l->route('/forum/readlater/:topicid/mark/:postid', topicid => $Ffc::Digqr, postid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'mark_readlater')
      ->name('mark_readlater');
    $l->route('/forum/readlater/unmark/:postid')->via('get')
      ->to(controller => 'forum', action => 'unmark_readlater')
      ->name('unmark_readlater');

    # Alle Beiträge in einem Rutsch als gelesen markieren
    $l->route('/topic/mark_all_read')->via('get')
      ->to(controller => 'forum', action => 'mark_all_seen')
      ->name('mark_forum_topic_all_seen');
    
    # Standardrouten für die Beitragsbehandlung
    Ffc::Plugin::Posts::install_routes_posts($l, 'forum', '/topic/:topicid', topicid => $Ffc::Digqr);
}

sub where_select { 
    my $topicid = $_[0]->param('topicid');
    if ( $topicid ) {
        my $action = $_[0]->stash('action');
        if ( $action =~ m~\A(?:delete|edit|upload|move)~xmsio ) {
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

sub set_lastseen {
    my ( $c, $uid, $topicid ) = @_;
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
        moveurl      => 'move_forum_topiclist',
        heading      => $heading,
    );
    $c->stash( topicediturl => $c->url_for('edit_forum_topic_form', topicid => $topicid) )
        if $uid eq $userfrom or $c->session->{admin};
    $c->set_lastseen( $uid, $topicid );
    $c->counting;
    $c->show_posts();
}

sub query { $_[0]->query_posts }

sub add { my $c = shift; $c->add_post( undef, $c->param('topicid'), @_ ) }

sub edit_form {
    my $c = shift;
    $c->counting;
    $c->stash( heading => 
        'Beitrag zum Thema "' . $c->_get_title_from_topicid . '" ändern' );
    $c->edit_post_form();
}

sub edit_do { $_[0]->edit_post_do(undef, $_[0]->param('topicid')) }

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

