package Ffc::Forum;
use strict; use warnings; use utf8;

sub add_topic_form {
    my $c = shift;
    $c->counting;
    $c->stash(
        titlestring => $c->param('titlestring') // '',
        topicid     => undef,
        textdata    => $c->param('textdata') // '',
    );
    return $c->render(template => 'topicform');
}

sub _create_topic {
    my $c = shift;
    my $uid = $c->session->{userid};
    my $titlestring = $c->param('titlestring');
    return unless $c->_check_titlestring;
    if ( my $topicid = $c->_get_topicid_for_title ) {
        $c->set_warning('Das Thema gab es bereits, der eingegebene Beitrag wurde zum Thema hinzugefügt.');
        return $topicid;
    }
    else {
        $c->set_error('');
    }
    $c->dbh_do(
        'INSERT INTO "topics" ("userfrom", "title") VALUES (?,?)',
        $uid, $titlestring
    );
    my $r = $c->dbh_selectall_arrayref(
        'SELECT "id" FROM "topics" WHERE "userfrom"=? ORDER BY "id" DESC LIMIT 1',
        $uid 
    );
    unless ( @$r ) {
        $c->set_error('Das Thema konnte irgendwie nicht angelegt werden. Bitte versuchen Sie es erneut.');
        return;
    }
    return $r->[0]->[0];
}

sub add_topic_do {
    my $c = shift;
    my $uid = $c->session->{userid};
    return $c->add_topic_form unless $c->_check_titlestring;
    my $text = $c->param('textdata');
    if ( !defined($text) or (2 > length $text) ) {
        $c->stash(textdata => $text);
        $c->set_error('Es wurde zu wenig Text eingegeben (min. 2 Zeichen)');
        return $c->add_topic_form;
    }
    if ( my $topicid = $c->_create_topic() ) {
        $c->param(topicid => $topicid);
        $c->add;
    }
    else {
        return $c->add_topic_form;
    }
}

1;

