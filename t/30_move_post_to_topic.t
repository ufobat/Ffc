use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 883;

use Data::Dumper;

###############################################################################
note q~Testsystem vorbereiten~;
###############################################################################
my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();

my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my ( $user2, $pass2 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1, $user2, $pass2 );
sub login1  { Testinit::test_login(   $t, $user1, $pass1 ) }
sub login2  { Testinit::test_login(   $t, $user2, $pass2 ) }
sub info    { Testinit::test_info(    $t, @_             ) }
sub error   { Testinit::test_error(   $t, @_             ) }
sub warning { Testinit::test_warning( $t, @_             ) }

##################################################
note('Testdaten zusammenstellen');
my @Topics = (
  # [ Top  => Topic-ID ]
    [ asdf => 1 ],
    [ fgjd => 2 ],
);
# Textdata, Article-Id, Topic-Id
my @Articles = (
    map( {;[$_, 0, 1]} qw(qwe rtz uio oiu tre) ),
    map( {;[$_, 0, 2]} qw(yxc vbn jkl cft hgf) ),
);
# Filename, Content, Article-Id
my @Attachements = (
    ['aaa123.txt', 'aaa321aaa', 3],
    ['bbb567.txt', 'bbb765bbb', 7],
);

login1();
$t->get_ok("/topic/1/limit/100")->status_is(302)->content_is('');
login2();
$t->get_ok("/topic/1/limit/100")->status_is(302)->content_is('');
login1();

##################################################
note('Helferroutinen');

{
    my $lastaid = 0;
    sub set_lastid { 
        $_[0]->[1] = ++$lastaid;
        note(qq~Artikel-ID $lastaid wurde ausgegeben~);
        return $lastaid;
    }
    sub get_lastid { $lastaid }
}

sub create_topics {
    for my $top ( @Topics ) {
        my ( $top, $id ) = @$top;
        note("Thema Nr. $id mit Beitraegen anlegen");
        my $allready = 0;
        for my $art ( @Articles ) {
            note(qq~Artikel fuer Thema Nr. $id anlegen~);
            next unless $art->[2] == $id;
            if ( $allready ) {
                $t->post_ok("/topic/$id/new", form => {textdata => $art->[0]})
                  ->status_is(302)->header_like(Location => qr~/topic/$id~)->content_is('');
            }
            else {
                note(qq~Thema Nr. $id inklusive erstem Artikel selber erstmal anlegen~);
                $t->post_ok('/topic/new', form => {titlestring => $top, textdata => $art->[0]})
                  ->status_is(302)->header_like( Location => qr{\A/topic/$id}xms )->content_is('');
                $allready = 1;
            }
            set_lastid($art);
            note(qq~Artikel Nr. $art->[1] wurde zu Thema Nr. $id hinzugefuegt~);
            for my $att ( @Attachements ) {
                next unless $att->[2] == $art->[1];
                note("Anhang an Artikel Nr. $art->[1] anhaengen");
                $t->post_ok("/topic/$id/upload/$art->[1]", 
                    form => { 
                        postid => $art->[1],
                        attachement => {
                            file => Mojo::Asset::Memory->new->add_chunk($att->[1]),
                            filename => $att->[0],
                            'Content-Type' => 'plain/text',
                        },
                    }
                );
                $t->status_is(302)->content_is('')
                  ->header_like(location => qr~/topic/$id~);
            }
        }
    }

    check_topics();
}

sub check_topics {
    note(qq~Themen werden geprueft~);
    for my $tops ( @Topics ) {
        my ( $top, $id ) = @$tops;
        note(qq~Pruefe das Thema Nr. $id~);
        $t->get_ok("/topic/$id")->status_is(200)
          ->content_like(qr~<h1>\s*$top~xmsi);
        note("Beitraege von Thema Nr. $id pruefen");
        for my $art ( @Articles ) {
            note("Artikel Nr. $art->[1] pruefen");
            if ( $art->[2] == $id ) { $t->content_like  (qr~<p>$art->[0]</p>~) }
            else                    { $t->content_unlike(qr~<p>$art->[0]</p>~) }
            unless ( $t->success ) {
                diag(Dumper $art, $tops);
            }
            for my $att ( @Attachements ) {
                next unless $art->[2] == $id and $att->[2] == $art->[1];
                note("Anhang von Artikel Nr. $art->[1] pruefen");
            }
        }
        note(qq~Thema Nr. $id wurde ueberprueft~);
    }
}

sub move_post {
    my ( $article, $n_t_id, $newtopictitle, $warning, $error, $wrongarticle ) = @_;
    my ( $art, $a_id, $o_t_id ) = @$article;
    if ( $n_t_id ) {
        $t->post_ok("/topic/$o_t_id/move/$a_id", form => {newtopicid => $n_t_id});
    }
    else {
        $t->post_ok("/topic/$o_t_id/move/$a_id", form => {titlestring => $newtopictitle});
    }
    $t->status_is(302)->content_is('');
    if ( $error or $warning ) {
        if ( $error ) {
            $t->header_is( Location => "/topic/$o_t_id" );
            $t->get_ok("/topic/$o_t_id")->status_is(200);
            error($error);
            unless ( $wrongarticle or $newtopictitle ) {
                $t->content_like(qr~<p>$art</p>~);
                $t->get_ok("/topic/$n_t_id")->status_is(200);
                $t->content_unlike(qr~<p>$art</p>~);
            }
        }
        else {
            $t->header_is( Location => "/topic/$o_t_id" );
            $t->get_ok("/topic/$o_t_id")->status_is(200);
            warning($warning); # Gibt nur Errors hier -.-
            $t->content_like(qr~<p>$art</p>~);
            if ( $n_t_id and $n_t_id <= @Topics ) {
                $t->get_ok("/topic/$n_t_id")->status_is(200);
                $t->content_unlike(qr~<p>$art</p>~);
            }
            elsif ( $n_t_id ) {
                $t->get_ok("/topic/$n_t_id")->status_is(404);
            }
        }
    }
    else {
        if ( $newtopictitle ) {
            $n_t_id = @Topics + 1;
            push @Topics, [$newtopictitle, $n_t_id];
        }
        $t->header_is( Location => "/topic/$n_t_id" );
        $t->get_ok("/topic/$n_t_id")->status_is(200);
        info('Beitrag wurde in das andere Thema verschoben');
        $t->content_like(qr~<p>$art</p>~);
        $t->get_ok("/topic/$o_t_id")->status_is(200);
        $t->content_unlike(qr~<p>$art</p>~);
        $article->[2] = $n_t_id;
        my $title = $Topics[$n_t_id - 1][0];
        my $oldid = $article->[1];
        my $newid = set_lastid($article);
        my $tstring = qq~<a href="/topic/$n_t_id/display/$newid" target="_blank" title="Der Beitrag wurde in ein anderes Thema verschoben, folgen sie dem Beitrag hier">Beitrag verschoben nach "$title"</a>~;
        push @Articles, [$tstring, $oldid, $o_t_id];
        for my $att ( @Attachements ) {
            next unless $att->[2] == $oldid;
            $att->[2] = $newid;
            note("Es wurde ein Anhang verschoben");
        }
    }
    check_topics();
}

##################################################
note('Testreihe starten');
create_topics();

note('Falscher Benutzer');
login2();
move_post($Articles[0], 2, undef, undef, 'Konnte keinen passenden Beitrag zum Verschieben finden', 1);
note('Falsche Eingaben');
login1();
move_post($Articles[0],'', undef, 'Neues Thema wurde nicht ausgewählt');
move_post($Articles[0], 3, undef, undef, 'Konnte das neue Thema zum Verschieben nicht finden');
move_post(['qwe', 1, 2], 2, undef, undef, 'Konnte keinen passenden Beitrag zum Verschieben finden', 1);
move_post(['qwe', 1, 3], 2, undef, undef, 'Konnte das gewünschte Thema nicht finden.  Konnte keinen passenden Beitrag zum Verschieben finden', 1);
move_post(['qwerqwer', 20, 1], 2, undef, undef, 'Konnte keinen passenden Beitrag zum Verschieben finden', 1);

note('Jetzt sollte es funktionieren');
move_post($Articles[0], 2);
note('Und Rueckwaerts verschieben sollte ebenfalls funktionieren');
move_post($Articles[0], 1);

note('Und mit nem neuen Thema aber leerem Thementitel geht es nicht');
move_post($Articles[0], undef, '', 'Neues Thema wurde nicht ausgewählt');
note('Und mit nem neuen Thema aber ungenuegendem Thementitel geht es auch nicht');
move_post($Articles[0], undef, 'a', undef, 'Die Übschrift ist zu kurz und muss mindestens zwei Zeichen enthalten. Neues Thema konnte nicht angelegt werden');
note('Und jetzt funktioniert das Verschieben in ein neues Thema');
move_post($Articles[0], undef, 'dofm' );

note('Und jetzt das ganze mit Anhang');
note('Fehler mit Anhang');
move_post($Articles[2],'', undef, 'Neues Thema wurde nicht ausgewählt');
move_post($Articles[2], 4, undef, undef, 'Konnte das neue Thema zum Verschieben nicht finden');
move_post($Articles[2], undef, 'a', undef, 'Die Übschrift ist zu kurz und muss mindestens zwei Zeichen enthalten. Neues Thema konnte nicht angelegt werden');
note('Funzt mit Anhang');
move_post($Articles[2], 3);
move_post($Articles[6], undef, 'mfod' );

