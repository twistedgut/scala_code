package XTracker::Database::Variant;
use strict;
use warnings;

use Perl6::Export::Attrs;

=head2

Returns true iff the passed string exactly matches the pattern for a SKU,
which is presently (bunch-of-digits)(single-minus)(bunch-of-digits).

=cut

sub is_valid_sku       :Export(:validation) { return shift =~ m{\A\d+-\d+\z}; }

1;
