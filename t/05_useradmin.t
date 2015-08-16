use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 692;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user, $pass ) = qw(test test1234);

sub admin_login { Testinit::test_login(  $t, $admin, $apass             ) }
sub user_login  { Testinit::test_login(  $t, $user,  $pass              ) }
sub logout      { Testinit::test_logout( $t                             ) }
sub error_login { $t->content_like(        qr'Fehler bei der Anmeldung' ) }
sub error       { Testinit::test_error(  $t, @_                         ) }
sub info        { Testinit::test_info(   $t, @_                         ) }
sub trandstr    { Testinit::test_randstring(                            ) }

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
  ->content_like(qr'active activeoptions">Einstellungen<')
  ->content_like(qr'Neuen Benutzer anlegen')
  ->content_like(qr'<form action="/options/admin/useradd#useradmin" method="POST">');

note 'nonadmins shall not see useradmin forms';
$dbh->do('UPDATE users SET admin=0 WHERE UPPER(name)=UPPER(?)', undef, $admin);
$t->get_ok('/options/form')
  ->status_is(200)
  ->content_like(qr'active activeoptions">Einstellungen<')
  ->content_unlike(qr'Neuen Benutzer anlegen')
  ->content_unlike(qr'<form action="/options/admin/useradd#useradmin" method="POST">');

$t->post_ok('/options/admin/useradd', form => {})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
error('Nur Administratoren dürfen das');
is @{get_users()}, 1, 'user count ok';
$t->post_ok("/options/admin/usermod/$admin", form => {})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
error('Nur Administratoren dürfen das');
is @{get_users()}, 1, 'user count ok';

note 'admins shall see useradmin forms';
$dbh->do('UPDATE users SET admin=1 WHERE UPPER(name)=UPPER(?)', undef, $admin);
$t->get_ok('/options/form')
  ->status_is(200)
  ->content_like(qr'active activeoptions">Einstellungen<')
  ->content_like(qr'Neuen Benutzer anlegen')
  ->content_like(qr'<form action="/options/admin/useradd#useradmin" method="POST">');

note 'wrong use of useradmin interface';
$t->post_ok('/options/admin/useradd', form => {})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
error(q~Benutzername nicht angegeben~);
is @{get_users()}, 1, 'user count ok';

$t->post_ok('/options/admin/useradd', form => {username => 'a'})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
error(q~Benutzername passt nicht \\(muss zwischen 2 und 32 Buchstaben haben\\)~);
is @{get_users()}, 1, 'user count ok';

$t->post_ok('/options/admin/useradd', form => {username => ('a' x 33)})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
error(q~Benutzername passt nicht \\(muss zwischen 2 und 32 Buchstaben haben\\)~);
is @{get_users()}, 1, 'user count ok';
  
$t->post_ok('/options/admin/useradd', form => {username => $user})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
error(q~Neuen Benutzern muss ein Passwort gesetzt werden~);
is @{get_users()}, 1, 'user count ok';

$t->post_ok('/options/admin/useradd', form => {username => $user, newpw1 => $pass})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
error(q~Neuen Benutzern muss ein Passwort gesetzt werden~);
is @{get_users()}, 1, 'user count ok';

$t->post_ok('/options/admin/useradd', form => {username => $user, newpw1 => $pass, newpw2 => "$pass#"})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
error(q~Passworte stimmen nicht überein~);
is @{get_users()}, 1, 'user count ok';

note 'new inactive user';
$t->post_ok('/options/admin/useradd', form => {username => $user, newpw1 => $pass, newpw2 => $pass})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
info(qq~Benutzer \&quot;$user\&quot; angelegt~);
is @{get_users()}, 2, 'user count ok';

logout();
$t->post_ok('/login', form => { username => $user, password => $pass })
  ->status_is(403);
error_login();

dump_user();

note 'new active adminuser';
$t->post_ok('/options/admin/useradd', form => {username => $user, newpw1 => $pass, newpw2 => $pass, active => 1, admin => 1})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
info(qq~Benutzer \&quot;$user\&quot; angelegt~);
is @{get_users()}, 2, 'user count ok';
user_login();

$t->get_ok('/options/form')
  ->content_like(qr~Angemeldet als "$user"~)
  ->content_like(qr'active activeoptions">Einstellungen<')
  ->content_like(qr'Neuen Benutzer anlegen')
  ->content_like(qr'<form action="/options/admin/useradd#useradmin" method="POST">');

dump_user();

note 'new active normal user';
$t->post_ok('/options/admin/useradd', form => {username => $user, newpw1 => $pass, newpw2 => $pass, active => 1})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
info(qq~Benutzer \&quot;$user\&quot; angelegt~);
is @{get_users()}, 2, 'user count ok';
user_login();

$t->get_ok('/options/form')
  ->content_like(qr~Angemeldet als "$user"~)
  ->content_like(qr'active activeoptions">Einstellungen<')
  ->content_unlike(qr'Neuen Benutzer anlegen')
  ->content_unlike(qr'<form action="/options/admin/useradd#useradmin" method="POST">');

note 'alter user password via admin login without overwrite-check';
admin_login();
my $newpass = "$pass#";
$t->post_ok("/options/admin/usermod/$user", form => {newpw1 => $newpass, newpw2 => $newpass, active => 1})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
error(q~Benutzer existiert bereits, das Überschreiben-Häkchen ist allerdings nicht gesetzt~);
is @{get_users()}, 2, 'user count ok';
logout();
$t->post_ok('/login', form => { username => $user, password => $newpass })
  ->status_is(403);
error_login();
user_login();

note 'alter user password via admin login';
admin_login();
my $oldpass = $pass;
$pass = $newpass;
$t->post_ok("/options/admin/usermod/$user", form => {newpw1 => $pass, newpw2 => $pass, active => 1, overwriteok => 1})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
info(qq~Benutzer \&quot;$user\&quot; geändert~);
is @{get_users()}, 2, 'user count ok';
logout();
$t->post_ok('/login', form => { username => $user, password => $oldpass })
  ->status_is(403);
error_login();
user_login();

note 'disable user';
admin_login();
$t->post_ok("/options/admin/usermod/$user", form => {active => 0})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
error(q~Benutzer existiert bereits, das Überschreiben-Häkchen ist allerdings nicht gesetzt~);
is get_user($user)->{active}, 1, 'user still active';
$t->post_ok("/options/admin/usermod/$user", form => {active => 0, overwriteok => 1})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
info(qq~Benutzer \&quot;$user\&quot; geändert~);
is get_user($user)->{active}, 0, 'user now inactive';
logout();
$t->post_ok('/login', form => { username => $user, password => $pass })
  ->status_is(403);
error_login();

note 'reenable user';
admin_login();
$t->post_ok("/options/admin/usermod/$user", form => {active => 1})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
error(q~Benutzer existiert bereits, das Überschreiben-Häkchen ist allerdings nicht gesetzt~);
is get_user($user)->{active}, 0, 'user still inactive';
$t->post_ok("/options/admin/usermod/$user", form => {active => 1, overwriteok => 1})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
info(qq~Benutzer \&quot;$user\&quot; geändert~);
is get_user($user)->{active}, 1, 'user is active again';
user_login();

note 'set admin flag for user';
admin_login();
$t->post_ok("/options/admin/usermod/$user", form => {admin => 1, active => 1})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
error(q~Benutzer existiert bereits, das Überschreiben-Häkchen ist allerdings nicht gesetzt~);
is get_user($user)->{admin}, 0, 'user still no admin';
user_login();
$t->get_ok('/options/form')
  ->content_like(qr~Angemeldet als "$user"~)
  ->content_like(qr'active activeoptions">Einstellungen<')
  ->content_unlike(qr'Neuen Benutzer anlegen')
  ->content_unlike(qr'<form action="/options/admin/useradd#useradmin" method="POST">');
admin_login();
$t->post_ok("/options/admin/usermod/$user", form => {admin => 1, active => 1, overwriteok => 1})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
info(qq~Benutzer \&quot;$user\&quot; geändert~);
is get_user($user)->{admin}, 1, 'user is now admin';
user_login();
$t->get_ok('/options/form')
  ->content_like(qr~Angemeldet als "$user"~)
  ->content_like(qr'active activeoptions">Einstellungen<')
  ->content_like(qr'Neuen Benutzer anlegen')
  ->content_like(qr'<form action="/options/admin/useradd#useradmin" method="POST">');

note 'unset admin flag for user';
admin_login();
$t->post_ok("/options/admin/usermod/$user", form => {admin => 0, active => 1})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
error(q~Benutzer existiert bereits, das Überschreiben-Häkchen ist allerdings nicht gesetzt~);
is get_user($user)->{admin}, 1, 'user still admin';
user_login();
$t->get_ok('/options/form')
  ->content_like(qr~Angemeldet als "$user"~)
  ->content_like(qr'active activeoptions">Einstellungen<')
  ->content_like(qr'Neuen Benutzer anlegen')
  ->content_like(qr'<form action="/options/admin/useradd#useradmin" method="POST">');
admin_login();
$t->post_ok("/options/admin/usermod/$user", form => {admin => 0, active => 1, overwriteok => 1})
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200);
info(qq~Benutzer \&quot;$user\&quot; geändert~);
is get_user($user)->{admin}, 0, 'user no admin anymore';
user_login();
$t->get_ok('/options/form')
  ->content_like(qr~Angemeldet als "$user"~)
  ->content_like(qr'active activeoptions">Einstellungen<')
  ->content_unlike(qr'Neuen Benutzer anlegen')
  ->content_unlike(qr'<form action="/options/admin/useradd#useradmin" method="POST">');

note 'show user email adresses for administrators';
my @users = ([$user,'', $pass]);

sub add_testuser {
    my $email = shift() ? 1 : '';
    note 'generate new test users';
    note 'test user has email adress' if $email;
    my ( $user, $pass ) = (trandstr(), trandstr());
    $email = trandstr().'@home.de' if $email;
    $t->post_ok('/options/admin/useradd', form => {username => $user, newpw1 => $pass, newpw2 => $pass, active => 1})
      ->status_is(302)->content_is('')->header_is(Location => '/options/form');
    $t->get_ok('/options/form')->status_is(200);
    info(qq~Benutzer \&quot;$user\&quot; angelegt~);
    if ( $email ) {
        Testinit::test_login( $t, $user, $pass );
        $t->post_ok('/options/email', form => { email => $email })
          ->status_is(302)->content_is('')->header_is(Location => '/options/form');
        $t->get_ok('/options/form')->status_is(200);
        info('Email-Adresse geändert');
        admin_login();
    }
    push @users, [$user, $email, $pass];
}
sub test_emailadresses {
    note 'check that user email adresses visible for admin';
    for my $u ( @users ) {
        $t->get_ok('/options/form');
        if ( $u->[1] ) {
            $t->content_like(
             qr~<h2>Benutzer &quot;$u->[0]&quot; ändern \($u->[1]\):</h2>~);
        }
        else {
            $t->content_like(
             qr~<h2>Benutzer &quot;$u->[0]&quot; ändern:</h2>~);
        }
    }
}
sub test_emailadresslist {
    note 'check that user email adress list visible for admin';
    my $emailadresslist = join '; ', map { $_->[1] || () } sort {uc($a->[0]) cmp uc($b->[0])} @users;
    $t->get_ok('/options/form');
    if ( $emailadresslist ) {
        $t->content_like(qr~<h2>Liste verfügbarer Emailadressen:</h2>~)
          ->content_like(qr~<p>$emailadresslist</p>~);
    }
    else {
        $t->content_unlike(qr~<h2>Liste verfügbarer Emailadressen:</h2>~);
    }
}
sub test_no_other_emailadresses_visible {
    note 'check that normal users are unable to see user email adresses';
    for my $u ( @users ) {
        Testinit::test_login( $t, $u->[0], $u->[2] );
        $t->get_ok('/options/form')
          ->content_like(qr~Angemeldet als "$u->[0]"~)
          ->content_unlike(qr~<h2>Liste verfügbarer Emailadressen:</h2>~);
        for my $tu ( @users ) {
            next if $tu->[0] eq $u->[0];
            next unless $tu->[1];
            $t->content_unlike(qr~$tu->[1]~);
        }
    }
    admin_login();
}

test_no_other_emailadresses_visible();
test_emailadresslist();
test_emailadresses();
add_testuser(1);
test_no_other_emailadresses_visible();
test_emailadresslist();
test_emailadresses();
add_testuser();
test_no_other_emailadresses_visible();
test_emailadresslist();
test_emailadresses();
add_testuser(1);
test_no_other_emailadresses_visible();
test_emailadresslist();
test_emailadresses();

