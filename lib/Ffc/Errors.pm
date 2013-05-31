package Ffc::Errors;
use utf8;
use strict;
use warnings;

use Carp;

sub handle_silent {
    # controller, code, errormessage
    my $c    = shift or croak 'no controller provided as first parameter';
    my $code = shift or croak 'no code provided as second parameter';
    local $@;
    eval { $code->() };
    if ( $@ ) {
        $c->app->log->error($@);
        return;
    }
    return 1;

}

sub handle {
    # controller, code, errormessage
    my $c    = shift or croak 'no controller provided as first parameter';
    my $code = shift or croak 'no code provided as second parameter';
    if ( $Ffc::Data::Debug ) {
        $code->();
        return 1;
    }
    else {
        my $msg  = shift;
        local $@;
        eval { $code->() };
        if ( $@ ) {
            my $log = $c->app->log;
            $log->error("system error message: $@");
            $log->error("user presented error message: " . ($msg // ''));
            my $error = $c->stash('error') // '';
            my $newerror = $msg || $@ || 'Fehler';
            $c->stash(error => $error ? "$error\n\n$newerror." : "$newerror.");
            return;
        }
    }
    return 1; 
}

sub handling {
    my $c      = shift or croak 'no controller provided as first parameter';
    my $params = shift or croak 'params not set for board error handling';
    my ( $code, $msg, $after_ok, $after_error, $plain );
    if ( 'CODE' eq ref $params ) {
        $code = $params;
    }
    else {
        croak 'no hash params provided' unless 'HASH' eq ref $params;
        $code        = $params->{code}; 
        $msg         = $params->{msg} // '';
        $after_ok    = $params->{after_ok};
        $after_error = $params->{after_error};
        $plain       = $params->{plain};
    }
    if ( $plain ) {
        handle( $c, sub { croak $plain }, $plain );
        $after_error->(@_) if $after_error and 'CODE' eq ref $after_error;
        return;
    }
    croak '"code" variable not set in error message' unless $code;
    croak '"code" is not a code reference' unless 'CODE' eq ref $code;
    unless ( handle( $c, $code, $msg ) ) {
        $after_error->(@_) if $after_error and 'CODE' eq ref $after_error;
        return;
    }
    $after_ok->(@_) if $after_ok and 'CODE' eq ref $after_ok;
    return 1;
}

sub _something {
    my $c = shift; my $code = shift; my $return;
    croak '"code" is not a code reference' unless 'CODE' eq ref $code;
    handle_silent( $c, sub { $return = $code->() }, '' );
    return $return;
}
sub or_empty    { _something( @_ ) // [] }
sub or_nostring { _something( @_ ) // '' }
sub or_zero     { _something( @_ ) // 0  }
sub or_undef    { _something( @_ )       }

sub info {
    my $c = shift;
    croak q{no mojolicious controller given} unless $c;
    my $newinfo = shift || return;
    my $info = $c->stash('info') // '';
    $c->stash(info => $info ? "$info\n\n$newinfo." : "$newinfo.");
}

1;

