package AltSimpleBoard::Errors;
use utf8;
use strict;
use warnings;

sub handle {
    # controller, code, errormessage
    my $c    = shift;
    my $code = shift;
    my $msg  = shift;
    local $@;
    eval { $code->() };
    if ( $@ ) {
        my $log = $c->app->log;
        $log->error("system error message: $@");
        $log->error("user presented error message: $msg");
        my $error = $c->stash('error') // '';
        my $newerror = $AltSimpleBoard::Data::Debug ? $@ : ($msg // 'Fehler');
        $c->stash(error => $error ? "$error\n\n$newerror" : $newerror);
        return;
    }
    return 1; 
}

sub handling {
    my $c           = shift; 
    my $params      = shift or die 'params not set for board error handling';
    my ( $code, $msg, $after_ok, $after_error, $plain );
    if ( 'CODE' eq ref $params ) {
        $code = $params;
    }
    else {
        die 'no hash params provided' unless 'HASH' eq ref $params;
        $code        = $params->{code}; 
        $msg         = $params->{msg} // '';
        $after_ok    = $params->{after_ok};
        $after_error = $params->{after_error};
        $plain       = $params->{plain};
    }
    if ( $plain ) {
        handle( $c, sub { die $plain }, $plain );
        $after_error->(@_) if $after_error and 'CODE' eq ref $after_error;
        return;
    }
    die '"code" variable not set in error message' unless $code;
    die '"code" is not a code reference' unless 'CODE' eq ref $code;
    unless ( handle( $c, $code, $msg ) ) {
        $after_error->(@_) if $after_error and 'CODE' eq ref $after_error;
        return;
    }
    $after_ok->(@_) if $after_ok and 'CODE' eq ref $after_ok;
    return 1;
}

sub _something {
    my $c = shift; my $code = shift; my $return;
    die '"code" is not a code reference' unless 'CODE' eq ref $code;
    handle( $c, sub { $return = $code->() }, '' );
    return $return;
}
sub or_empty    { _something( @_ ) // [] }
sub or_nostring { _something( @_ ) // '' }
sub or_zero     { _something( @_ ) // 0  }

sub prepare { $_[0]->stash( error => '' ) unless $_[0]->stash('error') }

1;

