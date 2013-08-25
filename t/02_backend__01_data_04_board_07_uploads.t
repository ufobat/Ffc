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

use Test::More tests => 11;

Test::General::test_prepare();
sub r { &Test::General::test_r }

use_ok('Ffc::Data::Board::Upload');

my $user = Mock::Testuser->new_active_user();
{
    note '$dir = sub make_path( $postid, $anum )';
    my ( $postid, $anum ) = map { 3 + int rand 99 } 0 .. 1;
    my @ret = check_call(
        \&Ffc::Data::Board::Upload::make_path,
        make_path =>
        {
            name => 'postid',
            good => $postid,
            bad  => ['', ' ', 'as'],
            emptyerror => 'Ungültiger Beitrag',
        },
        {
            name => 'anum',
            good => $anum,
            bad  => ['', ' ', 'as'],
            emptyerror => 'Ungültiger Anhang',
        },
    );
    is $ret[0], "$Ffc::Data::UploadDir/$postid-$anum", 'path ok';
}
note '$one = sub upload( $username, $postid, $newfile, $descr, $move_to_code )';
note '$one = sub delete_upload( $username, $postid, $attachementnr )';
note '( $filename, $descr, $path ) = sub get_attachement( $username, $postid, $attachementnr )';
note '[ $filename, $descr, $number ] = sub get_attachement_list( $username, $postid )';
