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
        my $c = $_[0];
        $c->session->{userid} = $c->param('userid');
        
        # und als JSON raus damit
        $c->render(json => {
            newmsgscount => $c->newmsgscount(),
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
    #$t->status_is(200)->content_is('');

    # Neue Nachrichten zum Vermailen sammeln
    if ( $data->{newmsgscount} ) {
        push @lines, "Neue Nachrichten: $data->{newmsgscount}\n";
        $cnt += $data->{newmsgscount};
        say "Benutzer $username hat $data->{newmsgscount} neue Nachrichten erhalten.";
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

