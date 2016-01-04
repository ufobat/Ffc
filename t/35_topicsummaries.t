use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use utf8;

use Carp;
use Data::Dumper;
use Test::Mojo;
use Test::More tests => 48;

#################################################
# Vorbereitungstreffen
#################################################

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
Testinit::test_login( $t, $admin, $apass);
my @Topics = qw(abcd efgh);

sub check_content {
    my @tops = @_;
    @tops = @Topics unless @tops;
    note 'Thema aufrufen mit "' . scalar(@tops) . '" Beitraegen';
    $t->get_ok('/topic/1')->status_is(200);
    for my $top ( @tops ) {
        note('Beitrag pruefen');
        $t->content_like(qr~$top~);
    }
}

sub check_summary {
    my $text = shift;
    note 'Themenliste aufrufen';
    $t->get_ok('/forum')->status_is(200);
    note 'Summary checken';
    $t->content_like(
        qr~<div class="otherspopup popup topiclistpopup summarypopup">\s*<p>$text ...</p>\s*</div>~
    );
}

#################################################
# Party
#################################################

note 'Beitrag 1 anlegen';
$t->post_ok('/topic/new', 
    form => {
        titlestring => "Testtopic",
        textdata => $Topics[0]
    })->status_is(302)->content_is('');
check_content($Topics[0]);
check_summary($Topics[0]);

note 'Beitrag 2 anlegen';
$t->post_ok('/topic/1/new', 
    form => { textdata => $Topics[1] })
  ->status_is(302)->content_is('');
check_content();
check_summary($Topics[1]);

note 'Beitrag 2 aendern';
$Topics[1] = 'hgfe';
$t->post_ok('/topic/1/edit/2', 
    form => { textdata => $Topics[1] })
  ->status_is(302)->content_is('');
check_content();
check_summary($Topics[1]);

note 'Beitrag 1 aendern';
$Topics[0] = 'fcba';
$t->post_ok('/topic/1/edit/1', 
    form => { textdata => $Topics[0] })
  ->status_is(302)->content_is('');
check_content();
check_summary($Topics[1]);

