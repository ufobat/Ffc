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
use Test::More tests => 278;

# Benutzer anlegen
my ( $t, $path, $aname, $apass, $dbh ) = Testinit::start_test();
# Benutzerobjekte zur Weiterverarbeitung
my ( $user2, $user3 ) = Testinit::make_userobjs($t, 2, $aname, $apass);

Testinit::test_login($t, $aname, $apass);
note '--------- userlist';
note "  $_->{userid} => $_->{username}" for Testinit::userlist();

sub _lastseen_table {
    my $sfrom = $_[0] ? 'msgs' : 'forum';
    my $sthing = $_[0] ? 'userfromid' : 'topicid';
    note my $sql = "SELECT userid, '$sthing', $sthing, lastseen FROM lastseen$sfrom";
    map {; sprintf 'userid = %d, %s = %d, lastseen = %d', @$_ } @{ $dbh->selectall_arrayref( $sql ) };
}

# Prüfen, ob was da ist, oder ob gerade das nicht da ist
sub _check_ajax {
    my $u = shift; my $uto = shift; my @posts = @_;
    my  $ispmsgs = $uto ? 1 : 0;
    note '';
    note '---------- test ' . ( $ispmsgs ? 'pmsgs' : 'forum' );
    my ( $t, $uid, $utoid ) = ( $u->{t}, $u->{userid}, $uto->{userid} );
    note "  -- test userid = $uid ($u->{username})";
    my $urlstart = ($utoid ? "/pmsgs/$utoid" : '/topic/1');
    my $urlfetch = "$urlstart/fetch/new";
    note '  -- before: ' . join "\n             ", _lastseen_table($ispmsgs);
    $t->get_ok( $urlfetch )->status_is(200)->json_has( "/$#posts" );
    if ( not $t->{success} ) {
        $t->content_is('');
    }
    note '  -- after:  ' . join "\n             ", _lastseen_table($ispmsgs);

    my ( @check, @old, @new );
    for my $i ( 0 .. $#posts ) {
        my $p = $posts[$i];
        my $isnew = Testinit::isnew($u, $p) ? 1 : 0;
        push @check, {
            order => $i,
            post  => $p,
            isnew => $isnew,
            own   => ( $uid == $p->{userfrom}->{userid} ? 1 : 0 ),
        };
        if ( $isnew ) { push @new, $p }
        else          { push @old, $p }
    }
    note '             old : ' . join( ', ', map {;$_->{postid}} @old ) if @old;
    note '             new : ' . join( ', ', map {;$_->{postid}} @new ) if @new;
    note '  --  json tests';
    for my $pi ( 0 .. $#check ) {
        my $ci = $check[$pi]; my $cp = $ci->{post}; my $jr = "/$pi";
        $t->json_like($jr, qr~<p>$cp->{content}</p>~);
        $t->json_like($jr, qr~<a href="$urlstart/display/$cp->{postid}"~);
        if ( $ci->{isnew} ) {
            $t->json_like($jr, qr~<div class="postbox newpost">~);
        }
        else {
            if   ( $ci->{own} ) { $t->json_like( $jr, qr~<div class="postbox ownpost">~ ) }
            else                { $t->json_like( $jr, qr~<div class="postbox">~         ) }
        }
    }
}
sub check_forum { _check_ajax( shift(), undef,   @_ ) }
sub check_pmsgs { _check_ajax( shift(), shift(), @_ ) }

# Neues Thema mit paar Beiträgen - wir benutzen immer das selbe, warum auch nicht
note "---------- insert start";
$user2->{t}->post_ok('/topic/new',
    form => {
        titlestring => 'Topic1',
        textdata => 'Testbeitrag1',
    })->status_is(302)->content_is('');
Testinit::add_forum( $user2, 1, 'Testbeitrag1' );
Testinit::add_forum( $user2, 3 );
Testinit::add_pmsgs( $user2, $user3, 3 );
#Testinit::show_forums();
#Testinit::show_pmsgss();

# Forenbeiträge und Privatnachrichten im AJAX-Fetch prüfen
note '';
note '';
note '---------- forum post test for users';
check_forum( $user2, reverse Testinit::forums() );
check_forum( $user3, reverse Testinit::forums() );
note '';
note '';
note '---------- pmsgs post test for users';
check_pmsgs( $user2, $user3, reverse Testinit::pmsgss() );
check_pmsgs( $user3, $user3, reverse Testinit::pmsgss() );

# Forenbeiträge auf gelesen markieren
note '';
note '';
note "---------- reset all";
Testinit::resetall($user3, '/topic/1', Testinit::forums());
Testinit::resetall($user3, '/pmsgs/2', Testinit::pmsgss());
#Testinit::show_forums();
#Testinit::show_pmsgss();

check_forum( $user2, reverse Testinit::forums() );
check_forum( $user3, reverse Testinit::forums() );
check_pmsgs( $user2, $user3, reverse Testinit::pmsgss() );
check_pmsgs( $user3, $user3, reverse Testinit::pmsgss() );

# Neue Beiträge durch User 2
note "--------- new entries";
Testinit::add_forum($user2,2);
Testinit::add_pmsgs($user2,$user3,2);
#Testinit::show_forums();
#Testinit::show_pmsgss();

check_forum( $user2,         reverse Testinit::forums() );
check_pmsgs( $user2, $user3, reverse Testinit::pmsgss() );

check_forum( $user3,         reverse Testinit::forums() );
check_pmsgs( $user3, $user2, reverse Testinit::pmsgss() );

