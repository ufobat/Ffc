package Ffc::Forum;
use 5.18.0;
use strict; use warnings; use utf8;

sub   newsmail_topic_do { $_[0]->_handle_newsmail_topic_do(1, $_[1]) }
sub unnewsmail_topic_do { $_[0]->_handle_newsmail_topic_do(0, $_[1]) }
sub _handle_newsmail_topic_do {
    $_[0]->_handle_val_topic_do('newsmail', $_[1],
        'Für das gewählte Thema werden Informations-Emails bei neuen Beiträgen verschickt.',
        'Für das gewählte Thema werden keine Informations-Emails bei neuen Beiträgen mehr verschickt.',
        $_[2],
        (($_[1] and not $_[0]->session->{newsmail}) ? ' Mailversand ist generell unterbunden, es kommen keine Emails an. Um den Emailversand zu aktivieren, musst du unter "Benutzerkonto" in den "Einstellungen" oben rechts im Menü beim Punk "Email-Adresse einstellen" den Punkt "Benachrichtigungen per Email erhalten" anhaken.' : ''),
    );
}

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
    my ( $c, $name, $val, $dotxt, $undotxt, $redirect, $warning ) = @_;
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
    if ( $val )     { $c->set_info_f(    $dotxt   ) }
    else            { $c->set_info_f(    $undotxt ) }
    if ( $warning ) { $c->set_warning_f( $warning ) } 
    $c->redirect_to($redirect ? ( $redirect, topicid => $topicid ) : 'show_forum_topiclist');
}

sub mark_seen {
    my $topicid = $_[0]->param('topicid');
    $_[0]->set_lastseen( $_[0]->session->{userid}, $topicid );
    $_[0]->redirect_to($_[1] ? ( $_[1], topicid => $topicid ) : 'show_forum_topiclist');
}

sub mark_all_seen {
    my $c = shift;
    $c->counting;
    my $uid = $c->session->{userid};
    for my $top ( grep {;$_->[3]} @{$c->stash('topics')} ) {
        $c->set_lastseen( $uid, $top->[0] );
    }
    $c->set_info_f('Alle Themen wurden als gelesen markiert.');
    $c->redirect_to('show_forum_topiclist');
}

1;

