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
                eval {
                $post =
                  Ffc::Data::Board::Views::get_post( $s->{act}, $id,
                    $c->get_params($s) );
                };
                $c->info_stash($@);
            },
            msg =>
'Beitrag, zu dem etwas hochgeladen wurde, konnte nicht ermittelt werden',
            after_error => sub { $c->stash(postid => ''); $c->frontpage() },
            after_ok    => sub {
                $post->{active} = 1;
                $c->stash( post => $post );
                $c->render('board/uploadform');
            },
        }
    );
}

sub upload {
    my $c      = shift;
    my $file   = $c->param('attachedfile');
    my $postid = $c->param('postid');
    my $desc   = $c->param('description');
    $c->error_handling(
        {
            code => sub {
                Ffc::Data::Board::Upload::upload( $c->session->{user},
                    $postid, $file->filename, $desc,
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
    $c->stash( footerlinks => $Ffc::Data::Footerlinks );
    my $s = $c->session;
    my $id = $c->param('postid');
    my $attid = $c->param('number');
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
                $c->render('board/uploaddeletecheck');
            },
        }
    );
}

sub upload_delete {
    my $c = shift;
    $c->error_handling( { 
        code        => sub { 
            Ffc::Data::Board::Upload::delete_upload(
                $c->session()->{user}, 
                $c->param('postid'), 
                $c->param('number'),
            );
        }, 
        msg         => 'Anhang konnte nicht gelöscht werden',
        after_error => sub { $c->frontpage() },
        after_ok    => sub { 
            $c->info('Ahnang wurde gelöscht'); 
            $c->redirect_to_show();
        },
    } );
}

sub get_attachement {
    my $c = shift;
    my $postid = $c->param('postid');
    my $number = $c->param('number');
    my $user   = $c->session()->{user};
    my $attachement = $c->or_empty(sub { Ffc::Data::Board::Upload::get_attachement($user, $postid, $number) });
    my $path;
    if ( @$attachement and -e $attachement->[3] ) {
        $c->res->headers->header('Content-Disposition' => "attachment;filename=$attachement->[0]");
        $path = $attachement->[2];
    }
    else {
        $c->res->headers->header('Content-Disposition' => "attachment;filename=nofile.png");
        $path = "$Ffc::Data::Themedir/".$c->theme().'/img/nofile.png';
    }
    $c->render_static($path);
}

1;

