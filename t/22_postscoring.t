use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use Ffc::Plugin::Config;
use File::Temp qw~tempfile tempdir~;
use File::Spec::Functions qw(catfile catdir splitdir);

use Test::Mojo;
use Test::More tests => 266;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1 );
sub logina { Testinit::test_login($t, $admin, $apass) }
sub login1 { Testinit::test_login($t, $user1, $pass1) }

sub info  { Testinit::test_info( $t, @_) }
sub error { Testinit::test_error($t, @_) }

my @scores = (undef, map {;[ 0, Testinit::test_randstring() ] } 0 .. 2); # Index == Post-Id

sub _update_score {
    my ( $dir, $ajax, $id, $fail, $own ) = @_;
    $fail //= 0; $own  //= 0; my $up = ( $dir eq 'in' ) ? 1 : 0;
    note( "---------- '${dir}crease', postid='$id', ajax='$ajax', own='$own', fail='$fail'" );

    if ( $ajax ) {
        $t->get_ok("/topic/1/score/${dir}crease/$id/ajax")
          ->status_is('200');
    }
    else {
        $t->get_ok("/topic/1/score/${dir}crease/$id")
          ->status_is('302')->content_is('')
          ->header_is(Location => '/topic/1');
        $t->get_ok('/topic/1')->status_is(200);
    }
    cdiag();

    if ( $fail ) {
        $t->content_unlike(qr~\A(?:up|down)\z~xims);
        cdiag();
        $t->content_unlike(qr~Bewertung\s+(?:erhöht|veringert)~xmsio);
        cdiag();

        if ( $ajax ) {
            if ( $own ) { $t->content_is( 'failed own' )                      }
            else        { $t->content_is( $up ? 'failed max' : 'failed min' ) }
            cdiag();
        }
        else {
            if ( $own ) {
                error('Eigene Beiträge können nicht bewertet werden');
            } else {
                if ( $up ) { error('Bewertung hat das Maximum erreicht') }
                else       { error('Bewertung hat das Minimum erreicht') }
            }
            cdiag();
        }
    }
    else {
        if ( $up ) { $scores[$id][0]++ }
        else       { $scores[$id][0]-- }

        if ( $ajax ) {
            $t->content_is( $up ? 'up' : 'down' );
        }
        else {
            if ( $up ) { info('Bewertung erhöht')    }
            else       { info('Bewertung veringert') }
        }
        cdiag();
    }
}
# sub($id, $fail, $own);
sub inc   { _update_score('in', 0, @_) }
sub dec   { _update_score('de', 0, @_) }
sub inc_a { _update_score('in', 1, @_) }
sub dec_a { _update_score('de', 1, @_) }

sub cdiag {
    my @caller = caller(2);
    $t->{success} or diag "caller-line '$caller[2]'";
}

sub check_score {
    my ( $show, $id ) = @_; # Beitragsersteller bekommen keine Scoring-Links (show), Id des Posts
    $t->get_ok('/topic/1')->status_is(200);
    my $score = $scores[$id][0];
    if ( $score > 0 ){
        $score = qr~<span\s+title="Bewertungswert\s+des\s+Beitrages"\s+class="score\s+goodpost">\+$score</span>~xmsi;
    }
    elsif ( $score < 0 ) {
        $score = qr~<span\s+title="Bewertungswert\s+des\s+Beitrages"\s+class="score\s+badpost">$score</span>~xmsi;
    }
    else {
        $score = qr~<span\s+title="Bewertungswert\s+des\s+Beitrages"\s+class="score">0</span>~xmsi;
    }
    if ( $show ) {
        $show = qr~<a\s+name="highscorelink"\s+href="/topic/1/score/increase/$id"\s+title="Bewertung\s+erhöhen">\+</a>\s*$score\s*<a\s+name="highscorelink"\s+href="/topic/1/score/decrease/$id"\s+title="Bewertung\s+herabsetzen">\-</a>~xmsi;
    }
    else {
        $show = $score;
    }
    $t->content_like(qr~$show\s*\)</span>\s*</h2>\s*<p>$scores[$id][1]</p>~xmsi);
    cdiag();
}

logina();
note 'Maximalzahl aendern wegen damit nicht so viel rumgetestet werden muss';
$t->post_ok('/admin/boardsettings/maxscore', form => {optionvalue => 2})
  ->status_is(302)->content_is('')
  ->header_is(Location => '/admin/form');

note 'Ein Thema (Id=1, immer) mit zwei Testbeitraegen für Admin anlegen';
$t->post_ok('/topic/new', 
    form => {
        titlestring => "admin $admin topic", 
        textdata => $scores[1][1],
    })->status_is(302)->content_is('');
$t->post_ok('/topic/1/new', 
    form => {
        textdata => $scores[2][1],
    })->status_is(302)->content_is('');

note 'Der Ersteller darf da nur den Score, aber keine Links sehen';
check_score(0,1);
check_score(0,2);

login1();
sub check_all_scores {
    check_score(1,1);
    check_score(1,2);
    check_score(0,3);
}
note 'Andere Benutzer sehen die Links zum bewerten ... ausser bei eigenen Beitraegen, klar';
$t->get_ok('/topic/1')->status_is(200);
$t->content_like(qr~$_~) 
    for map {$scores[$_][1]} 1 .. 2;
$t->post_ok('/topic/1/new', 
    form => {
        textdata => $scores[3][1],
    })->status_is(302)->content_is('');
check_all_scores();

note 'Eigene Beitraege koennen nicht bewertet werden';
inc(3,1,1);
check_all_scores();
dec(3,1,1);
check_all_scores();

note 'Beitrag Id 2 wird hoeher bewertet';
inc(2);
check_all_scores();
note 'Beitrag Id 2 wird noch hoeher bewertet';
inc(2);
check_all_scores();
note 'Beitrag Id 2 wird noch hoeher bewertet, geht aber nicht hoeher';
inc(2,1);
check_all_scores();
note 'Beitrag Id 1 wird niedriger bewertet';
dec(1);
check_all_scores();
note 'Beitrag Id 1 wird noch niedriger bewertet';
dec(1);
check_all_scores();
note 'Beitrag Id 1 wird noch niedriger bewertet, geht aber nicht niedriger';
dec(1,1);
check_all_scores();
note 'Beitragsersteller sieht die Bewertungen ebenfalls';
logina();
check_score(0,1);
check_score(0,2);
check_score(1,3);

note 'Beitraege ueber AJAX-Calls aendern geht net';
login1();
inc_a(2,1);
dec_a(1,1);
check_all_scores();
note 'Beitraege ueber AJAX-Calls aendern geht im folgenden';
inc_a(1);
dec_a(2);
check_all_scores();
