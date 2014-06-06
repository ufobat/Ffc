package Ffc::Plugin::Posts; # Create
use 5.010;
use strict; use warnings; use utf8;

sub _delete_upload_post_check {
    my $c = shift;
    $c->stash( dourl => $c->url_for('upload_'.$c->stash('controller').'_do' => $c->additional_params) );
    _setup_stash($c);
    _get_single_post($c, @_);
    $c->render( template => 'delete_upload_check' );
}

sub _delete_upload_post_do {
    my $c = shift;
    my ( $wheres, @wherep ) = $c->where_select;
    my $fileid = $c->param('fileid');
}

1;

