use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 615;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user, $pass ) = qw(test test1234);
Testinit::test_add_user( $t, $admin, $apass, $user, $pass );
my @testkats;
sub admin { Testinit::test_login(      $t, $admin, $apass ) }
sub user  { Testinit::test_login(      $t, $user,  $pass  ) }
sub rstr  { Testinit::test_randstring()                     }
sub error { Testinit::test_error(      $t, @_             ) }
sub info  { Testinit::test_info(       $t, @_             ) }

my $maxid = 0;

# check that no user can see category management
sub check_user {
    user();
    $t->get_ok('/options/form')
      ->status_is(200)
      ->content_unlike(qr~<h1>Kategorieverwaltung</h1>~)
      ->content_unlike(qr~<h2>Neue Kategorie anlegen:</h2>~)
      ->content_unlike(qr~<h2>Kategorie \&quot;[^<]*\&quot; ändern:</h2>~);
    admin();
}

# check that admins can see correct category management
sub check_admin {
    $t->get_ok('/options/form')
      ->status_is(200)
      ->content_like(qr~<h1>Kategorieverwaltung</h1>~)
      ->content_like(qr~<h2>Neue Kategorie anlegen:</h2>~)
      ->content_like(qr~<form action="/options/admin/catadd#categoryadmin" method="POST">~);
    for my $kat ( @testkats ) {
        my $sbcq = $kat->[2] ? ' checked="checked"' : '';
        $t->content_like(qr~<div class="suboption categoryadmin_form">
    <h2>Kategorie &quot;$kat->[1]&quot; ändern:</h2>
    <form action="/options/admin/catmod/$kat->[0]#categoryadmin" method="POST">
        <input type="hidden" name="overwriteok" value="1" />
        <p>
            Kategoriename:
            <input type="text" name="catname" value="$kat->[1]" />
        </p>
        <p>
            <input type="checkbox" name="visible"$sbcq />
            ist sichtbar,
            <button type="submit" class="linkalike">Speichern</button>
        </p>
    </form>
</div>~);
    }
}

admin();

note 'check whether category handling is available for admins, not for normal users';
check_admin();
check_user();

note 'test add category errors';
{
    user();
    $t->post_ok('/options/admin/catadd', form => {})
      ->status_is(200);
    error('Nur Administratoren dürfen das');
    check_user();
    check_admin();
    $t->post_ok('/options/admin/catadd', form => {})
      ->status_is(200);
    error('Kategoriename nicht angegeben');
    check_user();
    check_admin();
}

note 'adding new visible categories';
for ( 1 .. 2 ) {
    my $tkat = [++$maxid, rstr(), 1];
    push @testkats, $tkat;
    $t->post_ok('/options/admin/catadd', form => {catname => $tkat->[1], visible => 1 })
      ->status_is(200);
    info(qq~Kategorie &quot;$tkat->[1]&quot; erstellt~);
    check_user();
    check_admin();
}
note 'adding new invisible categories';
for ( 1 .. 2 ) {
    my $tkat = [++$maxid, rstr(), 0];
    push @testkats, $tkat;
    $t->post_ok('/options/admin/catadd', form => {catname => $tkat->[1]})
      ->status_is(200);
    info(qq~Kategorie &quot;$tkat->[1]&quot; erstellt~);
    check_user();
    check_admin();
}

note 'error adding allready existing category';
$t->post_ok('/options/admin/catadd', form => {catname => $testkats[1][1]})
  ->status_is(200);
error('Die neue Kategorie gibt es bereits');
check_user();
check_admin();

note 'test modify category errors';
user();
$t->post_ok('/options/admin/catmod/1', form => {})
  ->status_is(200);
error('Nur Administratoren dürfen das');
check_user();
check_admin();
$t->post_ok('/options/admin/catmod/1', form => {})
  ->status_is(200);
error('Der Überschreiben-Check zum Ändern einer Kategorie ist nicht gesetzt');
check_user();
check_admin();
$t->post_ok('/options/admin/catmod/1', form => {overwriteok => 1})
  ->status_is(200);
error('Kategoriename nicht angegeben');
check_user();
check_admin();

note 'testing change category name into same name with visible unchanged';
$t->post_ok('/options/admin/catmod/2', form => {overwriteok => 1, catname => $testkats[1][1], visible => 1})
  ->status_is(200);
info(qq~Kategorie &quot;$testkats[1][1]&quot; geändert~);
check_user();
check_admin();

note 'testing change category name into same name with invisible changed';
$testkats[1][2] = 0;
$t->post_ok('/options/admin/catmod/2', form => {overwriteok => 1, catname => $testkats[1][1], visible => 0})
  ->status_is(200);
info(qq~Kategorie &quot;$testkats[1][1]&quot; geändert~);
check_user();
check_admin();

note 'testing change category name into same name with visible changed';
$testkats[1][2] = 1;
$t->post_ok('/options/admin/catmod/2', form => {overwriteok => 1, catname => $testkats[1][1], visible => 1})
  ->status_is(200);
info(qq~Kategorie &quot;$testkats[1][1]&quot; geändert~);
check_user();
check_admin();

note 'testing change category name into same name with visible unchanged';
$testkats[1] = [ 2, rstr(), 1 ];
$t->post_ok('/options/admin/catmod/2', form => {overwriteok => 1, catname => $testkats[1][1], visible => 1})
  ->status_is(200);
info(qq~Kategorie &quot;$testkats[1][1]&quot; geändert~);
check_user();
check_admin();

note 'testing change category name into same name with invisible changed';
$testkats[1] = [ 2, rstr(), 0 ];
$t->post_ok('/options/admin/catmod/2', form => {overwriteok => 1, catname => $testkats[1][1], visible => 0})
  ->status_is(200);
info(qq~Kategorie &quot;$testkats[1][1]&quot; geändert~);
check_user();
check_admin();

note 'testing change category name into same name with visible changed';
$testkats[1] = [ 2, rstr(), 1 ];
$t->post_ok('/options/admin/catmod/2', form => {overwriteok => 1, catname => $testkats[1][1], visible => 1})
  ->status_is(200);
info(qq~Kategorie &quot;$testkats[1][1]&quot; geändert~);
check_user();
check_admin();

