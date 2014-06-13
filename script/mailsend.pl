#!/usr/bin/perl 
use 5.010;
use strict;
use warnings;
use Net::SMTP;
use Sys::Hostname;
use Test::More;
use Test::Mojo;
use File::Spec::Functions qw(catdir splitdir);
use File::Basename;
use lib catdir(splitdir(File::Basename::dirname(__FILE__)), '..', 'lib');

my $host   = 'localhost';
my $sender = 'admin@'.hostname();

my $config = do {
    use Mojolicious::Lite;
    my $config = plugin 'Ffc::Plugin::Config';
    get '/:userid' => [userid => qr/\d+/xmso] => sub { 
        my $c = shift;
        $c->session->{userid} = $c->param('userid');
        $c->counting;
        $c->render( text => join '=',
            map { ( $c->stash($_.'count') // 0 ) }
                qw(newmsgs newpost),
        );
    };
    $config;
};

my $t = Test::Mojo->new;

my $users = $config->dbh->selectall_arrayref( << 'EOSQL' );
    SELECT "name", "email", "id" 
    FROM "users" 
    WHERE "email" IS NOT NULL AND "email"<>'' 
    ORDER BY UPPER("name"), "id"
EOSQL

my $title = $config->dbh->selectall_arrayref(
    'SELECT "value" FROM "config" WHERE "key"=?',
    undef, 'title');
$title = @$title ? $title->[0]->[0] : 'Forum';

for my $u ( @$users ) {
    my $count_pmsgs = 0;
    my $count_forum = 0;
    if ( $t->get_ok("/$u->[2]") ) {
        my $text = $t->tx->res->text;
        if ( $text =~ m/(?<pmsgs>\d+)=(?<forum>\d+)/xmso ) {
            $count_pmsgs = $+{pmsgs};
            $count_forum = $+{forum};
        }
    }
    if ( $count_pmsgs or $count_forum ) {
        say "Neuigkeiten ($count_pmsgs, $count_forum) für $u->[0] ($u->[1], $u->[2]).";
    }
    else {
        say "Nichts neues für $u->[0] ($u->[1], $u->[2]).";
        next;
    }
    my $smtp = Net::SMTP->new($host) or die "Could not start to mail: $!";
    $smtp->mail($sender);
    $smtp->to($u->[1]);
    $smtp->data();
    $smtp->datasend("Subject: Neue Nachrichten\n");
    $smtp->datasend("To: $u->[1]\n");
    $smtp->datasend("\n");
    $smtp->datasend("Hallo $u->[0],\n\n");
    if ( $count_pmsgs and $count_forum ) {
        $smtp->datasend("es warten $count_forum neue Forennachrichten\n");
        $smtp->datasend("und $count_pmsgs neue private Nachrichten\n");
    }
    elsif ( not $count_pmsgs ) {
        $smtp->datasend("es warten $count_forum neue Forennachrichten\n");
    }
    else {
        $smtp->datasend("es warten $count_pmsgs neue private Nachrichten\n");
    }
    $smtp->datasend("bei $title auf dich.\n\n");
    $smtp->datasend("Viel Spaß beim lesen.\n\n");
    $smtp->dataend();
    $smtp->quit or say "Could not send mail: $!";
    say "Information über $count_forum Beiträge  und $count_pmsgs Nachrichten  an $u->[0] ($u->[1], $u->[2]) verschickt.";
}

done_testing( scalar @$users );
