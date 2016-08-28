#!/usr/bin/perl 
use 5.18.0;
use utf8;
use strict;
use warnings;
use Net::SMTP;
use Sys::Hostname;
use Test::More;
use Test::Mojo;
use File::Spec::Functions qw(catdir splitdir);
use File::Basename;
use lib catdir(splitdir(File::Basename::dirname(__FILE__)), '..', 'lib');
use Ffc;

# Irgend eine Email-Adresse als Sender - muss ja sein
my $host   = 'localhost';
my $sender = 'admin@'.hostname();

###############################################################################
# Wir bauen uns erst mal eine kleine Webserver-Instanz, über die wir die notwendigen 
# Informationen aus der Datenbank ziehen
{
    use Mojolicious::Lite;
    plugin 'Ffc::Plugin::Config';
    plugin 'Ffc::Plugin::Formats';
    plugin 'Ffc::Plugin::Lists';
    
    # Hierrüber können wir uns je Nutzer die notwendigen Informationen holen,
    # so wie sie auch im Forum geholt werden könnten
    get '/:userid' => [userid => qr/\d+/xmso] => sub { 
        my $c = shift;
        my $uid = $c->session->{userid} = $c->param('userid');
        # Themen- und Benutzerlisten
        $c->counting;
        my $topics =  $c->stash('topics');
        my $users  =  $c->stash('users');

        # Benutzer und Themenliste zurück setzen
        for my $top ( @$topics ) {
            $c->set_lastseen($uid,$top->[0],1);
        }

        # Privatnachrichten
        my $pmsgscnt = 0;
        for my $m ( @$users ) {
            next unless $m->[2];
            $pmsgscnt += $m->[2];
            my $utoid  = $m->[0];
            my $lastseen = $c->dbh_selectall_arrayref(
                'SELECT "lastseen" FROM "lastseenmsgs"
                WHERE "userid"=? AND "userfromid"=?',
                $uid, $utoid
            );
            # Mailsend setzen, wird bei neuen Nachrichten wieder umgesetzt
            if ( @$lastseen ) {
                $c->dbh_do( 'UPDATE "lastseenmsgs" SET "mailed"=1 WHERE "userid"=? AND "userfromid"=?', $uid, $utoid );
            }
            else {
                $c->dbh_do( 'INSERT INTO "lastseenmsgs" ("userid", "userfromid", "mailed") VALUES (?,?,1)', $uid, $utoid );
            }
        }
        
        # und als JSON raus damit
        $c->render(json => {
            newmsgscount => $pmsgscnt,
            newpostcount => do {
                my $res = 0;
                $res += $_->[3] for @$topics;
                $res;
            }
        });
    };
    #
    # Wir benöten einen Betreff für die Email, darin sollte der Forentitel erscheinen
    get '/title'   => sub {
        $_[0]->render(text => $_[0]->configdata->{title});
    };

    # Und wir brauchen alle Benutzer-Ids, um die für die personenbezogenen Mails durchzugehen
    get '/userids' => sub {
        $_[0]->render(json => $_[0]->dbh_selectall_arrayref( << 'EOSQL' ));
    SELECT u."name", u."email", u."id" 
    FROM "users" u
    WHERE u."email" IS NOT NULL AND u."email"<>'' AND u."active"=1 AND u."newsmail"=1
    ORDER BY UPPER("name"), "id"
EOSQL
    };
};

###############################################################################
# Jetzt erstellen wir uns kurz einen lokalen Webserver über das Test-Framework,
# aus dem wir die notnwendigen Daten raus ziehen
my $t     = Test::Mojo->new;
my $title = $t->get_ok('/title')->tx->res->text   || 'Forum';
my $users = $t->get_ok('/userids')->tx->res->json || [];

###############################################################################
# Wir gehen die Benutzerliste durch und versenden die notwendigen Emails
for my $u ( @$users ) {
    my ( $username, $email, $uid ) = @$u;
    my $cnt = 0; my @lines;

    # Alle Daten Benutzerbezogen ermitteln
    my $data = $t->get_ok("/$uid")->tx->res->json;

    # Neue Nachrichten zum Vermailen sammeln
    for my $what ( [newmsgscount => 'private Nachrichten'], [newpostscount => 'Forenbeiträge'] ) {
        if ( $data->{$what->[0]} ) {
            push @lines, "Erhaltene neue $what->[1]: $data->{$what->[0]}\n";
            $cnt += $data->{$what->[0]};
            say "Benutzer $username hat $data->{$what->[0]} neue $what->[1] erhalten.";
        }
    }

    # Es wird natürlich nur eine Email rausgeschickt, wenn es tatsächlich was zum mailen gibt
    if ( $cnt ) {
        send_email($username, $email, \@lines);
        say "Benutzer $username wurde per Email informiert.";
    }
    else {
        say "Benutzer $username hat keine neuen Nachrichten erhalten.";
    }
}

###############################################################################
# Den Versand einer Email durchführen - strait forward
sub send_email {
    my ( $username, $email, $lines ) = @_;
    my $smtp = Net::SMTP->new($host) or die "Could not start to mail: $!";
    $smtp->mail($sender);
    $smtp->to($email);
    $smtp->data();
    $smtp->datasend("Subject: Neue Nachrichten in $title\n");
    $smtp->datasend("To: $email\n");
    $smtp->datasend("\n");
    $smtp->datasend("Hallo $username,\n\n");
    $smtp->datasend("es warten folgende neue Nachrichten in $title auf dich:\n\n");
    for my $l ( @$lines ) {
        $smtp->datasend("    $l\n");
    }
    $smtp->datasend("\n\nViel Spass beim lesen.\n\n");
    $smtp->dataend();
    $smtp->quit or say "Could not send mail: $!";
}

done_testing( 2 + @$users );
