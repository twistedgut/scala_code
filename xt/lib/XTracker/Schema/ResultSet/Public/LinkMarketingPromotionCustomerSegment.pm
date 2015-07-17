package XTracker::Schema::ResultSet::Public::LinkMarketingPromotionCustomerSegment;
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';
use DateTime;


=head2 get_active_segments

    $customer_segment_r = $self->get_active_segments;

This returns a list of Customer Segments that are active.

=cut

sub get_active_segments {
    my $self = shift;

    my $customer_segment_rs = $self->search_related('customer_segment',{
        enabled => 't',
    });
    return $customer_segment_rs;
}


1;
