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
use File::Path;
srand;

use Test::More tests => 186;

Test::General::test_prepare();
sub r { &Test::General::test_r }
my @del;

use_ok('Ffc::Data::Board::Upload');
$Ffc::Data::UploadDir = File::Temp::tempdir();
die qq'tmp test upload dir "$Ffc::Data::UploadDir" does not exist' unless -e -d $Ffc::Data::UploadDir;

my $user1 = Mock::Testuser->new_active_user();
my $user2 = Mock::Testuser->new_active_user();
my $user3 = Mock::Testuser->new_active_user();
$_->{id} = Ffc::Data::Auth::get_userid($_->{name}) for $user1, $user2, $user3;

#############################################################################
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
#############################################################################
for ( 1..3 ) {
    note '$dir = sub make_url( $postid, $anum )';
    my ( $postid, $anum ) = map { 3 + int rand 99 } 0 .. 1;
    my @ret = check_call(
        \&Ffc::Data::Board::Upload::make_url,
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
    is $ret[0], "$Ffc::Data::UploadUrl/$postid-$anum", 'path ok';
}

#############################################################################
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
my ( $testfile4, $teststr4 ) = get_testfile();
my ( $testfile5, $teststr5 ) = get_testfile();
my ( $testfile6, $teststr6 ) = get_testfile();

my $poststr1 = r();
my $poststr2 = r();
my $poststr3 = r();
Ffc::Data::Board::Forms::insert_post($user1->{name}, $poststr1, undef, undef);
my $postid1 = Test::General::test_get_max_postid();
Ffc::Data::Board::Forms::insert_post($user1->{name}, $poststr2, undef, $user1->{name});
my $postid2 = Test::General::test_get_max_postid();
Ffc::Data::Board::Forms::insert_post($user1->{name}, $poststr3, undef, $user2->{name});
my $postid3 = Test::General::test_get_max_postid();

#############################################################################
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
            emptyerror => 'Dateiname "" ungültig',
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
#############################################################################
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
    is $ret[0][0], 'newfile1.dat', 'filename ok';
    is $ret[0][1], 'descr1', 'description ok';
    like $ret[0][2], qr/$Ffc::Data::UploadUrl/, 'url ok';
    is $ret[0][3], $del[-1], 'real path ok';
}
#############################################################################
{
    note '[ $filename, $descr, $number ] = sub get_attachement_list( $username, $postid )';
    my @ret = check_call(
        \&Ffc::Data::Board::Upload::get_attachement_list,
        get_attachement_list =>
        {
            name => 'userid',
            good => $user1->{id},
            bad  => ['', ' ', 'aa', Mock::Testuser::get_noneexisting_userid(), $user3->{id}],
            emptyerror => 'Keine Benutzerid angegeben',
            errormsg   => ['Keine Benutzerid angegeben', 'Benutzer ungültig', 'Benutzer ungültig', 'Ungültiger Beitrag'],
        },
        {
            name => 'postid',
            good => $postid3,
            bad  => ['', ' ', 'as'],
            emptyerror => 'Ungültiger Beitrag',
            errormsg => [('Ungültiger Beitrag') x 3],
        },
    );
    is $ret[0][0][0], 'newfile1.dat', 'filename ok';
    is $ret[0][0][1], 'descr1', 'description ok';
    is $ret[0][0][2], 1, 'attachement number ok';
    is $ret[0][0][3], $postid3, 'postid ok';
    like $ret[0][0][4], qr/$Ffc::Data::UploadUrl/, 'url ok';
    is $ret[0][0][5], $del[-1], 'real path ok';
}
#############################################################################
{
    note '$one = sub delete_upload( $username, $postid, $attachementnr )';
    my $attid = Ffc::Data::dbh()->selectall_arrayref('SELECT MAX(a.number) FROM '.$Ffc::Data::Prefix.'attachements a WHERE a.postid=?', undef, $postid3)->[0]->[0];
    my $delfile = $del[-1];
    Ffc::Data::Board::Upload::upload($user1->{name}, $postid3, 'newfile2.dat', 'descr2', sub { push @del, $_[0]; copy $testfile2, $_[0] } );
    my @ret = check_call(
        \&Ffc::Data::Board::Upload::delete_upload,
        delete_upload =>
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
            bad  => ['', ' ', 'as'],
            emptyerror => 'Ungültiger Anhang',
        },
    );
    ok !-e $delfile, 'file deleted';
    ok -e $del[-1], 'other file still exists';
    my $ret = Ffc::Data::dbh()->selectall_arrayref('SELECT a.number, a.filename FROM '.$Ffc::Data::Prefix.'attachements a WHERE a.postid=?', undef, $postid3);
    is @$ret, 1, 'attachement count ok';
    is $ret->[0]->[0], 2, 'attachement number ok';
    is $ret->[0]->[1], 'newfile2.dat', 'attachement filename ok';
}
#############################################################################
{
    note '$one = sub delete_upload( $username, $postid, $attachementnr ) # Logic check';
    Ffc::Data::Board::Upload::upload($user1->{name}, $postid1, 'newcfile4.dat', 'descr3', sub { push @del, $_[0]; copy $testfile4, $_[0] } );
    my $attid1 = Ffc::Data::dbh()->selectall_arrayref('SELECT MAX(a.number) FROM '.$Ffc::Data::Prefix.'attachements a WHERE a.postid=?', undef, $postid1)->[0]->[0];
    Ffc::Data::Board::Upload::upload($user1->{name}, $postid1, 'newcfile4.dat', 'descr4', sub { push @del, $_[0]; copy $testfile5, $_[0] } );
    my $attid2 = Ffc::Data::dbh()->selectall_arrayref('SELECT MAX(a.number) FROM '.$Ffc::Data::Prefix.'attachements a WHERE a.postid=?', undef, $postid1)->[0]->[0];
    cmp_ok $attid1, '<', $attid2, 'new upload has higher number';
    Ffc::Data::Board::Upload::delete_upload($user1->{name}, $postid1, $attid1);
    Ffc::Data::Board::Upload::upload($user1->{name}, $postid1, 'newcfile4.dat', 'descr4', sub { push @del, $_[0]; copy $testfile6, $_[0] } );
    my $attid3 = Ffc::Data::dbh()->selectall_arrayref('SELECT MAX(a.number) FROM '.$Ffc::Data::Prefix.'attachements a WHERE a.postid=?', undef, $postid1)->[0]->[0];
    cmp_ok $attid2, '<', $attid3, 'new upload has higher number';
}
#############################################################################
{
    note '$one = sub delete_attachements( $username, $postid )';
    my @check;
    Ffc::Data::Board::Upload::upload($user1->{name}, $postid1, 'newfile3.dat', 'descr3', sub { push @del, $_[0]; copy $testfile2, $_[0] } );
    push @check, $del[-1];
    Ffc::Data::Board::Upload::upload($user1->{name}, $postid1, 'newfile4.dat', 'descr4', sub { push @del, $_[0]; copy $testfile2, $_[0] } );
    push @check, $del[-1];
    Ffc::Data::Board::Upload::upload($user1->{name}, $postid1, 'newfile5.dat', 'descr5', sub { push @del, $_[0]; copy $testfile2, $_[0] } );
    push @check, $del[-1];
    my @ret = check_call(
        \&Ffc::Data::Board::Upload::delete_attachements,
        delete_upload =>
        {
            name => 'username',
            good => $user1->{name},
            bad  => ['', ' ', Test::General::test_get_non_username(), $user3->{name}],
            emptyerror => 'Kein Benutzername angegeben',
            errormsg   => ['Kein Benutzername angegeben', 'Benutzername ungültig', 'Benutzer unbekannt', 'Ungültiger Beitrag'],
        },
        {
            name => 'postid',
            good => $postid1,
            bad  => ['', ' ', 'as'],
            emptyerror => 'Ungültiger Beitrag',
        },
    );
    is $ret[0], 5, 'delete count ok';
    ok !-e $_, 'file deleted' for @check;
    my $ret = Ffc::Data::dbh()->selectall_arrayref('SELECT COUNT(a.number) FROM '.$Ffc::Data::Prefix.'attachements a WHERE a.postid=?', undef, $postid1);
    is $ret->[0]->[0], 0, 'attachement count ok';
}
#############################################################################
{
    note 'check uploads for several kinds of posts';
    for my $id ( $postid1, $postid2, $postid3 ) {
        my $file = '';
        Ffc::Data::Board::Upload::upload($user1->{name}, $id, "newfile_7_$id.dat", "descr_7_$id", sub { push @del, $_[0]; $file = $_[0]; copy $testfile3, $_[0] } );
        ok $file, "filename '$file' exists";
        ok -e $file, "file '$file' exists";
        my $attid = Ffc::Data::dbh()->selectall_arrayref('SELECT MAX(a.number) FROM '.$Ffc::Data::Prefix.'attachements a WHERE a.postid=?', undef, $id)->[0]->[0];
        ok $attid, "attachement id '$attid' found";
        eval { Ffc::Data::Board::Upload::delete_upload($user2->{name}, $id, $attid) };
        ok $@, 'error received';
        like $@, qr/Benutzer\s+nicht\s+berechtigt/xmsi, 'error message seems legit';
        ok -e $file, "file '$file' still exists, user not allowed to delete it";
        Ffc::Data::Board::Upload::delete_upload($user1->{name}, $id, $attid);
        ok !-e $file, "file '$file' deleted";
    }
}
#############################################################################
{
    note 'delete post';
    Ffc::Data::Board::Upload::upload($user1->{name}, $postid1, 'newfile6.dat', 'descr6', sub { push @del, $_[0]; copy $testfile3, $_[0] } );
    check_call(
        \&Ffc::Data::Board::Forms::delete_post,
        delete_post => {
            name => 'user name',
            good => $user1->{name},
            bad  => [ '', '   ', Mock::Testuser::get_noneexisting_username() ],
            errormsg => [
                'Kein Benutzername angegeben',
                'Benutzername ungültig',
                'Benutzer unbekannt',
            ],
            emptyerror => 'Kein Benutzername angegeben',
        },
        {
            name => 'post id',
            good => $postid1,
            bad  => [ '', '  ', 'aaaa' ],
            errormsg   => [ 'Keine Postid angegeben', 'Postid ungültig' ],
            emptyerror => 'Keine Postid angegeben',
        },
    );
    ok(!(Ffc::Data::dbh()->selectrow_array('SELECT COUNT(id) FROM '.$Ffc::Data::Prefix.'posts WHERE id=?', undef, $postid1 ))[0], 'posting does not exist after deletion anymore' );
    ok(!(Ffc::Data::dbh()->selectrow_array('SELECT COUNT(number) FROM '.$Ffc::Data::Prefix.'attachements WHERE postid=?', undef, $postid1 ))[0], 'attachements do not exist after deletion anymore' );
    ok !-e $del[-1], 'attachement is deleted together with the post';
}

#############################################################################
END {
    my $errors;
    unlink $_ for @del;
    File::Path::rmtree($Ffc::Data::UploadDir, {error => \$errors});
    diag join "\n", @$errors if @$errors;
}

