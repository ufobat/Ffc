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

use Test::More tests => 1;

Test::General::test_prepare();
sub r { &Test::General::test_r }

use_ok('Ffc::Data::Board::Upload');

my $user1 = Mock::Testuser->new_active_user();
my $user2 = Mock::Testuser->new_active_user();
my $user3 = Mock::Testuser->new_active_user();

my @del;

sub get_testfile {
    my ( $testfh, $testfile ) = File::Temp::tempfile(SUFFIX => '.dat', CLEANUP => 1);
    my $teststr = r();
    print $testfh $teststr; 
    close $testfh;
    push @del, $testfile;
    return $testfile, $teststr;
}
my ( $testfile1, $teststr1 ) = get_testfile();
my ( $testfile2, $teststr2 ) = get_testfile();
my ( $testfile3, $teststr3 ) = get_testfile();

my $move_to_code1 = sub { push @del, $_[0]; copy $testfile1, $_[0] };
my $move_to_code2 = sub { push @del, $_[0]; copy $testfile2, $_[0] };
my $move_to_code3 = sub { push @del, $_[0]; copy $testfile3, $_[0] };

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

