package Ffc::Forum;
use strict; use warnings; use utf8;

sub mark_readlater {
    my $c = shift;
    $c->redirect_to('show_posts');
}

sub unmark_readlater {
    my $c = shift;
    $c->dbh_selectall_arrayref(
        'DELETE FROM "readlater" WHERE "postid"=? AND "userid"=?',
        $c->param('postid'), $c->session->{userid}
    );
    $c->redirect_to('list_readlater');
}

sub list_readlater {
    my $c = shift;
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

