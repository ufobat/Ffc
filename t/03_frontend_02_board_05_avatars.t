#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Test::Mojo;
use Test::General;
use Mojo::Util;
use Mock::Testuser;
use Ffc::Data;

use Test::More tests => 12;
sub r { &Test::General::test_r }

srand;
my $t        = Test::General::test_prepare_frontend('Ffc');
my $user     = Mock::Testuser->new_active_user();
my $testfile = r() . ' Avatar.png';
my $teststr  = r();
my $destfile = "$Ffc::Data::AvatarDir/$user->{name}.png";

ok( !-e $destfile, 'file does not exist yet' );

$t->get_ok('/logout');
$t->post_ok( '/login',
    form => { user => $user->{name}, pass => $user->{password} } )
  ->status_is(302)
  ->header_like( Location => qr{\Ahttps?://localhost:\d+/\z}xms );

$t->post_ok(
    '/options/avatar_save',
    form => {
        avatarfile => {
            filename => $testfile,
            file     => Mojo::Asset::Memory->new->add_chunk($teststr),
            content_type => 'image/png',
        }
    }
)->status_is(200);
ok( -e $destfile, qq'file does exist now: $destfile' );

$t->get_ok("/show_avatar/$user->{name}")->status_is(200);
$t->content_like(qr($teststr));

END { unlink $testfile; unlink $destfile }
