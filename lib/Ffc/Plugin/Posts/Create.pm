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
    my $controller = $c->stash('controller');
    if ( $controller eq 'forum' and $topicid ) {
        my $sql = 'SELECT'
            . ' CASE WHEN MAX(COALESCE(p.id,-1))>MAX(COALESCE(l.lastseen,-1)) THEN 1 ELSE 0 END'
            . ' FROM users u LEFT OUTER JOIN posts p ON p.userfrom<>? AND p.'
              . ( $userto ? 'userto=?' : 'topicid=?' )
            . ' LEFT OUTER JOIN lastseen' 
            . ( $controller eq 'pmsgs' 
                ? 'msgs l ON l.userid=u.id AND l.userfromid=?' 
                : 'forum l ON l.userid=u.id AND l.topicid=?' )
            . ' WHERE u.id=? GROUP BY u.id';
        my $r = $c->dbh->selectall_arrayref( 
            $sql, undef, $c->session->{userid},
            ( $userto ? ($userto, $userto) : ($topicid, $topicid) ),
            $c->session->{userid},
        );
        if ( @$r and $r->[0]->[0] ) {
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
    if ( $controller eq 'forum' and $topicid ) {
        $c->dbh->do( << 'EOSQL', undef, $topicid, $topicid );
UPDATE "topics" 
SET "lastid"=(
    SELECT COALESCE(MAX("id"),0) 
    FROM "posts" 
    WHERE "topicid" IS NOT NULL 
      AND "topicid"=?
      AND "userto" IS NULL
    LIMIT 1
  )
WHERE "id"=?
EOSQL
    }
    if ( $controller eq 'pmsgs' and $userto ) {
        my $userid = $c->session->{userid};
        $c->dbh->do( << 'EOSQL'
UPDATE "lastseenmsgs"
SET "lastid"=(
    SELECT COALESCE(MAX(p."id"),0)
    FROM "posts" p
    WHERE p."userfrom"=? AND p."userto"=?
    LIMIT 1)
WHERE "userfromid"=? AND "userid"=?
EOSQL
            , undef, $userid, $userto, $userid, $userto );
    }

    $c->set_info_f('Ein neuer Beitrag wurde erstellt');
    _redirect_to_show($c);
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
    my $text = $c->param('textdata');
    unless ( $postid and $postid =~ $Ffc::Digqr ) {
        $c->set_error_f('Konnte den Beitrag nicht ändern, da die Beitragsnummer irgendwie verloren ging');
        $c->stash(textdata => $text);
        return _redirect_to_show($c);
    }
    if ( !defined($text) or (2 > length $text) ) {
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen)');
        return $c->edit_form;
    }

    my $sql = qq~ SELECT COUNT("id")\nFROM "posts"\n~
            . qq~ WHERE "id"=?~;
    $sql .= qq~ AND $wheres~ if $wheres;
    unless ( $c->dbh->selectall_arrayref( $sql, undef, $postid, @wherep )->[0]->[0] ) {
        $c->set_error_f('Kein passender Beitrag zum ändern gefunden');
        return _redirect_to_show($c);
    }

    $sql = qq~UPDATE "posts"\n~
            . qq~SET "textdata"=?, "cache"=?, "altered"=current_timestamp\n~
            . qq~WHERE "id"=?~;
    $sql .= qq~ AND $wheres~ if $wheres;
    $c->dbh->do( $sql, undef, $text, $c->pre_format($text), $postid, @wherep );
    $c->set_info_f('Der Beitrag wurde geändert');
    _redirect_to_show($c);
}

1;

