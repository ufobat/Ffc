use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use Ffc::Plugin::Config;
use File::Temp qw~tempfile tempdir~;
use File::Spec::Functions qw(catfile catdir splitdir);
use Mojo::Util 'xml_escape';
use Data::Dumper;

use Test::Mojo;
use Test::More tests => 220;

#############################################################################
# Benutzer anlegen
my ( $t, $path, $aname, $apass, $dbh ) = Testinit::start_test();
# Benutzerobjekte zur Weiterverarbeitung
# ( admin = userid 1 !!! )
my ( $u2, $u3, $u4 ) = Testinit::make_userobjs($t, 3, $aname, $apass);
sub add_forum { Testinit::add_forum($_[0], 1, $_[2], $_[1]) }
sub add_pmsgs { Testinit::add_pmsgs(@_) }

#############################################################################
# Test-Sub für '/fetch'
# test_fetch( $user, $arr_topics_new, $arr_pmsgs_new );
sub test_fetch {
    my ( $u, $e_top, $e_msg ) = @_;
    note "---------- check user '$u->{userid}' for correct json-return of new posts";
    $u->{t}->post_ok('/fetch')->status_is(200);
    $u->{t}->json_is('/3' => $e_top);
    $u->{t}->json_is('/4' => $e_msg);
}
# reset_topic( $user, $id ); reset_pmsgs( $user, $id );
sub _reset { $_[0]->get_ok("$_[1]/$_[2]")->status_is(200) }
sub reset_topic { _reset($_[0]->{t}, '/topic', $_[1]) }
sub reset_pmsgs { _reset($_[0]->{t}, '/pmsgs', $_[1]) }

#############################################################################
# Neue Themen als Testwiese
note "---------- insert start";
# Id 1
$u2->{t}->post_ok('/topic/new',
    form => {
        titlestring => 'Topic1',
        textdata => 'Testbeitrag1',
    })->status_is(302)->content_is('');
add_forum($u2, 1, 'Testbeitrag1');
# Check Topic 1
$u3->{t}->get_ok('/topic/1')->status_is(200)
      ->content_like(qr~Topic1~)
      ->content_like(qr~Testbeitrag1~)
      ->content_like(qr~topicid\:\s*1,~)
      ->content_like(qr~usertoid\:\s*0,~);
reset_topic($u4, 1);
# Check Pmsgs 1
$u3->{t}->get_ok('/pmsgs/1')->status_is(200)
      ->content_like(qr~topicid\:\s*0,~)
      ->content_like(qr~usertoid\:\s*1,~);

# Id 2
$u3->{t}->post_ok('/topic/new',
    form => {
        titlestring => 'Topic2',
        textdata => 'Testbeitrag2',
    })->status_is(302)->content_is('');
add_forum($u3, 1, 'Testbeitrag2');
# Check Topic 2
$u2->{t}->get_ok('/topic/2')->status_is(200)
      ->content_like(qr~Topic2~)
      ->content_like(qr~Testbeitrag2~)
      ->content_like(qr~topicid\:\s*2,~)
      ->content_like(qr~usertoid\:\s*0,~);
reset_topic($u4, 2);
# Check Pmsgs 2
$u2->{t}->get_ok('/pmsgs/2')->status_is(200)
      ->content_like(qr~topicid\:\s*0,~)
      ->content_like(qr~usertoid\:\s*2,~);

# Id 3
$u3->{t}->post_ok('/topic/new',
    form => {
        titlestring => 'Topic3',
        textdata => 'Testbeitrag3',
    })->status_is(302)->content_is('');
add_forum($u3, 1, 'Testbeitrag3');
# Check Topic 3
$u4->{t}->get_ok('/topic/3')->status_is(200)
      ->content_like(qr~Topic3~)
      ->content_like(qr~Testbeitrag3~)
      ->content_like(qr~topicid\:\s*3,~)
      ->content_like(qr~usertoid\:\s*0,~);
reset_topic($u2, 3);

# nochmal nachguggen
test_fetch( $u2, [], [] );
test_fetch( $u3, [], [] );
test_fetch( $u4, [], [] );

#############################################################################
# Die Tests gehen los

# u2 -> 1, u3 -> 2, 3

# Beiträge anlegen
note "---------- add forum posts";
add_forum( $u2, 1 );
add_forum( $u2, 1 );
add_forum( $u2, 1 );
add_forum( $u2, 2 );
add_forum( $u2, 2 );
note "---------- add pmsgs posts";
add_pmsgs( $u2, $u3, 2 );
# check users
note "---------- test fetch";
test_fetch( $u2, [], [] );
test_fetch( $u3, [2,1], [2] );
test_fetch( $u4, [2,1], [] );

# reset users
reset_topic($u3, 1);
reset_topic($u3, 2);
reset_pmsgs($u3, 2);
reset_topic($u4, 1);
reset_topic($u4, 2);

# test reseted
test_fetch( $u2, [], [] );
test_fetch( $u3, [], [] );
test_fetch( $u4, [], [] );
