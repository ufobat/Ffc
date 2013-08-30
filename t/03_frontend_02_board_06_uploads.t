use strict;
use warnings;
use 5.010;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Test::Callcheck;
use Test::General;
use Mock::Controller;
use Mock::Testuser;
use Ffc::Data::Board::Forms;
use File::Temp;
use File::Copy;
srand;

use Test::More tests => 5;

my $t = Test::General::test_prepare_frontend('Ffc');
sub r { &Test::General::test_r }

my $u1 = Mock::Testuser->new_active_user();
my $u2 = Mock::Testuser->new_active_user();
my $u3 = Mock::Testuser->new_active_user();
$_->{id} = Ffc::Data::Auth::get_userid($_->{name}) for $u1, $u2, $u3;

my @del;

sub get_testfile {
    my ( $testfh, $testfile ) = File::Temp::tempfile(SUFFIX => '.dat', CLEANUP => 1);
    my $teststr = r();
    print $testfh $teststr; 
    close $testfh;
    push @del, $testfile;
    return $testfile, $teststr;
}

my @testmatrix = (
#    from, to, available, hidden
    [ $u1, undef, [$u1, $u2, $u3], []         ],
    [ $u1, $u2,   [$u1, $u2],      [$u3]      ],
    [ $u1, $u1,   [$u1],           [$u2, $u3] ],
);

$t->get_ok('/logout');
$t->post_ok( '/login',
    form => { user => $u1->{name}, pass => $u1->{password} } )
  ->status_is(302)
  ->header_like( Location => qr{\Ahttps?://localhost:\d+/\z}xms );

#$t->post_ok(
#    '/options/avatar_save',
#    form => {
#        avatarfile => {
#            filename => $testfile,
#            file     => Mojo::Asset::Memory->new->add_chunk($teststr),
#            content_type => 'image/png',
#        }
#    }
#)->status_is(200);

END { unlink $_ for @del }

