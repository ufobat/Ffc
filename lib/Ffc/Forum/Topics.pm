package Ffc::Forum;
use strict; use warnings; use utf8;

sub show_topiclist {
    my $c = shift;
    $c->counting;
    my $page = $c->param('page') // 1;
    $c->session->{query} = '';
    if ( $page == 1 ) {
        $c->stash(topics_for_list => $c->stash('topics'));
    }
    else {
        $c->generate_topiclist('topics_for_list');
    }
    $c->stash(
        page     => $page,
        pageurl  => 'show_forum_topiclist_page',
        returl   => $c->url_for('show_forum_topiclist'),
        queryurl => $c->url_for('search_forum_posts'),
    );

    $c->render(template => 'topiclist');
}

sub add_topic_form {
    my $c = shift;
    $c->counting;
    $c->stash(
        titlestring => $c->param('titlestring') // '',
        topicid     => undef,
        textdata    => $c->param('textdata') // '',
    );
    return $c->render(template => 'topicform');
}

sub _get_topicid_for_title {
    my $c = shift;
    my $r = $c->dbh_selectall_arrayref(
        'SELECT "id" FROM "topics" WHERE "title"=?',
        shift() // $c->param('titlestring')
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
    my $text = $c->param('textdata');
    if ( !defined($text) or (2 > length $text) ) {
        $c->stash(textdata => $text);
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen)');
        return $c->add_topic_form;
    }
    if ( my $topicid = $c->_get_topicid_for_title ) {
        $c->set_warning('Das Thema gab es bereits, der eingegebene Beitrag wurde zum Thema hinzugefügt.');
        $c->param(topicid => $topicid);
        return $c->add();
    }
    else {
        $c->set_error('');
    }
    $c->dbh_do(
        'INSERT INTO "topics" ("userfrom", "title") VALUES (?,?)',
        $uid, $titlestring
    );
    my $r = $c->dbh_selectall_arrayref(
        'SELECT "id" FROM "topics" WHERE "userfrom"=? ORDER BY "id" DESC LIMIT 1',
        $uid 
    );
    unless ( @$r ) {
        $c->set_error('Das Thema konnte irgendwie nicht angelegt werden. Bitte versuchen Sie es erneut.');
        return $c->add_topic_form;
    }
    $c->param(topicid => $r->[0]->[0]);
    return $c->add;
}

sub _get_title_from_topicid {
    my $c = shift;
    my $r = $c->dbh_selectall_arrayref(
        'SELECT "title", "userfrom" FROM "topics" WHERE "id"=?',
        shift() // $c->param('topicid')
    );
    unless ( @$r ) {
        $c->set_error('Konnte das gewünschte Thema nicht finden.');
        $c->show_topiclist;
        return;
    }
    return wantarray ? @{$r->[0]} : $r->[0]->[0];
}

sub edit_topic_form {
    my $c = shift;
    $c->counting;
    $c->stash(
        topicid     => $c->param('topicid'),
        titlestring => $c->param('titlestring') // scalar($c->_get_title_from_topicid),
    );
    $c->render(template => 'topicform');
}

sub _check_topic_edit {
    my $c = shift;
    return 1 if $c->session->{admin};
    my $topicid = shift() // $c->param('topicid');
    my $r = $c->dbh_selectall_arrayref(
        'SELECT "userfrom" FROM "topics" WHERE "id"=?',
        $topicid
    );
    unless ( @$r and $r->[0]->[0] == $c->session->{userid} ) {
        $c->set_error_f('Kann das Thema nicht ändern, da es nicht von Ihnen angelegt wurde und Sie auch kein Administrator sind.');
        $c->redirect_to('show_forum', topicid => $topicid);
        return;
    }
    return 1;
}

sub edit_topic_do {
    my $c = shift;
    my $titlestring = $c->param('titlestring');
    my $topicid = $c->param('topicid');
    return unless $c->_check_topic_edit($topicid);
    return $c->edit_topic_form unless $c->_check_titlestring($titlestring);
    if ( my $topicidto = $c->_get_topicid_for_title($titlestring) ) {
        if ( $topicidto == $topicid ) {
            $c->set_warning_f('Der Titel wurde nicht verändert.');
            return $c->redirect_to('show_forum', topicid => $topicid);
        }
        $c->set_warning('Das gewünschte Thema existiert bereits.');
        $c->counting;
        $c->stash(
            topicid   => $topicid,
            topicidto => $topicidto,
            titlestringdest => scalar($c->_get_title_from_topicid($topicidto)),
            titlestringorig => scalar($c->_get_title_from_topicid($topicid)),
        );
        return $c->render(template => 'topicmoveform');
    }
    $c->dbh_do(
        'UPDATE "topics" SET "title"=? WHERE "id"=?',
        $titlestring, $topicid
    );
    $c->set_info_f('Die Überschrift des Themas wurde geändert.');
    $c->redirect_to('show_forum', topicid => $topicid);
}

sub move_topic_do {
    my $c = shift;
    my $topicid = $c->param('topicid');
    my $topicidto = $c->param('topicidto');
    my $uid = $c->session->{userid};

    return $c->redirect_to('show_forum_topiclist') unless $c->_check_topic_edit($topicid);

    $c->dbh_do(
        'UPDATE "posts" SET "topicid"=? WHERE "topicid"=?',
        $topicidto, $topicid
    );
    my $r = $c->dbh_selectall_arrayref(
        'SELECT COUNT("id") FROM "posts" WHERE "topicid"=?',
        $topicid
    );
    if ( $r->[0]->[0] ) {
        $c->set_error_f('Die Beiträge konnten nicht verschoben werden.');
        return $c->redirect_to('show_forum_topiclist');
    }
    $c->dbh_do(
        'DELETE FROM "topics" WHERE "id"=?',
        $topicid
    );
    $c->dbh_do(
        'DELETE FROM "lastseenforum" WHERE "topicid"=?',
        $topicid
    );
    $c->set_info_f('Die Beiträge wurden in ein anderes Thema verschoben.');
    $c->redirect_to('show_forum', topicid => $topicidto);
}

sub   ignore_topic_do { $_[0]->_handle_ignore_topic_do(1) }
sub unignore_topic_do { $_[0]->_handle_ignore_topic_do(0) }
sub _handle_ignore_topic_do {
    $_[0]->_handle_val_topic_do('ignore', $_[1],
        'Zum gewählten Thema werden keine neuen Beiträge mehr angezählt.',
        'Das gewählte Thema wird jetzt nicht mehr ignoriert.');
}

sub   pin_topic_do { $_[0]->_handle_pin_topic_do(1) }
sub unpin_topic_do { $_[0]->_handle_pin_topic_do(0) }
sub _handle_pin_topic_do {
    $_[0]->_handle_val_topic_do('pin', $_[1],
        'Das gewählte Thema wird immer oben angeheftet.', 
        'Das gewählte Thema wird jetzt nicht mehr oben angeheftet.');
}

sub _handle_val_topic_do {
    my ( $c, $name, $val, $dotxt, $undotxt ) = @_;
    my $topicid = $c->param('topicid');
    my $lastseen = $c->dbh_selectall_arrayref(
        'SELECT "lastseen"
        FROM "lastseenforum"
        WHERE "userid"=? AND "topicid"=?',
        $c->session->{userid}, $topicid
    );
    if ( @$lastseen ) {
        $c->dbh_do(
            qq~UPDATE "lastseenforum" SET "$name"=? WHERE "userid"=? AND "topicid"=?~,
            $val, $c->session->{userid}, $topicid );
    }
    else {
        $c->dbh_do(
            qq~INSERT INTO "lastseenforum" ("userid", "topicid", "$name") VALUES (?,?,?)~,
            $c->session->{userid}, $topicid, $val);
    }
    if ( $val ) { $c->set_info_f( $dotxt   ) }
    else        { $c->set_info_f( $undotxt ) }
    $c->redirect_to('show_forum_topiclist');
}

sub sort_order_chronological { 
    $_[0]->_set_sort_order_cron_do(1, 'Themen werden chronologisch sortiert.');
}
sub sort_order_alphabetical  {
    $_[0]->_set_sort_order_cron_do(0, 'Themen werden alphabetisch sortiert.');
}
sub _set_sort_order_cron_do {
    my ( $c, $v, $t ) = @_;
    $c->dbh_do(
        'UPDATE "users" SET "chronsortorder"=? WHERE "id"=?'
        , $v, $c->session->{userid}
    );
    $c->session->{chronsortorder} = $v;
    $c->set_info_f($t);
    $c->redirect_to('show_forum_topiclist');
}

sub set_topiclimit {
    my $c = $_[0];
    my $topiclimit = $c->param('topiclimit');
    unless ( $topiclimit =~ $Ffc::Digqr and $topiclimit > 0 and $topiclimit < 128 ) {
        $c->set_error_f('Die Anzahl der auf einer Seite in der Liste angezeigten Überschriften muss eine ganze Zahl kleiner 128 sein.');
        $c->redirect_to('show_forum_topiclist');
        return;
    }
    $c->session->{topiclimit} = $topiclimit;
    $c->dbh_do('UPDATE "users" SET "topiclimit"=? WHERE "id"=?',
        $topiclimit, $c->session->{userid});
    $c->set_info_f("Anzahl der auf einer Seite der Liste angezeigten Überschriften auf $topiclimit geändert.");
    $c->redirect_to('show_forum_topiclist');
}

sub mark_seen {
    _set_lastseen( $_[0], $_[0]->session->{userid}, $_[0]->param('topicid') );
    $_[0]->redirect_to('show_forum_topiclist');
}

1;

