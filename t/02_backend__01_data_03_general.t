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

use Test::More tests => 26;

note('doing some preparations');
my $config = Mock::Config->new->{config};
my $app    = Mojolicious->new();
$app->log->level('error');
Ffc::Data::set_config($app);
Mock::Database::prepare_testdatabase();
my @users = ( Mock::Testuser->new_active_user() );
my @categories = @{ Ffc::Data::dbh()->selectall_arrayref('SELECT "id", "name", "short" FROM '.$Ffc::Data::Prefix.'categories') };

use_ok('Ffc::Data::General');

sub r { 
    my @chars = ( 'a'..'z', 'A'..'Z', 0..9 ); 
    return join '', map { $chars[int rand scalar @chars]} 0 .. 7 + int rand 5;
}
sub _get_rand_category_short { $categories[int rand scalar @categories][2] }

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
    note(' sub check_category_short_rules( $cshort )');
    check_call( \&Ffc::Data::General::check_category_short_rules,
        check_category_short_rules =>
        {
            name => 'category short name',
            good => substr(r(), 0, 64),
            bad => ['', '    ', substr(r(), 0, 2).'/'.substr(r(), 0, 3)],
            emptyerror => 'Kein Kategoriekürzel angegeben',
            errormsg => [ 'Kein Kategoriekürzel angegeben', 'Kategoriekürzel ungültig' ],
        },
    );
    ok( Ffc::Data::General::check_category_short_rules( substr(r(), 0, 64) ), 'category short fits the rules' );
}
{   
    note('sub get_category_id( $cshort )');
    check_call( \&Ffc::Data::General::get_category_id,
        get_category_id =>
        {
            name => 'category short name',
            good => _get_rand_category_short(),
            bad => ['', '    ', substr(r(), 0, 2).'/'.substr(r(), 0, 3)],
            emptyerror => 'Kein Kategoriekürzel angegeben',
            errormsg => [ 'Kein Kategoriekürzel angegeben', 'Kategoriekürzel ungültig' ],
        },
    );
    like( Ffc::Data::General::get_category_id(_get_rand_category_short()), qr(\d+), 'category id found' );
    {
        my $short = _get_rand_category_short();
        my $id = ( grep { $_->[2] eq $short } @categories )[0][0];
        is( Ffc::Data::General::get_category_id($short), $id, 'category id correct' );
    }
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

