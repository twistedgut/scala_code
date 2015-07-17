package Test::XTracker::Data::Quarantine;
use NAP::policy "tt", 'role';

requires 'prl_rollout_phase', 'iws_rollout_phase', 'schema', 'data__quantity__insert_quantity';

use Test::XTracker::Data;
use XTracker::Constants::FromDB qw/:flow_status/;

=head2 get_pre_quarantine_quantity

Returns a Quantity DBIc Row suitable for stock that is about to be moved
to quarantine

=cut
sub get_pre_quarantine_quantity {
    my ($self, $args) = @_;
    $args //= {};

    my $amount = $args->{amount} // 2;

    # Get/create a product/variant
    my ($channel, $products) = Test::XTracker::Data->grab_products({
        how_many => 1,
        (defined($args->{channel_id}) ? ( channel_id => $args->{channel_id} ) : () ),
    });
    my $product_data = $products->[0];

    # Make sure we have a suitable location
    my ($location, $status_id);
    if ($self->prl_rollout_phase() or $self->iws_rollout_phase()) {
        # If we're using some sort of automation, then we need the 'Transit'
        # location
        $location = $self->schema()->resultset('Public::Location')->find({
            location => 'Transit'
        });

        $status_id = ($self->prl_rollout_phase()
            ? $FLOW_STATUS__IN_TRANSIT_FROM_PRL__STOCK_STATUS
            : $FLOW_STATUS__IN_TRANSIT_FROM_IWS__STOCK_STATUS
        );
    } else {
        # Else any old 'Main' location will do
        $location = Test::XTracker::Data->get_main_stock_location();
        $status_id = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;
    }

    # There can be only one! (combination of the below fields in quantity, so
    # if there already is one, we'll need to make use of it)
    my $quantity = $self->schema()->resultset('Public::Quantity')->search({
        location_id => $location->id(),
        variant_id  => $product_data->{variant}->id(),
        channel_id  => $channel->id(),
        status_id   => $status_id,
    })->first();

    if($quantity) {
        # Make sure it has the quantity we expect
        $quantity->update({
            quantity => $amount,
        });
    } else {
        $quantity = $self->data__quantity__insert_quantity({
            location    => $location,
            variant     => $product_data->{variant},
            channel     => $channel,
            quantity    => $amount,
            status_id   => $status_id,
        });
    }

    return $quantity;
}
