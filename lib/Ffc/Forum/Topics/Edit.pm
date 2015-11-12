package Ffc::Forum;
use strict; use warnings; use utf8;

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

1;

