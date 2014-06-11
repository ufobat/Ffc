package Ffc::Plugin::Posts; # Delete
use 5.010;
use strict; use warnings; use utf8;

use File::Spec qw(catfile);

sub _delete_post_check {
    my $c = shift;
    $c->stash( dourl => $c->url_for('delete_'.$c->stash('controller').'_do', $c->additional_params) );
    _setup_stash($c);
    return unless _get_single_post($c, @_);
    $c->render( template => 'delete_check' );
}

sub _delete_post_do {
    my $c = shift;
    my ( $wheres, @wherep ) = $c->where_modify;
    my $postid = $c->param('postid');
    unless ( $postid and $postid =~ $Ffc::Digqr ) {
        $c->set_error('Konnte den Beitrag nicht ändern, da die Beitragsnummer irgendwie verloren ging');
        return $c->show();
    }
    {
        my $sql = q~SELECT "id" FROM "posts" WHERE "id"=?~;
        $sql   .= qq~ AND $wheres~ if $wheres;
        my $post = $c->dbh->selectall_arrayref( $sql, undef, $postid, @wherep );
        unless ( @$post ) {
            $c->set_error('Der angegebene Beitrag konnte nicht entfernt werden.');
            return $c->show();
        }
    }
    my $atts = 0;
    {
        my $sql = q~SELECT "id" FROM "attachements" WHERE "postid"=?~;
        my $r = $c->dbh->selectall_arrayref( $sql, undef, $postid );
        $atts = @$r;
        my $delerr = 0;
        for my $r ( @$r ) {
            my $file = catfile(@{$c->datapath}, 'uploads', $r->[0]);
            unlink $file or $delerr++;
        }
        $c->set_warning("$delerr Anhänge konnten nicht entfernt werden.")
            if $delerr;
    }
    if ( $atts ) {
        my $sql = q~DELETE FROM "attachements" WHERE "postid"=?~;
        $c->dbh->do( $sql, undef, $postid );
    }
    {
        my $sql = q~DELETE FROM "posts" WHERE "id"=?~;
        $sql   .= qq~ AND $wheres~ if $wheres;
        $c->dbh->do( $sql, undef, $postid, @wherep );
    }
    $c->set_info('Der Beitrag wurde komplett entfernt');
    $c->show();
}


1;

