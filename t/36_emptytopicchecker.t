use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use utf8;

use Carp;
use Data::Dumper;
use Test::Mojo;
use Test::More tests => 46;

#################################################
# Vorbereitungstreffen
#################################################

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
Testinit::test_login( $t, $admin, $apass);
my $Topic = 'Testtopic';

sub check_content {
    my ( $ent, $deleted ) = @_;
    note 'Thema aufrufen testen';
    $t->get_ok('/topic/1')->status_is(200)
      ->content_like(qr~$Topic~);
    if ( $deleted ) { $t->content_unlike( qr~$ent~ ) } 
    else            { $t->content_like(   qr~$ent~ ) }
    $t->get_ok('/forum')->status_is(200)
      ->content_like(qr~$Topic~);
}

note 'Beitrag 1 anlegen';
$t->post_ok('/topic/new', 
    form => {
        titlestring => $Topic,
        textdata => 'Testbeitrag1',
    })->status_is(302)->content_is('');
check_content('Testbeitrag1');

note 'Beitrag 1 loeschen';
$t->post_ok('/topic/1/delete/1')
  ->status_is(302)->content_is('');
check_content('Testbeitrag1', 1);

note 'Beitrag 2 anlegen';
$t->post_ok('/topic/1/new', 
    form => {
        textdata => 'Testbeitrag2',
    })->status_is(302)->content_is('');
check_content('Testbeitrag2');
check_content('Testbeitrag1', 1);
