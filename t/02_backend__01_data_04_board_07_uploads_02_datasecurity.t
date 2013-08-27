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

use Test::More tests => 79;

Test::General::test_prepare();
sub r { &Test::General::test_r }

use_ok('Ffc::Data::Board::Upload');

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

for my $t ( @testmatrix ) {
    my ( $from, $to, $avail, $hidden ) = @$t;
    
    my $poststr = r();
    Ffc::Data::Board::Forms::insert_post($from->{name}, $poststr, undef, $to ? $to->{name} : undef);
    my $postid = Test::General::test_get_max_postid();

    my ( $testfile1, $teststr1 ) = get_testfile();
    my ( $testfile2, $teststr2 ) = get_testfile();
    my ( $testfile3, $teststr3 ) = get_testfile();
    
    {
        eval {
            Ffc::Data::Board::Upload::upload($from->{name}, $postid, "$poststr.1.dat", "Desc 1. $poststr", sub { push @del, $_[0]; copy $testfile1, $_[0] } );
            Ffc::Data::Board::Upload::upload($from->{name}, $postid, "$poststr.2.dat", "Desc 2. $poststr", sub { push @del, $_[0]; copy $testfile2, $_[0] } );
            Ffc::Data::Board::Upload::upload($from->{name}, $postid, "$poststr.3.dat", "Desc 3. $poststr", sub { push @del, $_[0]; copy $testfile3, $_[0] } );
        };
        ok !$@, 'no error reported';
    }

    my $attid = Ffc::Data::dbh()->selectall_arrayref('SELECT MAX(a.number) FROM '.$Ffc::Data::Prefix.'attachements a WHERE a.postid=?', undef, $postid)->[0]->[0];

    for my $u ( $u2, $u3 ) {
        my ( $testfile4, $teststr4 ) = get_testfile();
        eval { Ffc::Data::Board::Upload::upload($u->{name}, $postid, "$poststr.4.dat", "Desc 4. $poststr", sub { push @del, $_[0]; copy $testfile4, $_[0] } ) };
        ok $@, 'error received, user is not allowed to upload a file';
        like $@, qr'Ungültiger Beitrag für den Benutzer um Anhänge dran zu hängen', 'error message ok';
    }

    note 'check who can see';
    for my $u ( @$avail ) {
        note '[ $filename, $descr, $number ] = sub get_attachement_list( $username, $postid )';
        my $ret = Ffc::Data::Board::Upload::get_attachement_list($u->{id}, $postid);
        is @$ret, 3, 'correct count of attachements';
        note '( $filename, $descr, $path ) = sub get_attachement( $username, $postid, $attachementnr )';
        my @ret = Ffc::Data::Board::Upload::get_attachement($u->{name}, $postid, $attid);
        is $ret[0], "$poststr.3.dat", 'filename received';
        ok -e $ret[2], 'file exists';
    }

    note q[check who can't see];
    for my $u ( @$hidden ) {
        note '[ $filename, $descr, $number ] = sub get_attachement_list( $username, $postid )';
        my $ret = Ffc::Data::Board::Upload::get_attachement_list($u->{id}, $postid);
        is @$ret, 0, 'correct count of attachements';
        note '( $filename, $descr, $path ) = sub get_attachement( $username, $postid, $attachementnr )';
        eval { Ffc::Data::Board::Upload::get_attachement($u->{name}, $postid, $attid) };
        ok $@, 'error resceived';
        like $@, qr(Anhang Nummer "$attid" ist unbekannt), 'error message ok';
    }

    note '$one = sub delete_upload( $username, $postid, $attachementnr )';
    for my $u ( $u2, $u3 ) {
        eval { Ffc::Data::Board::Upload::delete_upload($u->{name}, $postid, $attid ) };
        ok $@, 'error received, user is not allowed to delete an uploaded a file';
        like $@, qr'Anhang ungültig oder Benutzer nicht berechtigt, den genannten Anhang zu löschen', 'error message ok';
        ok -e $del[-1], 'file still exists';
    }
    {
        eval { Ffc::Data::Board::Upload::delete_upload($u1->{name}, $postid, $attid ) };
        ok !$@, 'no error received, user is allowed to delete an uploaded a file';
        diag $@ if $@;
        diag Dumper $t if $@;
    }
    note '$one = sub delete_attachements( $username, $postid )';
    for my $u ( $u2, $u3 ) {
        eval { Ffc::Data::Board::Upload::delete_attachements($u->{name}, $postid) };
        ok $@, 'error received, user is not allowed to delete all uploaded files';
        like $@, qr'Benutzer darf den Beitrag nicht löschen', 'error message ok';
    }
    {
        eval { Ffc::Data::Board::Upload::delete_attachements($u1->{name}, $postid ) };
        ok !$@, 'no error received, user is allowed to delete all uploaded files';
        diag $@ if $@;
    }
}

END { unlink $_ for @del }

