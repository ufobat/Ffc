package Ffc::Plugin::Posts; # Create
use 5.010;
use strict; use warnings; use utf8;

sub _add_post {
    my ( $c, $userto, $topicid, $noinfo, $noredirect ) = @_;
    my $text = $c->param('textdata');
    my $userid = $c->session->{userid};
    if ( !defined($text) or (2 >= length $text) ) {
        $c->stash(textdata => $text);
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen)');
        return $c->show;
    }
    my $cache = $c->pre_format($text);
    if ( !defined($cache) or (2 >= length $cache) ) {
        $c->stash(textdata => $text);
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen ohne Auszeichnungen)');
        return $c->show;
    }
    my $controller = $c->stash('controller');
    if ( $controller eq 'forum' and $topicid ) {
        my $sql = 'SELECT'
            . ' CASE WHEN MAX(COALESCE(p.id,0))>MAX(COALESCE(l.lastseen,0)) THEN 1 ELSE 0 END'
            . ' FROM users u LEFT OUTER JOIN posts p ON p.userfrom<>? AND p.'
              . ( $userto ? 'userto=?' : 'topicid=?' )
            . ' LEFT OUTER JOIN lastseen' 
            . ( $controller eq 'pmsgs' 
                ? 'msgs l ON l.userid=u.id AND l.userfromid=?' 
                : 'forum l ON l.userid=u.id AND l.topicid=?' )
            . ' WHERE u.id=? GROUP BY u.id';
        my $r = $c->dbh_selectall_arrayref( 
            $sql, $userid,
            ( $userto ? ($userto, $userto) : ($topicid, $topicid) ),
            $userid,
        );
        if ( @$r and $r->[0]->[0] ) {
            $c->stash(textdata => $text);
            $c->set_warning('Es wurde zwischenzeitlich ein neuer Beitrag erstellt, bitte prüfen!');
            return $c->show;
        }
    }
    $c->dbh_do( << 'EOSQL', 
INSERT INTO "posts"
    ("userfrom", "userto", "topicid", "textdata", "cache")
VALUES 
    (?,?,?,?,?)
EOSQL
        $userid, $userto, $topicid, $text, $cache
    );

    my $summary = $controller eq 'forum' ? $c->format_short($text) : ''; 

    if ( $controller eq 'forum' and $topicid ) {
        _update_topic_lastid($c, $topicid, $summary);
    }
    if ( $controller eq 'pmsgs' and $userto ) {
        _update_pmsgs_lastid( $c, $userid, $userto );
    }
    my $sql = << 'EOSQL',
SELECT "id" FROM "posts"
WHERE "userfrom"=?
EOSQL
    my @params = ( $userid );
    if ( $controller eq 'forum' ) {
        $sql .= ' AND "topicid"=? AND "userto" IS NULL';
        push @params, $topicid;
    }
    elsif ( $controller eq 'pmsgs' ) {
        $sql .= ' AND "userto"=? AND "topicid" IS NULL';
        push @params, $userto;
    }
    elsif ( $controller eq 'notes' ) {
        $sql .= ' AND "userto"="userfrom" AND "topicid" IS NULL';
    }
    $sql .= << 'EOSQL';

ORDER BY "id" DESC
LIMIT 1;
EOSQL
    my $r = $c->dbh_selectall_arrayref($sql, @params);
    unless ( @$r and $r->[0]->[0] ) {
        $c->set_error('Konnte den neuen Beitrag nicht finden in der Datenbank, irgend etwas ging schief');
        return $c->show;
    }

    $c->param(postid => $r->[0]->[0]);
    $c->set_info_f('Ein neuer Beitrag wurde erstellt') unless $noinfo;
    _redirect_to_show($c) unless $noredirect;
}

sub _edit_post_form {
    my $c = shift;
    $c->stash( dourl => $c->url_for('edit_'.$c->stash('controller').'_do', $c->additional_params) );
    _setup_stash($c);
    unless ( _get_single_post($c, @_) ) {
        $c->set_error_f('Konnte keinen passenden Beitrag zum Ändern finden');
        return _redirect_to_show($c);
    }
    $c->render( template => 'edit_form' );
}

sub _edit_post_do {
    my $c = shift;
    my ( $wheres, @wherep ) = $c->where_modify;
    my $postid = $c->param('postid');
    my $topicid = $c->param('topicid');
    my $text = $c->param('textdata');
    unless ( $postid and $postid =~ $Ffc::Digqr ) {
        $c->set_error_f('Konnte den Beitrag nicht ändern, da die Beitragsnummer irgendwie verloren ging');
        $c->stash(textdata => $text);
        return _redirect_to_show($c);
    }
    if ( !defined($text) or (2 >= length $text) ) {
        $c->stash(textdata => $text);
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen)');
        return $c->edit_form;
    }
    my $cache = $c->pre_format($text);
    if ( !defined($cache) or (2 >= length $cache) ) {
        $c->stash(textdata => $text);
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen ohne Auszeichnungen)');
        return $c->edit_form;
    }

    my $sql = qq~ SELECT COUNT("id")\nFROM "posts"\n~
            . qq~ WHERE "id"=? AND "blocked"=0~;
    $sql .= qq~ AND $wheres~ if $wheres;
    unless ( $c->dbh_selectall_arrayref( $sql, $postid, @wherep )->[0]->[0] ) {
        $c->set_error_f('Kein passender Beitrag zum ändern gefunden');
        return _redirect_to_show($c);
    }

    my $summary = $c->stash('controller') eq 'forum' ? $c->format_short($text) : ''; 
    $sql = qq~UPDATE "posts"\n~
            . qq~SET "textdata"=?, "cache"=?, "altered"=current_timestamp\n~
            . qq~WHERE "id"=? AND "blocked"=0~;
    $sql .= qq~ AND $wheres~ if $wheres;
    $c->dbh_do( $sql, $text, $cache, $postid, @wherep );
    $sql = q~UPDATE "topics" SET "summary"=? WHERE "id"=?~;
    $c->dbh_do( $sql, $summary, $topicid );
    $c->set_info_f('Der Beitrag wurde geändert');
    _redirect_to_show($c);
}

1;

