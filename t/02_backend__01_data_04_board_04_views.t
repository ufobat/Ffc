use strict;
use warnings;
use 5.010;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Test::Callcheck;
use Test::General;
use Mock::Controller;
use Mock::Testuser;
use Ffc::Data::Auth;
srand;

use Test::More tests => 1;

Test::General::test_prepare();

use_ok('Ffc::Data::Board::Views');

{
    note(q{sub count_newmsgs( $userid )});
}
{
    note(q{sub count_newpost( $userid )});
}
{
    note(q{sub count_notes( $userid )});
}
{
    note(q{sub get_categories( $userid )});
}
{
    note(q{sub get_notes( $userid )});
}
{
    note(q{sub get_forum( $userid )});
}
{
    note(q{sub get_msgs( $userid )});
}
{
    note(q{sub get_post( $userid )});
}
