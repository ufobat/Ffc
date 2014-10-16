use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
require Posttest;

use Test::Mojo;
use Test::More tests => 2135;

my $cname = 'pmsgs';

# runs a standardized test suite
#   run_tests( $UserFrom, $UserTo, $Urlpref, $Check_env, $do_attachements, $do_edit, $do_delete );
# using $user1 (id=2, #1) writing to $user2 (id=3, #2), but not to $admin (id=1, #0)
run_tests(1, 2, "/$cname/3", \&check_env, 1, 0, 0);

# checks for correct appearance of side effects
sub check_env {
    my ( $t, $entries, $delents, $delatts, $cnt ) = @_;
    $cnt = @$entries unless $cnt;
    my $user1 = users(1); my $user2 = users(2);
    my $newcnt = grep { $_->[3] and $_->[3] eq $user2 and $_->[5] } @$entries;
    login1();
    $t->get_ok("/pmsgs")->status_is(200)
      ->content_unlike(qr~/pmsgs/2~)
      ->content_like(qr~/pmsgs/3~)
      ->content_like(qr~title="Privatnachrichten\s+mit\s+Benutzer\s+\&quot;$user2\&quot;\s+ansehen">$user2</a>\s+</p>~xmsi);
    login2();
    $t->get_ok("/pmsgs")->status_is(200)
      ->content_like(qr~/pmsgs/2~)
      ->content_unlike(qr~/pmsgs/3~);
    if ( $newcnt ) {
        $t->content_like(qr~<title>Ffc\s+Forum\s+\(0/$newcnt\)</title>~xmsi);
        $t->content_like(qr~title="Privatnachrichten\s+mit\s+Benutzer\s+\&quot;$user1\&quot;\s+ansehen">$user1</a>\s*
            \(<span\s+class="mark">$newcnt</span>\)\s+</p>~xmsi);
        $t->content_like(qr~Privatnachrichten\s+mit\s+Benutzer\s+\&quot;$user1\&quot;\s+ansehen">$user1</a></p>\s*</h2>\s*<p>\s*
            Ungelesene\s+Nachrichten\s+vom\s+Benutzer:\s*<span\s+class="mark">$newcnt</span>~xmsi);
    }
    else {
        $t->content_like(qr~<title>Ffc\s+Forum\s+\(0/0\)</title>~xmsi);
        $t->content_like(qr~title="Privatnachrichten\s+mit\s+Benutzer\s+\&quot;$user1\&quot;\s+ansehen">$user1</a>\s*</p>~xmsi);
        $t->content_like(qr~Privatnachrichten\s+mit\s+Benutzer\s+\&quot;$user1\&quot;\s+ansehen">$user1</a></p>\s*</h2>\s*<p>\s*
            Ungelesene\s+Nachrichten\s+vom\s+Benutzer:\s*0~xmsi);
    }
    $t->get_ok("/pmsgs/2")->status_is(200);
    check_pages(\&login2, '/pmsgs/2');
    map { $_->[3] and $_->[3] eq $user2 and $_->[5] = 0 } @$entries;
    test_data_security($t, $entries, $delents, $delatts);
}

# test that no one other than the conversationists have access to their messages
sub test_data_security {
    my ($t, $entries, $delents, $delatts) = @_;
    logina();
    for my $e ( @$entries, @$delents ) {
        for my $i ( 1 .. 3 ) {
            $t->get_ok("/$cname/$i/display/$e->[0]")->status_is(200);
            $t->content_unlike(qr~$e->[1]~)->content_unlike(qr~postbox~);
            for my $att ( @{ $e->[4] } ) {
                $t->content_unlike(qr"/$cname/$i/download/$att->[0]")
                  ->content_unlike(qr~alt="$att->[2]"~);
            }
            for my $att ( @{ $e->[4] } ) {
                $t->get_ok("/$cname/$i/download/$att->[0]")
                  ->status_is(404)
                  ->content_unlike(qr~$att->[1]~);
            }
        }
    }
}


