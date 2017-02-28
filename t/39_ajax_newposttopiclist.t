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
use Test::More tests => 815;

# Benutzer anlegen
my ( $t, $path, $aname, $apass, $dbh ) = Testinit::start_test();
# Benutzerobjekte zur Weiterverarbeitung
my ( $u1, $u2, $u3 ) = Testinit::make_userobjs($t, 3, $aname, $apass);

# Neue Themen zum testen
note "---------- insert start";
# Id 1
$u1->{t}->post_ok('/topic/new',
    form => {
        titlestring => 'Topic1',
        textdata => 'Testbeitrag1',
    })->status_is(302)->content_is('');
# Check Topic 1
$u2->{t}->get_ok('/topic/1')->status_is(200)
      ->content_like(qr~Topic1~)
      ->content_like(qr~Testbeitrag1~)
      ->content_like(qr~topicid\:\s*1~)
      ->content_like(qr~usertoid\:\s*0~);
# Check Pmsgs 1
$u2->{t}->get_ok('/pmsgs/1')->status_is(200)
      ->content_like(qr~topicid\:\s*0~)
      ->content_like(qr~usertoid\:\s*1~);

# Id 2
$u2->{t}->post_ok('/topic/new',
    form => {
        titlestring => 'Topic2',
        textdata => 'Testbeitrag2',
    })->status_is(302)->content_is('');
# Check Topic 2
$u1->{t}->get_ok('/topic/2')->status_is(200)
      ->content_like(qr~Topic2~)
      ->content_like(qr~Testbeitrag2~)
      ->content_like(qr~topicid\:\s*2~)
      ->content_like(qr~usertoid\:\s*0~);
# Check Pmsgs 2
$u1->{t}->get_ok('/pmsgs/2')->status_is(200)
      ->content_like(qr~topicid\:\s*0~)
      ->content_like(qr~usertoid\:\s*2~);

# Id 3
$u2->{t}->post_ok('/topic/new',
    form => {
        titlestring => 'Topic3',
        textdata => 'Testbeitrag3',
    })->status_is(302)->content_is('');
# Check Topic 3
$u3->{t}->get_ok('/topic/3')->status_is(200)
      ->content_like(qr~Topic3~)
      ->content_like(qr~Testbeitrag3~)
      ->content_like(qr~topicid\:\s*3~)
      ->content_like(qr~usertoid\:\s*0~);

#Testinit::add_forum( $u2, 1, 'Testbeitrag1' );
#Testinit::add_pmsgs( $u2, $user3, 3 );
