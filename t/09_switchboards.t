use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 153;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();

Testinit::test_login($t, $admin, $apass);

my @boards = qw(forum pmsgs notes);
my %names  = ( forum => 'Forum', pmsgs => 'Nachrichten', notes => 'Notizen' );
my @order  = qw(0 1 2
                0 2 1
                1 0 2
                1 2 0
                2 0 1
                2 1 0);

for my $board ( map { $boards[$_] } @order ) {
    my @isnt = grep { $_ ne $board } @boards;
    $t->get_ok("/$board/show")->status_is(200);
    $t->content_like(qr~<span class="linktext link$board active active$board">$names{$board}</span></a>~);
    $t->content_unlike(qr~<span class="linktext link$board">$names{$board}</span></a>~);
    for my $isnt ( @isnt ) {
        $t->content_like(qr~<span class="linktext link$isnt">$names{$isnt}</span></a>~);
        $t->content_unlike(qr~<span class="linktext link$isnt active active$isnt">$names{$isnt}</span></a>~);
    }
}


