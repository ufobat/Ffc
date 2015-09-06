use strict;
use warnings;
use 5.010;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Test::Mojo;

use Test::More tests => 106;

srand;

{
    use Mojolicious::Lite;

    my $config = {};
    plugin 'Ffc::Plugin::Formats';
    helper configdata => sub { $config };
    helper prepare    => sub {
        my $c = shift;
        $c->session->{user} = $c->param('user') // '';
        $c->configdata->{urlshorten} = $c->param('urlshorten') // 30;
    };

    any '/format_timestamp' => sub {
        my $c = shift;
        $c->prepare;
        $c->render(text => $c->format_timestamp($c->param('text')));
    };
    any '/format_timestamp_oj' => sub {
        my $c = shift;
        $c->prepare;
        $c->render(text => $c->format_timestamp($c->param('text'), 1));
    };
    any '/pre_format' => sub {
        my $c = shift;
        $c->prepare;
        $c->render(text => $c->pre_format($c->param('text')));
    };
    any '/username_format' => sub {
        my $c = shift;
        $c->prepare;
        $c->render(text => $c->username_format($c->param('text')));
    };
}

my $t = Test::Mojo->new;

sub format_timestamp_test {
    note('checking format_timestamp( $timestring )');
    my @timeok = ( int( rand 10000 ), map { int rand 100 } 0 .. 4 );
    $timeok[0]-- if $timeok[0] == ( localtime )[5] + 1900; # im zweifelsfall ein jahr zuvor
    my $timeok_teststring =
        sprintf '%04d-%02d-%02d'
      . ( ' ' x ( 3 + int rand 8 ) )
      . '%02d:%02d:%02d', @timeok;
    my $timeok_checkstring = sprintf '%02d.%02d.%04d, %02d:%02d',
      @timeok[ 2, 1, 0, 3, 4 ];
    my $timebad = ">>> " . int( rand 1000000 ) . " <<<";

    $t->post_ok('/format_timestamp', form => { text => '' })
      ->content_is('');
    $t->post_ok('/format_timestamp', form => { text => $timebad })
      ->content_is($timebad);
    $t->post_ok('/format_timestamp', form => { text => $timeok_teststring })
      ->content_is($timeok_checkstring);
    $t->post_ok('/format_timestamp', form => { text => '0000-00-00 00:00:00' })
      ->content_is('neu');
    {
        my @time = localtime;
        if ( $time[0] > 55 ) {
            sleep 6; # fix (workarround) testing bug with edge case on minute switch
            @time = localtime;
        }
        $time[5] += 1900; $time[4]++;
        my $stamp = sprintf '%04d-%02d-%02d %02d:%02d:%02d', @time[5,4,3,2,1,0];
        $t->post_ok('/format_timestamp', form => { text => $stamp })
          ->content_is('jetzt');
    }
    {
        my @time = localtime;
        if ( $time[0] > 55 ) {
            sleep 6; # fix (workarround) testing bug with edge case on minute switch
            @time = localtime;
        }
        $time[5] += 1900; $time[4]++;
        my $stamp = sprintf '%04d-%02d-%02d %02d:%02d:%02d', @time[5,4,3,2,1,0];
        my $check = sprintf '%02d:%02d', @time[2,1];
        $t->post_ok('/format_timestamp_oj', form => { text => $stamp })
          ->content_is($check);
    }
    {
        my @time = localtime; $time[5] += 1900; $time[4]++;
        $time[1]++;
        my $stamp = sprintf '%04d-%02d-%02d %02d:%02d:%02d', @time[5,4,3,2,1,0];
        my $check = sprintf '%02d:%02d', @time[2,1];
        $t->post_ok('/format_timestamp', form => { text => $stamp })
          ->content_is($check);
    }
}

sub format_things_test {
    note q~Testing the formatting functions~;
    $t->post_ok('/pre_format', form => {text => << 'EOTXT'})
:)
haha hallo welt! oder so.
http://bedivere.de <3
test </ironie>
<h3>test <strike>notest</strike></h3>
EOTXT
      ->status_is(200)
      ->content_is('');
}

#format_timestamp_test();
format_things_test();

