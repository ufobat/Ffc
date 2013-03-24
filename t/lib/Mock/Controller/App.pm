package Mock::Controller::App;
use strict;
use warnings;
use utf8;
use 5.010;
use Mock::Controller::Log;
use Mojolicious;
use Mojolicious::Plugin::JSONConfig;
use Data::Dumper;

our %Plugins = (
    JSONConfig => sub {
        my $params = shift;
        my $config = Mojolicious::Plugin::JSONConfig->new();
        $config->load($params->{file}, $config, Mojolicious->new());
    },
);

sub new { bless { log => Mock::Controller::Log->new() }, shift }
sub log { shift->{log} }

sub _logit {
    my $key = shift;
    my $app = shift;
    my @dat = @_;
    if ( @dat ) {
        $app->{$key} = [] unless exists $app->{$key};
        push @{$app->{$key}}, \@dat;
        if ( $key eq 'plugins' ) {
            my $plugin = shift @dat;
            if ( exists $Plugins{$plugin} ) {
                return $Plugins{$plugin}(@dat);
            }
            else {
                return $app;
            }
        }
        else {
            return $app;
        }
    }
    else {
        return $app->{$key};
    }
}

sub plugin { _logit('plugins', @_) }
sub secret { _logit('secrets', @_) }

1;

