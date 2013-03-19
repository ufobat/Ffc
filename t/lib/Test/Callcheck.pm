use 5.010;
use strict;
use warnings;
use utf8;

use Test::More;

sub check_call {    # alle aufrufoptionen durchprobieren
    my $code   = shift;
    my $sname  = shift;
    my @params = @_
      ; # ( { name => '', good => '', bad => [ '' ], emptyerror => '', errormsg => [ '' ] } )
    my @okparams;
    while ( my $par = shift @params ) {
        die qq(no emtpy error message given for "$par->{name}")
          unless $par->{emptyerror};
        {
            eval { $code->(@okparams) };
            like( $@, qr/$par->{emptyerror}/,
                qq~wrong call without "$par->{name}" yelled correctly~ );
        }
        for my $bad ( 0 .. $#{ $par->{bad} } ) {
            my $param = $par->{bad}->[$bad];
            my $error =
                 $par->{errormsg}->[$bad]
              || $par->{errormsg}->[-1]
              || $par->{emptyerror};
            {
                eval { $code->(@okparams, $param) };
                like( $@, qr/$error/,
                    qq~wrong call with "$par->{name}"="$param" yelled correctly~ );
            }
        }
        push @okparams, $par->{good};
    }
    {
        eval { $code->(@okparams) };
        ok(!$@, qq~good run of "$sname('~.join(q[', '], @okparams).qq~')" => "$@" went ok~);
    }
}

1;

