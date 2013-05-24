package Ffc::Board::Errors;

use 5.010;
use strict;
use warnings;
use utf8;

use Ffc::Errors;

sub info           { &Ffc::Errors::info        }
sub error_handling { &Ffc::Errors::handling    }
sub or_nostring    { &Ffc::Errors::or_nostring }
sub or_empty       { &Ffc::Errors::or_empty    }
sub or_zero        { &Ffc::Errors::or_zero     }
sub or_undef       { &Ffc::Errors::or_undef    }

1;

