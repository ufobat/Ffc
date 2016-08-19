package Ffc::Forum;
use 5.18.0;
use strict; use warnings; use utf8;

###############################################################################
sub moveto_topiclist_select {
    my $c = shift;
    $c->counting;
    $c->stash(dourl  => 'move_forum_topiclist_do');
    $c->stash(returl => $c->url_for('show_forum_topiclist'));
    $c->stash(heading => 'Beitrag verschieben');
    unless ( $c->get_single_post() ) {
        $c->set_warning_f(', unpassender Beitrag zum verschieben');
        return $c->redirect_to('show_forum', topicid => $c->param('topicid'));
    }
    $c->render(template => 'move_post_topiclist');
}

###############################################################################
sub _moveto_old_topic {
    my $c = shift;
    my $postid = $c->param('postid');
    my $oldtopicid = $c->param('topicid');
    my $newtopicid = $c->param('newtopicid');
    unless ( defined($oldtopicid) and $oldtopicid ) {
        $c->set_warning_f('Themen-Index wurde nicht übergeben');
        $c->redirect_to('show');
        return;
    }
    unless ( defined($postid) and $postid ) {
        $c->set_warning_f('Beitrags-Index wurde nicht übergeben');
        $c->redirect_to('show_forum', topicid => $oldtopicid);
        return;
    }
    unless ( defined($newtopicid) and $newtopicid ) {
        $c->set_warning_f('Neues Thema wurde nicht ausgewählt');
        $c->redirect_to('show_forum', topicid => $oldtopicid);
        return;
    }
    my $userid = $c->session->{userid};
    my $sql = << 'EOSQL';
SELECT "id", "textdata" FROM "posts"
WHERE "id"=?  AND "topicid"=?  AND "userfrom"=?  AND "userto" IS NULL
LIMIT 1;
EOSQL
    my $post = $c->dbh_selectall_arrayref( $sql, $postid, $oldtopicid, $userid );
    unless ( @$post ) {
        $c->set_error_f('Konnte keinen passenden Beitrag zum Verschieben finden');
        return;
    }
    $sql = q~SELECT "id", "title" FROM "topics" WHERE "id"=? LIMIT 1~;
    my $topic = $c->dbh_selectall_arrayref( $sql, $newtopicid );
    unless ( @$topic ) {
        $c->set_error_f('Konnte das neue Thema zum Verschieben nicht finden');
        return;
    }
    my $ttitle = $topic->[0]->[1];

    # Beitrag an der anderen Stelle hinzu fügen
    $c->param(topicid => $newtopicid);
    $c->param(textdata => $post->[0]->[1]);
    $c->add(1,1);
    my $newpostid = $c->param('postid');

    my $textdata = '<p><a href="'.$c->url_for('display_forum', topicid => $newtopicid, postid => $newpostid).'" target="_blank" title="Der Beitrag wurde in ein anderes Thema verschoben, folgen sie dem Beitrag hier">Beitrag verschoben nach "'.$ttitle.'"</a></p>';
    $sql = << 'EOSQL';
UPDATE "posts" SET "cache"=?, "blocked"=1
WHERE "id"=?  AND "topicid"=?  AND "userfrom"=?  AND "userto" IS NULL
EOSQL
    $c->dbh_selectall_arrayref( $sql, $textdata, $postid, $oldtopicid, $userid );
    $c->dbh_selectall_arrayref('UPDATE "attachements" SET "postid"=? WHERE "postid"=?', $newpostid, $postid);
    return $newtopicid;
}

###############################################################################
sub _moveto_new_topic {
    my $c = shift;
    my $postid = $c->param('postid');
    my $titlestring = $c->param('titlestring');
    if ( my $topicid =  $c->_create_topic() ) {
        $c->param(newtopicid => $topicid);
        return $c->_moveto_old_topic();
    }
    else {
        return;
    }
}

###############################################################################
sub moveto_topiclist_do {
    my $c = shift;
    my $postid = $c->param('postid');
    my $oldtopicid = $c->param('topicid');
    my $newtopicid = $c->param('newtopicid');
    my $titlestring = $c->param('titlestring') // '';
    if ( $newtopicid and $newtopicid =~ $Ffc::Digqr ) {
        unless ( $c->_moveto_old_topic() ) {
            return $c->redirect_to('show_forum', topicid => $oldtopicid);
        }
    }
    elsif ( $titlestring ) {
        unless ( $newtopicid = $c->_moveto_new_topic() ) {
            $c->set_error_f('Neues Thema konnte nicht angelegt werden');
            return $c->redirect_to('show_forum', topicid => $oldtopicid);
        }
    }
    else {
        $c->set_warning_f('Neues Thema wurde nicht ausgewählt');
        $c->redirect_to('show_forum', topicid => $oldtopicid);
        return;
    }
    $c->set_info_f('Beitrag wurde in das andere Thema verschoben');
    if ( $newtopicid ) {
        return $c->redirect_to('show_forum', topicid => $newtopicid);
    }
    else {
        return $c->redirect_to('show_forum_topiclist');
    }
}

1;
