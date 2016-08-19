package Ffc::Forum;
use 5.18.0;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

use Ffc::Forum::Topics;
use Ffc::Forum::Readlater;

###############################################################################
sub install_routes { 
    my $l = shift;

    # Themenlisten-Routen einrichten
    Ffc::Forum::install_topics_routes($l);
    
    # Späterlesen-Routen einrichten
    Ffc::Forum::install_readlater_routes($l);

    # Standardrouten für die Beitragsbehandlung
    Ffc::Plugin::Posts::install_routes_posts($l, 'forum', '/topic/:topicid', topicid => $Ffc::Digqr);
}

###############################################################################
sub where_select { 
    my $topicid = $_[0]->param('topicid');
    if ( $topicid ) {
        my $action = $_[0]->stash('action');
        if ( $action =~ m~\A(?:delete|edit|upload|move)~xmsio ) {
            return 
                'p."userto" IS NULL AND p."topicid"=? AND p."userfrom"=?',
                $topicid, $_[0]->session->{userid};
        }
        return 
            'p."userto" IS NULL AND p."topicid"=?',
            $topicid;
    }
    else {
        return 'p."userto" IS NULL';
    }
}
###############################################################################
sub where_modify {
    return
        '"userto" IS NULL AND "topicid"=? AND "userfrom"=?',
        $_[0]->param('topicid'), $_[0]->session->{userid};
}

###############################################################################
sub additional_params {
    return topicid => $_[0]->param('topicid');
}

###############################################################################
sub show_startuppage {
    if ( $_[0]->configdata->{starttopic} ) {
        $_[0]->redirect_to('show_forum', topicid => $_[0]->configdata->{starttopic});
    }
    else {
        $_[0]->show_topiclist;
    }
}

###############################################################################
sub show {
    my $c = shift;
    my ( $uid, $topicid ) = ( $c->session->{userid}, $c->param('topicid') );
    my ( $heading, $userfrom ) = $c->_get_title_from_topicid;
    return unless $heading;
    $c->stash(
        topicid      => $topicid,
        backurl      => $c->url_for('show_forum_topiclist'),
        backtext     => 'zur Themenliste',
        msgurl       => 'show_pmsgs',
        moveurl      => 'move_forum_topiclist',
        heading      => $heading,
    );
    $c->stash( topicediturl => $c->url_for('edit_forum_topic_form', topicid => $topicid) )
        if $uid eq $userfrom or $c->session->{admin};
    $c->set_lastseen( $uid, $topicid );
    $c->show_posts();
}

###############################################################################
sub add { 
    my $c = shift; 
    my $topicid = $c->param('topicid');
    $c->dbh_do( 'UPDATE "lastseenforum" SET "mailed"=0 WHERE "topicid"=?', $topicid );
    $c->add_post( undef, $topicid, @_ ) }

###############################################################################
sub edit_form {
    my $c = shift;
    $c->stash( heading => 
        'Beitrag zum Thema "' . $c->_get_title_from_topicid . '" ändern' );
    $c->edit_post_form();
}

###############################################################################
sub edit_do { $_[0]->edit_post_do(undef, $_[0]->param('topicid')) }

###############################################################################
sub delete_check {
    my $c = shift;
    $c->stash( heading => 
        'Beitrag zum Thema "' . $c->_get_title_from_topicid . '" entfernen' );
    $c->delete_post_check();
}


###############################################################################
sub upload_form {
    my $c = shift;
    $c->stash( heading => 
        'Eine Datei zum Beitrag zum Thema "' . $c->_get_title_from_topicid . '" anhängen' );
    $c->upload_post_form();
}


###############################################################################
sub delete_upload_check {
    my $c = shift;
    $c->stash( heading => 
        'Eine Datei zum Beitrag zum Thema "' . $c->_get_title_from_topicid . '" löschen' );
    $c->delete_upload_post_check();
}

###############################################################################
# Hier ist der einzige Ort, wo High-Scores gezählt werden
sub inc_highscore { $_[0]->inc_post_highscore() }
sub dec_highscore { $_[0]->dec_post_highscore() }

###############################################################################
# Das wird direkt durechgeleitet
sub search           { $_[0]->search_posts()          }
sub query            { $_[0]->query_posts             }
sub set_postlimit    { $_[0]->set_post_postlimit()    }
sub upload_do        { $_[0]->upload_post_do()        }
sub download         { $_[0]->download_post()         }
sub delete_upload_do { $_[0]->delete_upload_post_do() }
sub delete_do        { $_[0]->delete_post_do()        }

1;
