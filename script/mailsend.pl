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
    plugin 'Ffc::Plugin::Formats';
    get '/:userid' => [userid => qr/\d+/xmso] => sub { 
        my $c = shift;
        my $uid = $c->session->{userid} = $c->param('userid');
        $c->counting;
        my $topics =  $c->stash('topics');
        my $users  =  $c->stash('users');
        for my $top ( @$topics ) {
            $c->set_lastseen($uid,$top->[0],1);
        }
        my $pmsgscnt = 0;
        for my $m ( @$users ) {
            next unless $m->[8];
            $pmsgscnt += $m->[8];
            my $utoid = $m->[0];
            my $lastseen = $c->dbh_selectall_arrayref(
                'SELECT "lastseen" FROM "lastseenmsgs"
                WHERE "userid"=? AND "userfromid"=?',
                $uid, $utoid
            );
            if ( @$lastseen ) {
                $c->dbh_do(
                    'UPDATE "lastseenmsgs" SET "mailed"=1 WHERE "userid"=? AND "userfromid"=?',
                    $uid, $utoid );
            }
            else {
                $c->dbh_do(
                    'INSERT INTO "lastseenmsgs" ("userid", "userfromid", "mailed") VALUES (?,?,1)',
                    $uid, $utoid );
            }
        }
        $c->render(json => {
            newmsgs  => $pmsgscnt,
            newposts => [
                map  {;[@{$_}[2,3]]} 
                grep {;$_->[10] and $_->[3] and not $_->[12]}
                    @$topics,
            ],
        });
    };
    get '/title'   => sub {
        $_[0]->render(text => $_[0]->configdata->{title});
    };
    get '/userids' => sub {
        $_[0]->render(json => $_[0]->dbh_selectall_arrayref( << 'EOSQL' ));
    SELECT u."name", u."email", u."id" 
    FROM "users" u
    WHERE u."email" IS NOT NULL AND u."email"<>'' AND u."active"=1 AND u."newsmail"=1
    ORDER BY UPPER("name"), "id"
EOSQL
    };
};

my $t     = Test::Mojo->new;
my $title = $t->get_ok('/title')->tx->res->text   || 'Forum';
my $users = $t->get_ok('/userids')->tx->res->json || [];

for my $u ( @$users ) {
    my ( $username, $email, $uid ) = @$u;
    my $cnt = 0; my @lines; my $cntp = 0;

    my $data = $t->get_ok("/$uid")->tx->res->json;

    if ( $data->{newmsgs} ) {
        push @lines, "Private Nachrichten: $data->{newmsgs}\n";
        $cnt += $data->{newmsgs};
        say "Benutzer $username hat $cnt neue private Nachrichten erhalten.";
    }
    if ( @{$data->{newposts}} ) {
        push @lines, "Neue Forenbeiträge: $data->{newpostcount}";
        $cnt++;
        for my $d ( @{$data->{newposts}} ) {
            my $cntp += $d->[1];
            push @lines, "$d->[0]: $d->[1]";
        }
    }
    if ( $cntp ) {
        say "Benutzer $username wird ueber $cntp neue Beitraege informiert.";
    }
    if ( $cnt + $cntp ) {
        send_email($username, $email, \@lines);
        say "Benutzer $username wurde per Email informiert.";
    }
    else {
        say "Benutzer $username hat keine neuen Nachrichten erhalten.";
    }
}

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
