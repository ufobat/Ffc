package Ffc::Plugin::Posts; # Delete
use 5.010;
use strict; use warnings; use utf8;

use File::Spec qw(catfile);

sub _delete_post_check {
    my $c = shift;
    $c->stash( dourl => $c->url_for('delete_'.$c->stash('controller').'_do', $c->additional_params) );
    _setup_stash($c);
    unless ( _get_single_post($c, @_) ) {
        $c->set_error_f('Konnte keinen passenden Beitrag zum Löschen finden');
        return _redirect_to_show($c);
    }
    $c->render( template => 'delete_check' );
}

sub _delete_post_do {
    my $c = shift;
    my ( $wheres, @wherep ) = $c->where_modify;
    my $postid = $c->param('postid');
    my $userid = $c->session->{userid};
    my $controller = $c->stash('controller');
    my $topicid;
    unless ( $postid and $postid =~ $Ffc::Digqr ) {
        $c->set_error_f('Konnte den Beitrag nicht ändern, da die Beitragsnummer irgendwie verloren ging');
        return _redirect_to_show($c);
    }
    {
        my $sql = q~SELECT "id", "topicid" FROM "posts" WHERE "id"=? AND "blocked"=0~;
        $sql   .= qq~ AND $wheres~ if $wheres;
        my $post = $c->dbh_selectall_arrayref( $sql, $postid, @wherep );
        unless ( @$post ) {
            $c->set_error_f('Konnte keinen passenden Beitrag zum Löschen finden');
            return _redirect_to_show($c);
        }
        $topicid = $post->[0]->[1];
        if ( ( $controller eq 'forum' and not defined $topicid ) or ( $controller eq 'pmsgs' ) ) {
            $c->set_error_f('Konnte keinen passenden Beitrag zum Löschen finden');
            return _redirect_to_show($c);
        }
    }
    my $atts = 0;
    {
        my $sql = q~SELECT "id" FROM "attachements" WHERE "postid"=?~;
        my $r = $c->dbh_selectall_arrayref( $sql, $postid );
        $atts = @$r;
        my $delerr = 0;
        for my $r ( @$r ) {
            my $file = catfile(@{$c->datapath}, 'uploads', $r->[0]);
            unlink $file or $delerr++;
        }
        $c->set_warning_f("$delerr Anhänge konnten nicht entfernt werden.")
            if $delerr;
    }
    if ( $atts ) {
        my $sql = q~DELETE FROM "attachements" WHERE "postid"=?~;
        $c->dbh_do( $sql, $postid );
    }
    {
        my $sql = q~DELETE FROM "posts" WHERE "id"=? AND "blocked"=0~;
        $sql   .= qq~ AND $wheres~ if $wheres;
        $c->dbh_do( $sql, $postid, @wherep );

        my $summary = $c->dbh_selectall_arrayref('SELECT "text" FROM "posts" WHERE "topicid"=? ORDER BY "id" DESC LIMIT 1', $topicid);
        if ( $controller eq 'forum' and @$summary ) {
            $summary = $c->format_short($summary->[0]->[0]); 
        }
        else {
            $summary = '';
        }
        _update_topic_lastid($c, $topicid, $summary) if $controller eq 'forum';
    }
    $c->set_info_f('Der Beitrag wurde komplett entfernt');
    _redirect_to_show($c);
}


1;

