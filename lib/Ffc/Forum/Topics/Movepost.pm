package Ffc::Forum;
use 5.18.0;
use strict; use warnings; use utf8;

###############################################################################
# Vorbereiten der Webseite, über die man einen Beitrag in ein anderes Thema der Wahl verschieben kann
sub moveto_topiclist_select {
    my $c = $_[0];
    $c->counting;
    $c->stash(dourl  => 'move_forum_topiclist_do');
    $c->stash(returl => $c->url_for('show_forum_topiclist'));
    $c->stash(heading => 'Beitrag verschieben');
    # Wenn es aus irgend einem Grund den Beitrag nicht geben sollte, den man verschieben möchte
    unless ( $c->get_single_post() ) {
        $c->set_warning_f(', unpassender Beitrag zum verschieben');
        return $c->redirect_to('show_forum', topicid => $c->param('topicid'));
    }
    $c->render(template => 'move_post_topiclist');
}

###############################################################################
# Einen Beitrag in ein bestehendes Thema verschieben
sub _moveto_old_topic {
    my $c = $_[0];
    my ( $postid, $oldtopicid, $newtopicid ) = ( $c->param('postid'), $c->param('topicid'), $c->param('newtopicid') );

    # Eingabeprüfung
    unless ( defined $oldtopicid and $oldtopicid ) {
        $c->set_warning_f('Themen-Index wurde nicht übergeben');
        $c->redirect_to('show');
        return;
    }
    unless ( defined $postid and $postid ) {
        $c->set_warning_f('Beitrags-Index wurde nicht übergeben');
        $c->redirect_to('show_forum', topicid => $oldtopicid);
        return;
    }
    unless ( defined $newtopicid and $newtopicid ) {
        $c->set_warning_f('Neues Thema wurde nicht ausgewählt');
        $c->redirect_to('show_forum', topicid => $oldtopicid);
        return;
    }

    my $userid = $c->session->{userid};
    
    # Prüfen, ob es einen Beitrag unter der gegebenen Beitrags-Id gibt und ob man den überhaupt verschieben darf (darf man nur bei eigenen Beiträgen)
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

    # Nach dem neuen Titel suchen
    my $ttitle = $c->_get_title_from_topicid( $newtopicid, 1 );
    unless ( $ttitle ) {
        $c->set_error_f('Konnte das neue Thema zum Verschieben nicht finden');
        return;
    }

    # Beitrag im anderen Thema hinzu fügen
    $c->param(topicid  => $newtopicid);
    $c->param(textdata => $post->[0]->[1]);
    $c->add(1,1);
    my $newpostid = $c->param('postid');

    # Einen Hinweis anstelle des alten Beitrags im alten Thema einfügen
    my $textdata = '<p><a href="'.$c->url_for('display_forum', topicid => $newtopicid, postid => $newpostid).'" target="_blank" title="Der Beitrag wurde in ein anderes Thema verschoben, folgen sie dem Beitrag hier">Beitrag verschoben nach "'.$ttitle.'"</a></p>';
    $sql = << 'EOSQL';
UPDATE "posts" SET "cache"=?, "blocked"=1
WHERE "id"=?  AND "topicid"=?  AND "userfrom"=?  AND "userto" IS NULL
EOSQL
    $c->dbh_selectall_arrayref( $sql, $textdata, $postid, $oldtopicid, $userid );
    $c->dbh_selectall_arrayref('UPDATE "attachements" SET "postid"=? WHERE "postid"=?', $newpostid, $postid);

    # Da sind wir dann da
    return $newtopicid;
}

###############################################################################
# Beitrag in ein neues Thema verschieben (erzeugt einfach ein Thema und führt dann das "Verschieben in ein altes Thema" aus)
sub _moveto_new_topic {
    my $c = $_[0];
    my ( $postid, $titlestring ) = ( $c->param('postid'), $c->param('titlestring') );
    if ( my $topicid =  $c->_create_topic() ) {
        $c->param(newtopicid => $topicid);
        return $c->_moveto_old_topic();
    }
    return;
}

###############################################################################
# Irgendwie einen Beitrag in ein anderes Thema verschieben, je nach dem
sub moveto_topiclist_do {
    my $c = $_[0];
    my ( $postid, $oldtopicid, $newtopicid, $titlestring ) 
        = ( $c->param('postid'), $c->param('topicid'), $c->param('newtopicid'), $c->param('titlestring') );

    # Es geht in ein bestehendes Thema
    if ( $newtopicid and $newtopicid =~ $Ffc::Digqr ) {
        $c->_moveto_old_topic() 
            or return $c->redirect_to('show_forum', topicid => $oldtopicid);
    }
    # Es soll wohl in ein neues Thema gehen (alternativ natürlich in ein bestehendes)
    elsif ( $titlestring ) {
        unless ( $newtopicid = $c->_moveto_new_topic() ) {
            $c->set_error_f('Neues Thema konnte nicht angelegt werden');
            return $c->redirect_to('show_forum', topicid => $oldtopicid);
        }
    }
    # Es gibt gar kein Ziel
    else {
        $c->set_warning_f('Neues Thema wurde nicht ausgewählt');
        $c->redirect_to('show_forum', topicid => $oldtopicid);
        return;
    }
    
    # Hat alles funktioniert
    $c->set_info_f('Beitrag wurde in das andere Thema verschoben');
    # Eventuell direkt ins neue Thema springen, falls angegeben
    $newtopicid and return $c->redirect_to('show_forum', topicid => $newtopicid);
    return $c->redirect_to('show_forum_topiclist');
}

1;
