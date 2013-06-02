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

use Test::More tests => 23;

Test::General::test_prepare();
sub r { &Test::General::test_r }

use_ok('Ffc::Data::Board::Avatars');

my $user       = Mock::Testuser->new_active_user();
my ( $testfh, $testfile ) = File::Temp::tempfile(SUFFIX => '.png', CLEANUP => 1);
my $teststr = r();
print $testfh $teststr;
close $testfh;
my $check      = '';
my $code = sub { $check = "@_"; copy $testfile, $_[0] };
my $avatarfile = "$user->{name}.png";

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
            good => $testfile,
            bad  => [ '', r() . '.doc' ],
            errormsg =>
              [ 'Avatardateiname fehlt', 'Avatar muss eine Bilddatei sein' ],
            emptyerror => 'Avatardateiname fehlt',
        },
        {
            name     => 'movetocode',
            good     => $code,
            bad      => [ '', r() ],
            errormsg => [
                'Weiß nicht, was ich mit der Avatardatei machen muss',
'Benötige eine Code-Referenz, um mit der Avatardatei umgehen zu können'
            ],
            emptyerror =>
              'Weiß nicht, was ich mit der Avatardatei machen muss',
        },
    );

    is( $ret[0], $avatarfile, 'avatar file name returned' );
}
is( check_avatar(), $avatarfile, 'avatar set in database' );
is( $check, "$Ffc::Data::AvatarDir/$avatarfile", 'avatarfile path is there' );
ok( -e $check, 'avatar file exists');
{
    open my $fh, '<', $check or die qq'could not open test avatar file "$check": $!';
    local $/;
    is( <$fh>, $teststr, 'avatar file contains correct data' );
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
    is( $ret[0], "$Ffc::Data::AvatarUrl/$avatarfile", 'avatar file name returned' );
}

END { unlink $check; unlink $testfile }

