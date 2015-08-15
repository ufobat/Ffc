use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use Testinit;

use Test::More tests => 133;
use Test::Mojo;

my ( $t, $path, $admin, $pass, $dbh ) = Testinit::start_test();

note 'first attempt without login';
$t->get_ok('/');
check_notloggedin();
note 'try to logout without login before';
$t->get_ok('/logout');
check_notloggedin();
note 'failed login without data';
$t->post_ok('/login', form => { });
check_notloggedin();
note 'failed login without password';
$t->post_ok('/login', form => { username => $admin });
check_notloggedin();
$t->content_like(qr~Bitte melden Sie sich an~);
note 'failed login without username';
$t->post_ok('/login', form => { password => $pass });
check_notloggedin();
$t->content_like(qr~Bitte melden Sie sich an~);
note 'failed login with wrong password';
$t->post_ok('/login', form => { username => $admin, password => "#$pass#" });
check_notloggedin();
$t->content_like(qr'Fehler bei der Anmeldung');
$t->get_ok('/');
check_notloggedin();
note 'failed login with noneexisting username';
$t->post_ok('/login', form => { username => "#$admin#", password => $pass });
check_notloggedin();
$t->content_like(qr'Fehler bei der Anmeldung');
$t->get_ok('/');
check_notloggedin();
note 'working login';
$t->post_ok('/login', form => { username => $admin, password => $pass })
  ->status_is(302)
  ->header_like(location => qr~/~);
$t->get_ok('/');
check_loggedin();
note 'working logout';
$t->get_ok('/logout');
check_notloggedin();
note 'again failed login with wrong password';
$t->post_ok('/login', form => { username => $admin, password => "#$pass#" });
$t->content_like(qr'Fehler bei der Anmeldung');
check_notloggedin();

note 'failed login with inactive user';
$dbh->do('UPDATE users SET active=0 WHERE UPPER(name)=UPPER(?)', undef, $admin);
$t->post_ok('/login', form => { username => $admin, password => $pass });
$t->content_like(qr'Fehler bei der Anmeldung');
check_notloggedin();
note 'working login with active user';
$dbh->do('UPDATE users SET active=1 WHERE UPPER(name)=UPPER(?)', undef, $admin);
$t->post_ok('/login', form => { username => $admin, password => $pass })
  ->status_is(302)
  ->header_like(location => qr~/~);
$t->get_ok('/');
check_loggedin();
note 'test disabling user';
$dbh->do('UPDATE users SET active=0 WHERE UPPER(name)=UPPER(?)', undef, $admin);
$t->get_ok('/');
check_notloggedin();
$t->post_ok('/login', form => { username => $admin, password => $pass });
$t->content_like(qr'Fehler bei der Anmeldung');
check_notloggedin();
note 'test reenabling user';
$dbh->do('UPDATE users SET active=1 WHERE UPPER(name)=UPPER(?)', undef, $admin);
$t->get_ok('/');
check_notloggedin();
$t->post_ok('/login', form => { username => $admin, password => $pass })
  ->status_is(302)
  ->header_like(location => qr~/~);
$t->get_ok('/');
check_loggedin();

sub check_notloggedin {
    note 'check that i am not logged in';
    $t->status_is(200)
      ->content_like(qr/Angemeldet als "\&lt;noone\&gt;"/)
      ->content_like(qr/<input type="text" name="username"/)
      ->content_like(qr/<input type="password" name="password"/)
      ->content_like(qr~<form action="/login" method="POST">~i)
      ->content_like(qr~<input type="submit" value="anmelden" class="linkalike~);
}

sub check_loggedin {
    note 'check that i am logged in';
    $t->status_is(200)
      ->content_like(qr/Angemeldet als "$admin"/)
      ->content_unlike(qr~<form action="/login" method="POST">~i)
}
