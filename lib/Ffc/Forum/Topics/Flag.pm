package Ffc::Forum;
use strict; use warnings; use utf8;

sub   ignore_topic_do { $_[0]->_handle_ignore_topic_do(1, $_[1]) }
sub unignore_topic_do { $_[0]->_handle_ignore_topic_do(0, $_[1]) }
sub _handle_ignore_topic_do {
    $_[0]->_handle_val_topic_do('ignore', $_[1],
        'Zum gewählten Thema werden keine neuen Beiträge mehr angezählt.',
        'Das gewählte Thema wird jetzt nicht mehr ignoriert.', $_[2]);
}

sub   pin_topic_do { $_[0]->_handle_pin_topic_do(1) }
sub unpin_topic_do { $_[0]->_handle_pin_topic_do(0) }
sub _handle_pin_topic_do {
    $_[0]->_handle_val_topic_do('pin', $_[1],
        'Das gewählte Thema wird immer oben angeheftet.', 
        'Das gewählte Thema wird jetzt nicht mehr oben angeheftet.');
}

sub _handle_val_topic_do {
    my ( $c, $name, $val, $dotxt, $undotxt, $redirect ) = @_;
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
    $c->redirect_to($redirect ? ( $redirect, topicid => $topicid ) : 'show_forum_topiclist');
}

sub mark_seen {
    my $topicid = $_[0]->param('topicid');
    $_[0]->set_lastseen( $_[0]->session->{userid}, $topicid );
    $_[0]->redirect_to($_[1] ? ( $_[1], topicid => $topicid ) : 'show_forum_topiclist');
}

1;

