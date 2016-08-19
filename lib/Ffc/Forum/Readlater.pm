package Ffc::Forum;
use 5.18.0;
use strict; use warnings; use utf8;

###############################################################################
# Routen für die Beitragsvormerkungsliste erstellen
sub install_readlater_routes {
    my $l = $_[0];

    $l->route('/forum/readlater/list')->via('get')
      ->to(controller => 'forum', action => 'list_readlater')
      ->name('list_readlater');
    $l->route('/forum/readlater/:topicid/mark/:postid', topicid => $Ffc::Digqr, postid => $Ffc::Digqr)->via('get')
      ->to(controller => 'forum', action => 'mark_readlater')
      ->name('mark_readlater');
    $l->route('/forum/readlater/unmark/:postid')->via('get')
      ->to(controller => 'forum', action => 'unmark_readlater')
      ->name('unmark_readlater');
}

###############################################################################
# Vormerkung für Späterlesen eintragen
sub mark_readlater {
    my $c = $_[0];
    my ( $userid, $postid ) = ( $c->session->{userid}, $c->param('postid') );
    my $r =  $c->dbh_selectall_arrayref(
        'SELECT "postid" FROM "readlater" WHERE "postid"=? AND "userid"=?',
        $postid, $userid
    );
    if ( @$r ) {
        $c->set_info_f('Vormerkung besteht bereits');
    }
    else {
        $c->dbh_selectall_arrayref(
            'INSERT INTO "readlater" ("postid", "userid") VALUES (?,?)',
            $postid, $userid
        );
        $c->set_info_f('Beitrag wurde vorgemerkt')
    }
    $c->redirect_to('show_forum', topicid => $c->param('topicid'));
}

###############################################################################
# Vormerkung für Späterlesen wieder aufheben
sub unmark_readlater {
    my $c = $_[0];
    $c->dbh_selectall_arrayref(
        'DELETE FROM "readlater" WHERE "postid"=? AND "userid"=?',
        $c->param('postid'), $c->session->{userid}
    );
    $c->set_info_f('Vormerkung wurde aufgehoben');
    $c->redirect_to('list_readlater');
}

###############################################################################
# Liste der Späterlesen-Vormerkungen anzeigen
sub list_readlater {
    my $c = $_[0];
    $c->counting();
    $c->stash(rposts => 
        $c->dbh_selectall_arrayref(
            $c->get_show_sql('r."postid" IS NOT NULL'),
            $c->session->{userid}, $c->pagination()
        )
    );
    $c->render(template => 'readlater');
}

1;
