package Ffc::Forum;
use strict; use warnings; use utf8;

sub show_topiclist {
    my $c = shift;
    $c->counting;
    my $page = $c->param('page') // 1;
    $c->session->{query} = '';
    if ( $page == 1 ) {
        $c->stash(topics_for_list => $c->stash('topics'));
    }
    else {
        $c->generate_topiclist('topics_for_list');
    }
    $c->stash(
        page     => $page,
        pageurl  => 'show_forum_topiclist_page',
        returl   => $c->url_for('show_forum_topiclist'),
        queryurl => $c->url_for('search_forum_posts'),
    );

    $c->render(template => 'topiclist');
}

sub sort_order_chronological { 
    $_[0]->_set_sort_order_cron_do(1, 'Themen werden chronologisch sortiert.');
}
sub sort_order_alphabetical  {
    $_[0]->_set_sort_order_cron_do(0, 'Themen werden alphabetisch sortiert.');
}
sub _set_sort_order_cron_do {
    my ( $c, $v, $t ) = @_;
    $c->dbh_do(
        'UPDATE "users" SET "chronsortorder"=? WHERE "id"=?'
        , $v, $c->session->{userid}
    );
    $c->session->{chronsortorder} = $v;
    $c->set_info_f($t);
    $c->redirect_to('show_forum_topiclist');
}

sub set_topiclimit {
    my $c = $_[0];
    my $topiclimit = $c->param('topiclimit');
    unless ( $topiclimit =~ $Ffc::Digqr and $topiclimit > 0 and $topiclimit < 128 ) {
        $c->set_error_f('Die Anzahl der auf einer Seite in der Liste angezeigten Überschriften muss eine ganze Zahl kleiner 128 sein.');
        $c->redirect_to('show_forum_topiclist');
        return;
    }
    $c->session->{topiclimit} = $topiclimit;
    $c->dbh_do('UPDATE "users" SET "topiclimit"=? WHERE "id"=?',
        $topiclimit, $c->session->{userid});
    $c->set_info_f("Anzahl der auf einer Seite der Liste angezeigten Überschriften auf $topiclimit geändert.");
    $c->redirect_to('show_forum_topiclist');
}


1;

