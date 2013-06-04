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

use Test::More tests => 32;

Test::General::test_prepare();
sub r { &Test::General::test_r }

use_ok('Ffc::Data::Board::Avatars');

my $user       = Mock::Testuser->new_active_user();
my ( $testfh1, $testfile1 ) = File::Temp::tempfile(SUFFIX => '.png', CLEANUP => 1);
my ( $testfh2, $testfile2 ) = File::Temp::tempfile(SUFFIX => '.jpg', CLEANUP => 1);
my $teststr1 = r();
my $teststr2 = r();
print $testfh1 $teststr1; close $testfh1;
print $testfh2 $teststr2; close $testfh2;
my $check1      = '';
my $code1 = sub { $check1 = "@_"; copy $testfile1, $_[0] };
my $avatarfile1 = "$user->{name}.png";
my $check2      = '';
my $code2 = sub { $check2 = "@_"; copy $testfile2, $_[0] };
my $avatarfile2 = "$user->{name}.jpg";

sub check_avatar {
    (
        Ffc::Data::dbh()->selectrow_array(
            'SELECT avatar FROM ' . $Ffc::Data::Prefix . 'users WHERE name=?',
            undef, $user->{name}
        )
    )[0];
}

ok( !Ffc::Data::Board::Avatars::get_avatar_path( $user->{name} ),
    'no avatar set for user' );
ok( !check_avatar(), 'no avatar in database for user' );

#############################################################################
note 'first run';
{
    my @ret = check_call(
        \&Ffc::Data::Board::Avatars::upload_avatar,
        upload_avatar => {
            name     => 'username',
            good     => $user->{name},
            bad      => [ '', Test::General::test_get_non_username() ],
            errormsg => [ 'Kein Benutzername angegeben', 'Benutzer unbekannt' ],
            emptyerror => 'Kein Benutzername angegeben',
        },
        {
            name => 'uploadfile',
            good => $testfile1,
            bad  => [ '', r() . '.doc' ],
            errormsg =>
              [ 'Avatardateiname fehlt', 'Avatar muss eine Bilddatei sein' ],
            emptyerror => 'Avatardateiname fehlt',
        },
        {
            name     => 'movetocode',
            good     => $code1,
            bad      => [ '', r() ],
            errormsg => [
                'Weiß nicht, was ich mit der Avatardatei machen muss',
'Benötige eine Code-Referenz, um mit der Avatardatei umgehen zu können'
            ],
            emptyerror =>
              'Weiß nicht, was ich mit der Avatardatei machen muss',
        },
    );

    is( $ret[0], $avatarfile1, 'avatar file name returned' );
}
is( check_avatar(), $avatarfile1, 'avatar set in database' );
is( $check1, "$Ffc::Data::AvatarDir/$avatarfile1", 'avatarfile path is there' );
ok( -e $check1, 'avatar file exists');
{
    open my $fh, '<', $check1 or die qq'could not open test avatar file "$check1": $!';
    local $/;
    is( <$fh>, $teststr1, 'avatar file contains correct data' );
}

{
    my @ret = check_call(
        \&Ffc::Data::Board::Avatars::get_avatar_path,
        get_avatar_path => {
            name     => 'username',
            good     => $user->{name},
            bad      => [ '', Test::General::test_get_non_username() ],
            errormsg => [ 'Kein Benutzername angegeben', 'Benutzer unbekannt' ],
            emptyerror => 'Kein Benutzername angegeben',
        },
    );
    is( $ret[0], "$Ffc::Data::AvatarUrl/$avatarfile1", 'avatar file name returned' );
}

#############################################################################
note 'second run';

{
    my $ret;
    eval { $ret = Ffc::Data::Board::Avatars::upload_avatar($user->{name}, $testfile2, $code2) };
    ok(!$@, 'no error while resetting the avatar file');
    is( $ret, $avatarfile2, 'avatar file name returned' );
}
is( check_avatar(), $avatarfile2, 'avatar set in database' );
is( $check2, "$Ffc::Data::AvatarDir/$avatarfile2", 'avatarfile path is there' );
ok(!-e $check1, 'old avatar file is gone');
ok( -e $check2, 'new avatar file exists');
{
    open my $fh, '<', $check2 or die qq'could not open test avatar file "$check2": $!';
    local $/;
    is( <$fh>, $teststr2, 'avatar file contains correct data' );
}
{
    my $ret;
    eval { $ret = Ffc::Data::Board::Avatars::get_avatar_path( $user->{name} ) };
    ok(!$@, 'no error while resetting the avatar file');
    diag($@) if $@;
    is( $ret, "$Ffc::Data::AvatarUrl/$avatarfile2", 'avatar file name returned' );
}

END { unlink $check1; unlink $check2; unlink $testfile1; unlink $testfile2 }

