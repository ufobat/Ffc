#!/usr/bin/perl 
use 5.010;
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

my $host   = 'localhost';
my $sender = 'admin@'.hostname();

{
    use Mojolicious::Lite;
    plugin 'Ffc::Plugin::Config';
    get '/:userid' => [userid => qr/\d+/xmso] => sub { 
        my $c = shift;
        $c->session->{userid} = $c->param('userid');
        $c->counting;
        $c->render( text => join '=',
            map { ( $c->stash($_.'count') // 0 ) }
                qw(newmsgs newpost),
        );
    };
    get '/title' => sub {
        $_[0]->render(text => $_[0]->configdata->{title});
    };
    get '/userids' => sub {
        $_[0]->render(json => $_[0]->dbh_selectall_arrayref( << 'EOSQL' ));
    SELECT u."name", u."email", u."id" 
    FROM "users" u
    WHERE u."email" IS NOT NULL AND u."email"<>'' AND u."newsmail"=1 AND u."active"=1
    ORDER BY UPPER("name"), "id"
EOSQL
    };
};

my $t     = Test::Mojo->new;
my $title = $t->get_ok('/title')->tx->res->text   || 'Forum';
my $users = $t->get_ok('/userids')->tx->res->json || [];

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
        say "Neuigkeiten ($count_pmsgs, $count_forum) fuer $u->[0] ($u->[1], $u->[2]).";
    }
    else {
        say "Nichts neues fuer $u->[0] ($u->[1], $u->[2]).";
        next;
    }
    my $smtp = Net::SMTP->new($host) or die "Could not start to mail: $!";
    $smtp->mail($sender);
    $smtp->to($u->[1]);
    $smtp->data();
    $smtp->datasend("Subject: Neue Nachrichten in $title\n");
    $smtp->datasend("To: $u->[1]\n");
    $smtp->datasend("\n");
    $smtp->datasend("Hallo $u->[0],\n\nes ");
    if ( $count_forum ) {
        $count_forum == 1
          ? $smtp->datasend("es wartet eine neue Forennachricht\n")
          : $smtp->datasend("es warten $count_forum neue Forennachrichten\n");
        if ( $count_pmsgs ) {
            $count_pmsgs == 1
              ? $smtp->datasend("und eine neue private Nachricht\n")
              : $smtp->datasend("und $count_pmsgs neue private Nachrichten\n");
        }
    }
    else {
        $count_pmsgs == 1
          ? $smtp->datasend("es wartet eine neue private Nachricht\n")
          : $smtp->datasend("es warten $count_pmsgs neue private Nachrichten\n");
    }
    $smtp->datasend("bei $title auf dich.\n\n");
    $smtp->datasend("Viel Spass beim lesen.\n\n");
    $smtp->dataend();
    $smtp->quit or say "Could not send mail: $!";
    say "Information über $count_forum Beitraege  und $count_pmsgs Nachrichten  an $u->[0] ($u->[1], $u->[2]) verschickt.";
}

done_testing( 2 + @$users );
