package Ffc::Forum;
use 5.18.0;
use strict; use warnings; use utf8;

###############################################################################
# Die Daten für die Themenliste sammeln
sub _calculate_topiclist {
    my $c = $_[0];
    $c->counting;
    $c->session->{query} = '';

    # Die Themenliste muss bei der ersten Seite nicht neu erzeugt werden, sondern kann
    # direkt aus dem Menü mit übernommen werden - die Daten sind ja immer die gleichen
    my $page = $c->param('page') // 1;
    $page == 1
        ? $c->stash(topics_for_list => $c->stash('topics'))
        : $c->generate_topiclist('topics_for_list');

    # Webseite mit weiteren Metadaten füllen und erzeugen lassen
    $c->stash(
        page     => $page,
        pageurl  => 'show_forum_topiclist_page',
        returl   => $c->url_for('show_forum_topiclist'),
        queryurl => $c->url_for('search_forum_posts'),
    );
}

###############################################################################
# Die Themenliste als Inline-HTML ausliefern
sub get_topiclist { 
    _calculate_topiclist($_[0]);
    $_[0]->render(text => $_[0]->render_to_string(template => 'parts/topiclist')); 
}

###############################################################################
# Die Themenlisten-Webseite anzeigen
sub show_topiclist { 
    _calculate_topiclist($_[0]);
    $_[0]->render(template => 'topiclist'); 
}

###############################################################################
# Sortierungsrichtung einstellen
sub sort_order_chronological { _set_sort_order_cron_do( $_[0], 1, 'Themen werden chronologisch sortiert.' ) }
sub sort_order_alphabetical  { _set_sort_order_cron_do( $_[0], 0, 'Themen werden alphabetisch sortiert.'  ) }
# Handler
sub _set_sort_order_cron_do {
    my ( $c, $v, $t ) = @_;
    $c->dbh_do( 'UPDATE "users" SET "chronsortorder"=? WHERE "id"=?' , $v, $c->session->{userid});
    $c->session->{chronsortorder} = $v;
    $c->set_info_f($t);
    $c->redirect_to('show_forum_topiclist');
}

###############################################################################
# Anzahl der auf einer Seite angezeigten Themen browserseitig einstellen
sub set_topiclimit {
    my $c = $_[0];
    my $topiclimit = $c->param('topiclimit');

    # Themenlisten-Anzeigeanzahl prüfen, ob sie im Rahmen ist (dass es eine Zahl ist, dafür sorgt die Route)
    if ( $topiclimit < 1 or $topiclimit > 127 ) {
        $c->set_error_f('Die Anzahl der auf einer Seite in der Liste angezeigten Überschriften muss eine ganze Zahl kleiner 128 sein.');
        $c->redirect_to('show_forum_topiclist');
        return;
    }

    # Themenlisten-Anzahl übernehmen (Browserseitige Speicherung)
    $c->session->{limits}->{$c->session->{userid}}->{topiclimit} = $c->session->{topiclimit} = $topiclimit;
    $c->set_info_f("Anzahl der auf einer Seite der Liste angezeigten Überschriften auf $topiclimit geändert.");
    $c->redirect_to('show_forum_topiclist');
}

1;
