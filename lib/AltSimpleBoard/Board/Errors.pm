package AltSimpleBoard::Board::Errors;

use 5.010;
use strict;
use warnings;
use utf8;

use AltSimpleBoard::Errors;

sub error_prepare  { &AltSimpleBoard::Errors::prepare     }
sub error_handling { &AltSimpleBoard::Errors::handling    }
sub or_nostring    { &AltSimpleBoard::Errors::or_nostring }
sub or_empty       { &AltSimpleBoard::Errors::or_empty    }
sub or_zero        { &AltSimpleBoard::Errors::or_zero     }
sub or_undef       { &AltSimpleBoard::Errors::or_undef    }

1;

