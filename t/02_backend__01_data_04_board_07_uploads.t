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

for ( 1..3 ) {
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

{
    note '$one = sub upload( $username, $postid, $newfile, $descr, $move_to_code )';
    my @ret = check_call(
        \&Ffc::Data::Board::Upload::upload,
        upload =>
        {
            name => 'username',
            good => $user1->{name},
            bad  => ['', ' ', Test::General::test_get_non_username()],
            emptyerror => 'Kein Benutzername angegeben',
            errormsg   => ['Kein Benutzername angegeben', 'Benutzername ungültig', 'Benutzer unbekannt'],
        },
        {
            name => 'postid',
            good => $postid3,
            bad  => ['', ' ', 'as', $postid3 + 1],
            emptyerror => 'Ungültiger Beitrag',
            errormsg   => [],
        },
        {
            name => 'newfile',
            good => 'newfile1.dat',
            bad  => [''],
            emptyerror => 'Dateiname ungültig',
        },
        {
            name => 'description',
            good => 'descr1',
            noemptycheck => 1,
        },
        {
            name => 'move_to_code',
            good => sub { push @del, $_[0]; copy $testfile1, $_[0] },
            bad  => ['', ' ', 'asd'],
            emptyerror => 'Weiß nicht, was ich mit der Datei machen soll',
        },
    );
    ok $ret[0], 'upload successful';
    ok -e $del[-1], 'file created';
}
{
    note '( $filename, $descr, $path ) = sub get_attachement( $username, $postid, $attachementnr )';
    my $attid = Ffc::Data::dbh()->selectall_arrayref('SELECT MAX(a.number) FROM '.$Ffc::Data::Prefix.'attachements a WHERE a.postid=?', undef, $postid3)->[0]->[0];
    my @ret = check_call(
        \&Ffc::Data::Board::Upload::get_attachement,
        get_attachement =>
        {
            name => 'username',
            good => $user1->{name},
            bad  => ['', ' ', Test::General::test_get_non_username(), $user3->{name}],
            emptyerror => 'Kein Benutzername angegeben',
            errormsg   => ['Kein Benutzername angegeben', 'Benutzername ungültig', 'Benutzer unbekannt', 'Ungültiger Beitrag'],
        },
        {
            name => 'postid',
            good => $postid3,
            bad  => ['', ' ', 'as', $postid3 + 1],
            emptyerror => 'Ungültiger Beitrag',
            errormsg => [('Ungültiger Beitrag') x 3, 'Ungültiger Anhang'],
        },
        {
            name => 'attid',
            good => $attid,
            bad  => ['', ' ', 'as', $attid + 1],
            emptyerror => 'Ungültiger Anhang',
            errormsg => [('Ungültiger Anhang') x 3, sprintf 'Anhang Nummer "%d" ist unbekannt', $attid + 1],
        },
    );
    is $ret[0], 'newfile1.dat', 'filename ok';
    is $ret[1], 'descr1', 'description ok';
    is $ret[2], $del[-1], 'real path ok';
}
note '[ $filename, $descr, $number ] = sub get_attachement_list( $username, $postid )';
note '$one = sub delete_upload( $username, $postid, $attachementnr )';

unlink $_ for @del;

