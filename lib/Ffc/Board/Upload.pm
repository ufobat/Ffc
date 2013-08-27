package Ffc::Board::Upload;

use 5.010;
use strict;
use warnings;
use utf8;

use base 'Ffc::Board::Errors';

use Ffc::Data;
use Ffc::Data::Board::Views;
use Ffc::Data::Board::Upload;

sub upload_form {
    my $c = shift;
    $c->stash( footerlinks => $Ffc::Data::Footerlinks );
    my $s = $c->session;
    my $id = $c->param('postid');
    $c->get_counts();
    my $post;
    $c->error_handling(
        {
            code => sub {
                $post =
                  Ffc::Data::Board::Views::get_post( $s->{act}, $id,
                    $c->get_params($s) );
            },
            msg =>
'Beitrag, zu dem etwas hochgeladen wurde, konnte nicht ermittelt werden',
            after_error => sub { $c->frontpage() },
            after_ok    => sub {
                $post->{active} = 1;
                $c->stash( post => $post );
                $c->render('board/uploadform');
            },
        }
    );
}

sub upload {
    my $c = shift;
    my $file = $c->param('attachedfile');
    $c->error_handling(
        {
            code => sub {
                Ffc::Data::Board::Upload::upload( $c->session->{user},
                    $c->param('postid'),
                    $file->filename,
                    $c->param('description'),
                    sub { $file->move_to(@_) },
                );
            },
            msg => 'Datei konnte nicht hochgeladen werden',
            after_ok =>
              sub { $c->info('Datei wurde hochgeladen'); $c->redirect_to_show() },
        }
    );
    $c->redirect_to_show();
}

sub upload_delete_check {
    my $c = shift;
}

sub upload_delete {
    my $c = shift;
}

sub get_attachement {
    my $c = shift;
    $c->render_static(
            Ffc::Data::Board::Upload::get_attachement_path($c->session->{user})
         || "$Ffc::Data::Themedir/".$c->session->{theme}.'/img/nofile.png'
    );
}

1;

