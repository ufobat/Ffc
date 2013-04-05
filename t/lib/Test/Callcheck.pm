use 5.010;
use strict;
use warnings;
use utf8;
use Data::Dumper;

use Test::More;

sub check_call {    # alle aufrufoptionen durchprobieren
    my $code   = shift;
    my $sname  = shift;
    my @params = @_
      ; # ( { name => '', good => '', bad => [ '' ], emptyerror => '', errormsg => [ '' ] } )
    my @okparams;
    while ( my $par = shift @params ) {
        die qq(good parameter missing for "$par->{name}") unless defined $par->{good};
        for my $s ( qw(errormsgs bad) ) {
            $par->{$s} = [] unless exists $par->{$s};
            $par->{$s} = [$par->{$s}] unless 'ARRAY' eq ref $par->{$s};
        }
        unless ( exists( $par->{noemptycheck} ) and $par->{noemptycheck} ) {
            die qq(no emtpy error message given for "$par->{name}")
              unless $par->{emptyerror};
            {
                eval { $code->(@okparams) };
                like( $@, qr/$par->{emptyerror}/,
                    qq~wrong call without "$par->{name}" yelled correctly~ );
            }
        }
        for my $bad ( 0 .. $#{ $par->{bad} } ) {
            my $param = $par->{bad}->[$bad];
            my $error =
                 $par->{errormsg}->[$bad]
              // $par->{errormsg}->[-1]
              // $par->{emptyerror};
            {
                eval { $code->(@okparams, $param) };
                like( $@, qr/$error/,
                    qq~wrong call with "$par->{name}"="$param" yelled correctly~ );
            }
        }
        push @okparams, $par->{good};
    }
    my @ret;
    {
        eval { @ret = $code->(@okparams) };
        ok(!$@, qq~good run of "$sname('~.join(q[', '], map { m/\n/xms ? (split("\n", $_, 2))[0].' ...' : $_ } @okparams).qq~')" went ok~);
        diag($@) if $@;
    }
    return @ret;
}

sub just_call {
    my $code = shift;
    my $ret;
    eval { $ret = [ $code->(@_) ] };
    return( ( $@ ? 0 : 1 ), $ret, $@ );
}

1;

