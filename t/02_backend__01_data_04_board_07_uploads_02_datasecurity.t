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

use Test::More tests => 49;

Test::General::test_prepare();
sub r { &Test::General::test_r }
my @del;

use_ok('Ffc::Data::Board::Upload');

my $user1 = Mock::Testuser->new_active_user();
my $user2 = Mock::Testuser->new_active_user();
my $user3 = Mock::Testuser->new_active_user();

sub get_testfile {
    my ( $testfh, $testfile ) = File::Temp::tempfile(SUFFIX => '.dat', CLEANUP => 1);
    my $teststr = r();
    print $testfh $teststr; 
    close $testfh;
    return $testfile, $teststr;
}
my ( $testfile1, $teststr1 ) = get_testfile();
my ( $testfile2, $teststr2 ) = get_testfile();
my ( $testfile3, $teststr3 ) = get_testfile();

my $poststr1 = r();
my $poststr2 = r();
my $poststr3 = r();
Ffc::Data::Board::Forms::insert_post($user1->{name}, $poststr1, undef, undef);
my $postid1 = Test::General::test_get_max_postid();
Ffc::Data::Board::Forms::insert_post($user1->{name}, $poststr2, undef, $user1->{name});
my $postid2 = Test::General::test_get_max_postid();
Ffc::Data::Board::Forms::insert_post($user1->{name}, $poststr3, undef, $user2->{name});
my $postid3 = Test::General::test_get_max_postid();



unlink $_ for @del;

