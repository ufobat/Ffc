use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 341;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user, $pass ) = qw(test test1234);

sub admin_login { Testinit::test_login(  $t, $admin, $apass             ) }
sub user_login  { Testinit::test_login(  $t, $user,  $pass              ) }
sub logout      { Testinit::test_logout( $t                             ) }
sub error_login { Testinit::test_error(  $t, 'Fehler bei der Anmeldung' ) }
sub error       { Testinit::test_error(  $t, @_                         ) }
sub info        { Testinit::test_info(   $t, @_                         ) }

sub get_users   { 
    $dbh->selectall_arrayref('SELECT name, active, admin FROM users ORDER BY id')
}
sub get_user    { 
    my $r = $dbh->selectall_arrayref('SELECT name, active, admin FROM users WHERE name = ?', undef, $_[0]);
    return unless $r and @$r;
    return {
        name   => $r->[0]->[0],
        active => $r->[0]->[1],
        admin  => $r->[0]->[2],
    };
}

sub dump_user {
    logout();
    $dbh->do('DELETE FROM users WHERE UPPER(name)=UPPER(?)', undef, $user);
    is @{get_users()}, 1, 'user count ok';
    admin_login();
}

note 'admin login';
admin_login();
$t->get_ok('/options/form')
  ->status_is(200)
  ->content_like(qr'active activeoptions">Optionen<')
  ->content_like(qr'Neuen Benutzer anlegen')
  ->content_like(qr'<form action="/options/adminuseradd" method="POST">');

note 'nonadmins shall not see useradmin forms';
$dbh->do('UPDATE users SET admin=0 WHERE UPPER(name)=UPPER(?)', undef, $admin);
$t->get_ok('/options/form')
  ->status_is(200)
  ->content_like(qr'active activeoptions">Optionen<')
  ->content_unlike(qr'Neuen Benutzer anlegen')
  ->content_unlike(qr'<form action="/options/adminuseradd" method="POST">');

$t->post_ok('/options/adminuseradd', form => {})
  ->status_is(200);
error('Nur Administratoren dürfen das');
is @{get_users()}, 1, 'user count ok';
$t->post_ok("/options/adminusermod/$admin", form => {})
  ->status_is(200);
error('Nur Administratoren dürfen das');
is @{get_users()}, 1, 'user count ok';

note 'admins shall see useradmin forms';
$dbh->do('UPDATE users SET admin=1 WHERE UPPER(name)=UPPER(?)', undef, $admin);
$t->get_ok('/options/form')
  ->status_is(200)
  ->content_like(qr'active activeoptions">Optionen<')
  ->content_like(qr'Neuen Benutzer anlegen')
  ->content_like(qr'<form action="/options/adminuseradd" method="POST">');

note 'wrong use of useradmin interface';
$t->post_ok('/options/adminuseradd', form => {})
  ->status_is(200);
error(q~Benutzername nicht angegeben~);
is @{get_users()}, 1, 'user count ok';

$t->post_ok('/options/adminuseradd', form => {username => 'a'})
  ->status_is(200);
error(q~Benutzername passt nicht \\(muss zwischen 2 und 32 Buchstaben haben\\)~);
is @{get_users()}, 1, 'user count ok';

$t->post_ok('/options/adminuseradd', form => {username => ('a' x 33)})
  ->status_is(200);
error(q~Benutzername passt nicht \\(muss zwischen 2 und 32 Buchstaben haben\\)~);
is @{get_users()}, 1, 'user count ok';
  
$t->post_ok('/options/adminuseradd', form => {username => $user})
  ->status_is(200);
error(q~Neuen Benutzern muss ein Passwort gesetzt werden~);
is @{get_users()}, 1, 'user count ok';

$t->post_ok('/options/adminuseradd', form => {username => $user, newpw1 => $pass})
  ->status_is(200);
error(q~Neuen Benutzern muss ein Passwort gesetzt werden~);
is @{get_users()}, 1, 'user count ok';

$t->post_ok('/options/adminuseradd', form => {username => $user, newpw1 => $pass, newpw2 => "$pass#"})
  ->status_is(200);
error(q~Passworte stimmen nicht überein~);
is @{get_users()}, 1, 'user count ok';

note 'new inactive user';
$t->post_ok('/options/adminuseradd', form => {username => $user, newpw1 => $pass, newpw2 => $pass})
  ->status_is(200);
info(qq~Benutzer \&quot;$user\&quot; angelegt~);
is @{get_users()}, 2, 'user count ok';

logout();
$t->post_ok('/login', form => { username => $user, password => $pass })
  ->status_is(200);
error_login();

dump_user();

note 'new active adminuser';
$t->post_ok('/options/adminuseradd', form => {username => $user, newpw1 => $pass, newpw2 => $pass, active => 1, admin => 1})
  ->status_is(200);
info(qq~Benutzer \&quot;$user\&quot; angelegt~);
is @{get_users()}, 2, 'user count ok';
user_login();

$t->get_ok('/options/form')
  ->content_like(qr~Angemeldet als "$user"~)
  ->content_like(qr'active activeoptions">Optionen<')
  ->content_like(qr'Neuen Benutzer anlegen')
  ->content_like(qr'<form action="/options/adminuseradd" method="POST">');

dump_user();

note 'new active normal user';
$t->post_ok('/options/adminuseradd', form => {username => $user, newpw1 => $pass, newpw2 => $pass, active => 1})
  ->status_is(200);
info(qq~Benutzer \&quot;$user\&quot; angelegt~);
is @{get_users()}, 2, 'user count ok';
user_login();

$t->get_ok('/options/form')
  ->content_like(qr~Angemeldet als "$user"~)
  ->content_like(qr'active activeoptions">Optionen<')
  ->content_unlike(qr'Neuen Benutzer anlegen')
  ->content_unlike(qr'<form action="/options/adminuseradd" method="POST">');

note 'alter user password via admin login without overwrite-check';
admin_login();
my $newpass = "$pass#";
$t->post_ok("/options/adminusermod/$user", form => {newpw1 => $newpass, newpw2 => $newpass, active => 1})
  ->status_is(200);
error(q~Benutzer existiert bereits, das Überschreiben-Häkchen ist allerdings nicht gesetzt~);
is @{get_users()}, 2, 'user count ok';
logout();
$t->post_ok('/login', form => { username => $user, password => $newpass })
  ->status_is(200);
error_login();
user_login();

note 'alter user password via admin login';
admin_login();
my $oldpass = $pass;
$pass = $newpass;
$t->post_ok("/options/adminusermod/$user", form => {newpw1 => $pass, newpw2 => $pass, active => 1, overwriteok => 1})
  ->status_is(200);
info(qq~Benutzer \&quot;$user\&quot; geändert~);
is @{get_users()}, 2, 'user count ok';
logout();
$t->post_ok('/login', form => { username => $user, password => $oldpass })
  ->status_is(200);
error_login();
user_login();

note 'disable user';
admin_login();
$t->post_ok("/options/adminusermod/$user", form => {active => 0})
  ->status_is(200);
error(q~Benutzer existiert bereits, das Überschreiben-Häkchen ist allerdings nicht gesetzt~);
is get_user($user)->{active}, 1, 'user still active';
$t->post_ok("/options/adminusermod/$user", form => {active => 0, overwriteok => 1})
  ->status_is(200);
info(qq~Benutzer \&quot;$user\&quot; geändert~);
is get_user($user)->{active}, 0, 'user now inactive';
logout();
$t->post_ok('/login', form => { username => $user, password => $pass })
  ->status_is(200);
error_login();

note 'reenable user';
admin_login();
$t->post_ok("/options/adminusermod/$user", form => {active => 1})
  ->status_is(200);
error(q~Benutzer existiert bereits, das Überschreiben-Häkchen ist allerdings nicht gesetzt~);
is get_user($user)->{active}, 0, 'user still inactive';
$t->post_ok("/options/adminusermod/$user", form => {active => 1, overwriteok => 1})
  ->status_is(200);
info(qq~Benutzer \&quot;$user\&quot; geändert~);
is get_user($user)->{active}, 1, 'user is active again';
user_login();

note 'set admin flag for user';
admin_login();
$t->post_ok("/options/adminusermod/$user", form => {admin => 1, active => 1})
  ->status_is(200);
error(q~Benutzer existiert bereits, das Überschreiben-Häkchen ist allerdings nicht gesetzt~);
is get_user($user)->{admin}, 0, 'user still no admin';
user_login();
$t->get_ok('/options/form')
  ->content_like(qr~Angemeldet als "$user"~)
  ->content_like(qr'active activeoptions">Optionen<')
  ->content_unlike(qr'Neuen Benutzer anlegen')
  ->content_unlike(qr'<form action="/options/adminuseradd" method="POST">');
admin_login();
$t->post_ok("/options/adminusermod/$user", form => {admin => 1, active => 1, overwriteok => 1})
  ->status_is(200);
info(qq~Benutzer \&quot;$user\&quot; geändert~);
is get_user($user)->{admin}, 1, 'user is now admin';
user_login();
$t->get_ok('/options/form')
  ->content_like(qr~Angemeldet als "$user"~)
  ->content_like(qr'active activeoptions">Optionen<')
  ->content_like(qr'Neuen Benutzer anlegen')
  ->content_like(qr'<form action="/options/adminuseradd" method="POST">');

note 'unset admin flag for user';
admin_login();
$t->post_ok("/options/adminusermod/$user", form => {admin => 0, active => 1})
  ->status_is(200);
error(q~Benutzer existiert bereits, das Überschreiben-Häkchen ist allerdings nicht gesetzt~);
is get_user($user)->{admin}, 1, 'user still admin';
user_login();
$t->get_ok('/options/form')
  ->content_like(qr~Angemeldet als "$user"~)
  ->content_like(qr'active activeoptions">Optionen<')
  ->content_like(qr'Neuen Benutzer anlegen')
  ->content_like(qr'<form action="/options/adminuseradd" method="POST">');
admin_login();
$t->post_ok("/options/adminusermod/$user", form => {admin => 0, active => 1, overwriteok => 1})
  ->status_is(200);
info(qq~Benutzer \&quot;$user\&quot; geändert~);
is get_user($user)->{admin}, 0, 'user no admin anymore';
user_login();
$t->get_ok('/options/form')
  ->content_like(qr~Angemeldet als "$user"~)
  ->content_like(qr'active activeoptions">Optionen<')
  ->content_unlike(qr'Neuen Benutzer anlegen')
  ->content_unlike(qr'<form action="/options/adminuseradd" method="POST">');

