package Ffc::Forum;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

sub install_routes { 
    my $l = shift;
    $l->route('/forum')->via('get')
      ->to(controller => 'forum', action => 'show_topiclist')
      ->name('show_forum_topiclist');
    $l->route('/topic/new')->via('get')
      ->to(controller => 'forum', action => 'add_topic_form')
      ->name('add_forum_topic_form');
    $l->route('/topic/new')->via('post')
      ->to(controller => 'forum', action => 'add_topic_do')
      ->name('add_forum_topic_do');
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
    $l->route('/forum/:page', page => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'show_topiclist')
      ->name('show_forum_topiclist_page');
    Ffc::Plugin::Posts::install_routes_posts($l, 'forum', '/topic/:topicid', topicid => $Ffc::Digqr);
}

sub where_select { 
    return 
        'p."userto" IS NULL AND p."topicid"=?',
        $_[0]->param('topicid');
}
sub where_modify {
    return
        '"userto" IS NULL AND "topicid"=?',
        $_[0]->param('topicid');
}

sub lastseen { 
    my $c = shift;
    my $r = $c->dbh->selectall_arrayref(
        'SELECT "lastseen" FROM "lastseenforum" WHERE "userid"=? AND "topicid"=?',
        undef, $c->session->{userid}, $c->param('topicid')
    );
    return @$r ? $r->[0]->[0] : undef;
}

sub show_topiclist {
    my $c = shift;
    my $page = $c->param('page') // 1;
    my $topiclimit = $c->configdata->{topiclimit};
    my $uid = $c->session->{userid};
    $c->stash(
        page     => $page,
        pageurl  => 'show_forum_topiclist_page',
        topics => $c->dbh->selectall_arrayref(
            'SELECT t."id", t."userfrom", t."title", t."posted",
                (SELECT COUNT(p."id") 
                    FROM "posts" p
                    LEFT OUTER JOIN "lastseenforum" l ON l."userid"=? AND l."topicid"=p."topicid"
                    WHERE p."userto" IS NULL AND p."userfrom"<>? AND p."topicid"=t."id" AND p."id">COALESCE(l."lastseen",-1)
                ) AS "entrycount_new"
            FROM "topics" t
            ORDER BY "entrycount_new" DESC, UPPER(t."title") ASC
            LIMIT ? OFFSET ?',
            undef, $uid, $uid, $topiclimit, ( $page - 1 ) * $topiclimit
        ),
    );

    $c->render(template => 'topiclist');
}

sub add_topic_form {
    my $c = shift;
    $c->stash(
        titlestring => $c->param('titlestring') // '',
        topicid     => undef,
        textdata    => $c->param('textdata') // '',
    );
    return $c->render(template => 'topicform');
}

sub _get_topicid_for_title {
    my $c = shift;
    my $r = $c->dbh->selectall_arrayref(
        'SELECT "id" FROM "topics" WHERE "title"=?',
        undef, shift() // $c->param('titlestring')
    );
    return unless @$r;
    return $r->[0]->[0];
}

sub _check_titlestring {
    my $c = shift;
    my $titlestring = shift() // $c->param('titlestring');
    if ( !defined($titlestring) or (2 > length $titlestring) ) {
        $c->set_error('Die Übschrift ist zu kurz und muss mindestens zwei Zeichen enthalten.');
        return;
    }
    if ( 256 < length $titlestring ) {
        $c->set_error('Die Überschrift ist zu lang und darf höchstens 256 Zeichen enthalten.');
        return;
    }
    return 1;
}

sub add_topic_do {
    my $c = shift;
    my $uid = $c->session->{userid};
    my $titlestring = $c->param('titlestring');
    return $c->add_topic_form unless $c->_check_titlestring;
    if ( my $topicid = $c->_get_topicid_for_title ) {
        $c->set_warning('Das Thema gab es bereits, der eingegebene Beitrag wurde zum Thema hinzugefügt.');
        $c->param(topicid => $topicid);
        return $c->add();
    }
    my $dbh = $c->dbh;
    $dbh->do(
        'INSERT INTO "topics" ("userfrom", "title") VALUES (?,?)',
        undef, $uid, $titlestring
    );
    my $r = $dbh->selectall_arrayref(
        'SELECT "id" FROM "topics" WHERE "userfrom"=? ORDER BY "id" DESC LIMIT 1',
        undef, $uid 
    );
    unless ( @$r ) {
        $c->set_error('Das Thema konnte irgendwie nicht angelegt werden. Bitte versuchen Sie es erneut.');
        return $c->add_topic_form;
    }
    $c->param(topicid => $r);
    return $c->add;
}

sub _get_title_from_topicid {
    my $c = shift;
    my $r = $c->dbh->selectall_arrayref(
        'SELECT "title" FROM "topics" WHERE "id"=?',
        undef, shift() // $c->param('topicid')
    );
    unless ( @$r ) {
        $c->set_error('Konnte das gewünschte Thema nicht finden.');
        return $c->show_topiclist;
    }
    return $r->[0]->[0];
}

sub edit_topic_form {
    my $c = shift;
    $c->stash(
        topicid     => $c->param('topicid'),
        titlestring => $c->param('titlestring') // $c->_get_title_from_topicid,
    );
    $c->render(template => 'topicform');
}

sub _check_topic_edit {
    my $c = shift;
    my $topicid = shift() // $c->param('topicid');
    my $r = $c->dbh->selectall_arrayref(
        'SELECT "userfrom" FROM "topics" WHERE "id"=?',
        undef, $topicid
    );
    unless ( @$r ) {
        $c->set_error('Kann das Thema nicht ändern, da es nicht von Ihnen angelegt wurde.');
        $c->show_topiclist;
        return;
    }
    return $r->[0]->[0] == $c->session->{userid} ? 1 : 0;
}

sub edit_topic_do {
    my $c = shift;
    my $titlestring = $c->param('titlestring');
    my $topicid = $c->param('topicid');
    return unless $c->_check_topic_edit($topicid);
    return $c->edit_topic_form unless $c->_check_titlestring($titlestring);
    if ( my $topicidto = $c->_get_topicid_for_title($titlestring) ) {
        if ( $topicidto == $topicid ) {
            $c->set_warning('Der Titel wurde nicht verändert.');
            return $c->show_topiclist;
        }
        $c->set_warning('Das gewünschte Thema existiert bereits.');
        $c->stash(
            topicid   => $topicid,
            topicidto => $topicidto,
            titlestringdest => $c->_get_title_from_topicid($topicidto),
            titlestringorig => $c->_get_title_from_topicid($topicid),
        );
        return $c->render(template => 'topicmoveform');
    }
    $c->set_info('Überschrift des Themas wurde geändert.');
    $c->dbh->do(
        'UPDATE "topics" SET "title"=? WHERE "id"=?',
        undef, $titlestring, $topicid
    );
    $c->show_topiclist;
}

sub move_topic_do {
    my $c = shift;
    my $topicid = $c->param('topicid');
    my $dbh = $c->dbh;
    return unless $c->_check_topic_edit($topicid);
    $dbh->do(
        'UPDATE "posts" SET "topicid"=? WHERE "topicid"=?',
        undef, $c->param('topicidto'), $topicid
    );
    my $r = $c->dbh->selectall_arrayref(
        'SELECT COUNT("id") FROM "posts" WHERE "topicid"=?',
        undef, $topicid
    );
    if ( $r->[0]->[0] ) {
        $c->set_error('Die Beiträge konnten nicht verschoben werden.');
        return $c->show_topiclist;
    }
    $dbh->do(
        'DELETE FROM "topics" WHERE "id"=?',
        undef, $topicid
    );
    $c->set_info('Die Beiträge wurden in ein anderes Thema verschoben');
    $c->show_topiclist;
}

sub show {
    my $c = shift;
    my ( $dbh, $uid, $topicid ) = ( $c->dbh, $c->session->{userid}, $c->param('topicid') );
    $c->stash(
        backurl => $c->url_for('show_forum_topiclist'),
        heading => $c->_get_title_from_topicid,
    );
    my $lastseen = $c->dbh->selectall_arrayref(
        'SELECT "lastseen"
        FROM "lastseenforum"
        WHERE "userid"=? AND "topicid"=?',
        undef, $uid, $topicid
    );
    my $newlastseen = $c->dbh->selectall_arrayref(
        'SELECT "id" FROM "posts" WHERE "userto" IS NULL AND "topicid"=? ORDER BY "id" DESC LIMIT 1',
        undef, $topicid);
    $newlastseen = @$newlastseen ? $newlastseen->[0]->[0] : -1;
    if ( @$lastseen ) {
        $c->stash( lastseen => $lastseen->[0]->[0] );
        $dbh->do(
            'UPDATE "lastseenforum" SET "lastseen"=? WHERE "userid"=? AND "topicid"=?',
            undef, $newlastseen, $uid, $topicid );
    }
    else {
        $c->stash( lastseen => -1 );
        $dbh->do(
            'INSERT INTO "lastseenforum" ("userid", "topicid", "lastseen") VALUES (?,?,?)',
            undef, $uid, $topicid, $newlastseen );
    }
    $c->show_posts();
}

sub query { $_[0]->query_posts }

sub add { $_[0]->add_post( undef, $_[0]->param('topicid') ) }

sub edit_form {
    my $c = shift;
    $c->stash( heading => 
        'Beitrag zum Thema "' . $c->_get_title_from_topicid . '" ändern' );
    $c->edit_post_form();
}

sub edit_do { $_[0]->edit_post_do() }

sub delete_check {
    my $c = shift;
    $c->stash( heading => 
        'Beitrag zum Thema "' . $c->_get_title_from_topicid . '" entfernen' );
    $c->delete_post_check();
}

sub delete_do { $_[0]->delete_post_do() }

sub upload_form {
    my $c = shift;
    $c->stash( heading => 
        'Eine Datei zum Beitrag zum Thema "' . $c->_get_title_from_topicid . '" anhängen' );
    $c->upload_post_form();
}

sub upload_do { $_[0]->upload_post_do() }

sub download {  $_[0]->download_post() }

sub delete_upload_check {
    my $c = shift;
    $c->stash( heading => 
        'Eine Datei zum Beitrag zum Thema "' . $c->_get_title_from_topicid . '" löschen' );
    $c->delete_upload_post_check();
}

sub delete_upload_do { $_[0]->delete_upload_post_do() }

1;

