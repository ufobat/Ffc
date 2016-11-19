package Ffc::Forum;
use 5.18.0;
use strict; use warnings; use utf8;

###############################################################################
# Ignorieren-Schalter
sub   ignore_topic_do { _handle_ignore_topic_do($_[0], 1, $_[1]) }
sub unignore_topic_do { _handle_ignore_topic_do($_[0], 0, $_[1]) }
# Handler
sub _handle_ignore_topic_do {
    _handle_val_topic_do($_[0], 'ignore', 'pin', $_[1],
        'Zum gewählten Thema werden keine neuen Beiträge mehr angezählt.',
        'Das gewählte Thema wird jetzt nicht mehr ignoriert.', $_[2]);
}

###############################################################################
# Oben Anpinnen-Schalter
sub   pin_topic_do { _handle_pin_topic_do($_[0], 1) }
sub unpin_topic_do { _handle_pin_topic_do($_[0], 0) }
# Handler
sub _handle_pin_topic_do {
    _handle_val_topic_do($_[0], 'pin', 'ignore', $_[1],
        'Das gewählte Thema wird immer oben angeheftet.', 
        'Das gewählte Thema wird jetzt nicht mehr oben angeheftet.');
}

###############################################################################
# Bearbeitungs-Handler der Schalteranfrage
sub _handle_val_topic_do {
    my ( $c, $name, $reset, $val, $dotxt, $undotxt, $redirect, $warning ) = @_;
    my $topicid = $c->param('topicid');

    # Gibt es schon einen Eintrag für diesen Schalter
    my $lastseen = $c->dbh_selectall_arrayref(
        'SELECT "lastseen"
        FROM "lastseenforum"
        WHERE "userid"=? AND "topicid"=?',
        $c->session->{userid}, $topicid
    );

    # Datenbank-Eintrag entsprechend erzeugen oder ändern
    if ( @$lastseen ) {
        $c->dbh_do(
            qq~UPDATE "lastseenforum" SET "$name"=? WHERE "userid"=? AND "topicid"=?~,
            $val, $c->session->{userid}, $topicid );
        $c->dbh_do(
            qq~UPDATE "lastseenforum" SET "$reset"=0 WHERE "userid"=? AND "topicid"=?~,
            $c->session->{userid}, $topicid );
    }
    else {
        $c->dbh_do(
            qq~INSERT INTO "lastseenforum" ("userid", "topicid", "$name", "$reset") VALUES (?,?,?,0)~,
            $c->session->{userid}, $topicid, $val);
    }

    # Webseiten-Daten befüllen
    if ( $val )     { $c->set_info_f(    $dotxt   ) }
    else            { $c->set_info_f(    $undotxt ) }
    if ( $warning ) { $c->set_warning_f( $warning ) } 
    $c->redirect_to($redirect ? ( $redirect, topicid => $topicid ) : 'show_forum_topiclist');
}

###############################################################################
# Künstlich einen Beitrag als gelesen markieren
sub mark_seen {
    my $topicid = $_[1] // $_[0]->param('topicid');
    $_[0]->set_lastseen( $_[0]->session->{userid}, $topicid );
    $_[0]->redirect_to(  $_[1] ? ( $_[1], topicid => $topicid ) : 'show_forum_topiclist' );
}

###############################################################################
# Künstlich alle neuen Beiträge direkt in der Themenliste als gelesen markieren
sub mark_all_seen {
    my $c = $_[0];
    $c->counting;
    for my $top ( @{$c->stash('topics')} ) {
        $c->set_lastseen( $c->session->{userid}, $top->[0] );
    }
    $c->set_lastseen( $c->session->{userid}, $c->configdata->{starttopic} )
        if $c->configdata->{starttopic};
    $c->set_info_f('Alle Themen wurden als gelesen markiert.');
    $c->redirect_to('show_forum_topiclist');
}

1;
