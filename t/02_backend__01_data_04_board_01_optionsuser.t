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
use Ffc::Data::Auth;
srand;

use Test::More tests => 17;

Test::General::test_prepare();

use_ok('Ffc::Data::Board::OptionsUser');

{
    note('sub update_email( $userid, $email )');
    {
        my $user = Test::General::test_get_rand_user();
        $user->{email} = Test::General::test_r() . $user->{email};
        check_call(
            \&Ffc::Data::Board::OptionsUser::update_email,
            update_user_stats => {
                name => 'userid',
                good => Ffc::Data::Auth::get_userid( $user->{name} ),
                bad  => [
                    '',                      '        ',
                    Test::General::test_r(), $Test::General::Maxuserid + 1
                ],
                errormsg => [
                    'Keine Benutzerid angegeben',
                    'Benutzer ungültig',
                    'Benutzer ungültig',
                    'Benutzer unbekannt'
                ],
                emptyerror => 'Keine Benutzerid angegeben',
            },
            {
                name     => 'email',
                good     => $user->{email},
                bad      => [ '', '   ', 'a' x 1026 ],
                errormsg => [
                    'Keine Emailadresse angegeben',
                    'Neue Emailadresse schaut komisch aus',
                    'Neue Emailadresse ist zu lang'
                ],
                emptyerror => 'Keine Emailadresse angegeben',
            },
        );
    }
    {
        my $user = Test::General::test_get_rand_user();
        my $userid = Ffc::Data::Auth::get_userid( $user->{name} );
        my $get_email = sub { Ffc::Data::dbh()->selectrow_arrayref('SELECT u.email FROM '.$Ffc::Data::Prefix.'users u WHERE u.id=?', undef, $userid)->[0] };
        my $oldemail = $user->{email};
        my $newemail = Test::General::test_r() . $user->{email};
        isnt($oldemail, $newemail, 'email adresses are different');
        my $get_oldemail = $get_email->();
        is($oldemail, $get_oldemail, 'old email in database correct');
        ok(Ffc::Data::Board::OptionsUser::update_email($userid, $newemail), 'call ok');
        my $get_newemail = $get_email->();
        ok( $get_newemail, 'email adress in database ok after change');
        isnt($get_oldemail, $get_newemail, 'email adress was changed in database');
        is($newemail, $get_newemail, 'new email in database correct');
    }
}

{
    note('sub update_password( $userid, $oldpw, $newpw1, $newpw2 )');

}
{
    note('sub update_show_images( $sessionhash, $cross )');

}
{
    note('sub update_theme( $sessionhash, $themename )');

}

