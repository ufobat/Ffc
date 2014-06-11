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
    $c->dbh->do( << 'EOSQL', undef,
INSERT INTO "posts"
    ("userfrom", "userto", "topicid", "textdata", "cache")
VALUES 
    (?,?,?,?,?)
EOSQL
        $c->session->{userid}, $userto, $topicid, $text, $c->pre_format($text)
    );

    $c->set_info('Ein neuer Beitrag wurde erstellt');
    $c->show;
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
    $c->set_info('Der Beitrag wurde geändert');
    return $c->show;
}

1;

