package Ffc::Plugin::Posts; # Create
use 5.010;
use strict; use warnings; use utf8;

sub _add_post {
    my ( $c, $userto, $topicid ) = @_;
    my $text = $c->param('textdata');
    if ( !defined($text) or (2 > length $text) ) {
        $c->stash(textdata => $text);
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen)');
        return $c->show;
    }
    if ( $userto or $topicid ) {
        my $sql = 'SELECT CASE WHEN MAX(p.id)>l.lastseen THEN 1 ELSE 0 END'
            . ' FROM users u INNER JOIN lastseen'
            . ( $userto 
                ? 'msgs l ON l.userid=u.id AND l.userfromid=?' 
                : 'forum l ON l.userid=u.id AND l.topicid=?' )
            . ' INNER JOIN posts p ON p.userfrom<>? AND p.'
            . ( $userto 
                ? 'userfrom=?'
                : 'topicid=?' )
            . ' GROUP BY l.userid';
        my $r = $c->dbh->selectall_arrayref( 
            $sql, undef, 
            ( $userto 
                ? ($userto, $c->session->{userid}, $userto) 
                : ($topicid, $c->session->{userid}, $topicid) ),
        );
        if ( $r->[0]->[0] ) {
            $c->stash(textdata => $text);
            $c->set_warning('Es wurde zwischenzeitlich ein neuer Beitrag erstellt, bitte prüfen!');
            return $c->show;
        }
    }
    $c->dbh->do( << 'EOSQL', undef,
INSERT INTO "posts"
    ("userfrom", "userto", "topicid", "textdata", "cache")
VALUES 
    (?,?,?,?,?)
EOSQL
        $c->session->{userid}, $userto, $topicid, $text, $c->pre_format($text)
    );

    $c->set_info_f('Ein neuer Beitrag wurde erstellt');
    _redirect_to_show($c);
}

sub _edit_post_form {
    my $c = shift;
    $c->stash( dourl => $c->url_for('edit_'.$c->stash('controller').'_do', $c->additional_params) );
    _setup_stash($c);
    return unless _get_single_post($c, @_);
    $c->render( template => 'edit_form' );
}

sub _edit_post_do {
    my $c = shift;
    my ( $wheres, @wherep ) = $c->where_modify;
    my $postid = $c->param('postid');
    my $text = $c->param('textdata');
    unless ( $postid and $postid =~ $Ffc::Digqr ) {
        $c->set_error('Konnte den Beitrag nicht ändern, da die Beitragsnummer irgendwie verloren ging');
        $c->stash(textdata => $text);
        return $c->show;
    }
    if ( !defined($text) or (2 > length $text) ) {
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen)');
        return $c->edit_form;
    }

    my $sql = qq~UPDATE "posts"\n~
            . qq~SET "textdata"=?, "cache"=?, "altered"=current_timestamp\n~
            . qq~WHERE "id"=?~;
    $sql .= qq~ AND $wheres~ if $wheres;
    $c->dbh->do( $sql, undef, $text, $c->pre_format($text), $postid, @wherep );
    $c->set_info_f('Der Beitrag wurde geändert');
    _redirect_to_show($c);
}

1;

