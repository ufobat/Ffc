package Ffc::Plugin::Posts; # Delete
use 5.18.0;
use strict; use warnings; use utf8;

use File::Spec 'catfile';

###############################################################################
# Formular zur Nachfrage wegen des Löschens eines Beitrags vorbereiten und anzeigen
sub _delete_post_check {
    my $c = $_[0];
    $c->stash( dourl => $c->url_for('delete_'.$c->stash('controller').'_do', $c->additional_params) );
    _setup_stash($c);
    unless ( _get_single_post($c, @_) ) {
        $c->set_error_f('Konnte keinen passenden Beitrag zum Löschen finden');
        return _redirect_to_show($c);
    }
    $c->counting;
    $c->render( template => 'delete_check' );
}

###############################################################################
# Einen Beitrag tatsächlich aus der Datenbank löschen
sub _delete_post_do {
    my $c = $_[0];
    my ( $wheres, @wherep ) = $c->where_modify;
    my ( $postid, $userid, $controller, $topicid ) 
        = ( $c->param('postid'), $c->session->{userid}, $c->stash('controller'), undef );

    {
        # Nachsehen nach dem Beitrag, der gelöscht werden soll und ob der angemeldete 
        # Benutzer den überhaupt löschen darf
        my $sql = q~SELECT "id", "topicid" FROM "posts" WHERE "id"=? AND "blocked"=0~;
        $wheres and $sql .= qq~ AND $wheres~;
        my $post = $c->dbh_selectall_arrayref( $sql, $postid, @wherep );
        if ( not @$post ) {
            $c->set_error_f('Konnte keinen passenden Beitrag zum Löschen finden');
            return _redirect_to_show($c);
        }
        $topicid = $post->[0]->[1];
        if ( ( $controller eq 'forum' and not defined $topicid ) or ( $controller eq 'pmsgs' ) ) {
            $c->set_error_f('Konnte keinen passenden Beitrag zum Löschen finden');
            return _redirect_to_show($c);
        }
    }
    {
        # Anhänge müssen im Dateisystem gelöscht werden
        my $atts = 0;
        my $sql = q~SELECT "id" FROM "attachements" WHERE "postid"=?~;
        my $r = $c->dbh_selectall_arrayref( $sql, $postid );
        $atts = @$r;
        my $delerr = 0;
        for my $r ( @$r ) {
            my $file = catfile(@{$c->datapath}, 'uploads', $r->[0]);
            unlink $file or $delerr++;
            -e $file and $delerr++;
        }
        $c->set_warning_f("$delerr Anhänge konnten nicht entfernt werden.")
            if $delerr;
        if ( $atts ) {
            my $sql = q~DELETE FROM "attachements" WHERE "postid"=?~;
            $c->dbh_do( $sql, $postid );
        }
    }

    # Hier wird der Beitrag direkt aus der Datenbank gelöscht
    my $sql = q~DELETE FROM "posts" WHERE "id"=? AND "blocked"=0~;
    $sql   .= qq~ AND $wheres~ if $wheres;
    $c->dbh_do( $sql, $postid, @wherep );

    # Eventuell müssen wir im Forum noch die Summary der Themenliste anpassen
    if ( $controller eq 'forum' ) {
        my $summary = $c->dbh_selectall_arrayref(
            'SELECT "text" FROM "posts" WHERE "topicid"=? ORDER BY "id" DESC LIMIT 1', $topicid);
        if ( @$summary ) {
            $summary = $c->format_short($summary->[0]->[0]); 
            _update_topic_lastid($c, $topicid, $summary);
        }
        else {
            _update_topic_lastid($c, $topicid, '', 1);
        }
    }

    $c->set_info_f('Der Beitrag wurde komplett entfernt');
    _redirect_to_show($c);
}

1;
