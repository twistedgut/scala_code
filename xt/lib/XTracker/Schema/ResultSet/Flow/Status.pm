package XTracker::Schema::ResultSet::Flow::Status;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';
use XTracker::Constants::FromDB qw( :flow_status );

sub all_of_type_rs {
    my ($self, $type) = @_;

    return $self->search_rs({type_id => $type});
}

=head2 as_lookup

Return all the flow status objects (currently < 15) in a hash on id
making it easy to use as a lookup

=cut
sub as_lookup {
    my $self = shift;

    my $hash = {};

    foreach my $flow_status ($self->all) {
        $hash->{ $flow_status->id } = $flow_status;
    }

    return $hash;
}


{
my %iws_stock_status=(
    main => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    sample => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
    faulty => $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS, # really?
    rtv => $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS,
    dead => $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS,
);
sub find_by_iws_name {
    my ($self,$name) = @_;

    return $self->find($iws_stock_status{ lc $name });
}
}

1;
