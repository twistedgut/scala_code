package Test::XTracker::Hacks::isaFunction;

# There's a class of warnings that originate from UNIVERSAL::isa when used in
# conjunction with Test::Class that complain about isa being called as a f
# function. Gianni and Pete Sergeant think the warning is erroneous, and can't
# figure out why it would turn up - it's also not originating from our code.
#
# The errors it generates are voluminous and irritating. This hides them.

use strict;
use warnings;

use UNIVERSAL::isa;

{ no warnings 'redefine';
*UNIVERSAL::isa::report_warning = sub {}; }

1;

