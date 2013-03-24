use strict;
use warnings;
use 5.010;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Mojolicious;
use Mock::Config;
use Mock::Database;
use Mock::Testuser;
use Mock::Controller::App;
use Test::Callcheck;
srand;

use Test::More tests => 13;

note('doing some preparations');
my $config = Mock::Config->new->{config};
my $app    = Mojolicious->new();
$app->log->level('error');
Ffc::Data::set_config($app);
Mock::Database::prepare_testdatabase();
my @users = ( Mock::Testuser->new_active_user() );

use_ok('Ffc::Data::General');

{
    note('sub check_password_change( $newpw1, $newpw2, $oldpw )');
    my $user = $users[-1];
    my $old_password = $user->{password};
    $user->alter_password();
    my $new_password = $user->{password};
    check_call( \&Ffc::Data::General::check_password_change,
        check_password_change =>
        {
            name => 'new password',
            good => $new_password,
            bad => ['', '        ', substr($new_password, 0,5)],
            errormsg => ['Kein Passwort', 'Passwort ungültig'],
            emptyerror => 'Kein Passwort',
        },
        {
            name => 'new password repeat',
            good => $new_password,
            bad => [$old_password, '', '        ', substr($new_password, 0,5)],
            errormsg => ['Das neue Passwort und dessen Wiederholung stimmen nicht', 'Kein Passwort', 'Passwort ungültig'],
            emptyerror => 'Kein Passwort',
        },
        {
            name => 'old password',
            good => $old_password,
            bad => ['        ', substr($old_password, 0,5)],
            errormsg => ['Passwort ungültig'],
            noemptycheck => 1,
        },
    );
}
{   
    note('sub get_category_id( $cshort )');
}
{
    note('sub check_category( $cshort )');
}
{
    note('sub get_useremail( $userid )');
}
{
    note('sub get_userlist()');
}
{
    note('sub get_category( $catid )');
}

