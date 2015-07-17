package XTracker::Role::CommonVariant;
use NAP::policy "tt", 'role';
requires 'sku', 'get_client';

use MooseX::Params::Validate;
use XTracker::Constants::FromDB qw/:flow_status :shipment_item_status/;
use XTracker::Database::Logging;
use NAP::XT::Exception::Message::MismatchingClient;

=head1 NAME

XTracker::Role::CommonVariant

=head1 SYNOPSIS

  package XTracker::Schema::Result::Public::Variant

  ...

  use MooseX::NonMoose;
  extends 'DBIx::Class::Core';
  with 'XTracker::Role::CommonVariant';

  sub my_sub {
    my ( $self, $args ) = @_;
    return $self->update_pws_quantity($args);
  }

=head1 DESCRIPTION

This is a role that can be consumed by your DBIC variant result classes for
code that you want to share between Voucher::Variant and Public::Variant. At
this point in time DBIC isn't built on Moose, so you'll have to use
L<MooseX::NonMoose> to get your class to behave nicely.

=head1 METHODS

=head2 update_pws_quantity( \%args )

Perform a stock update on the website this product is sold on if it's live and
logs the change to log_pws_stock. You must provide a hashref with values for
C<action>, C<operator_id> and C<notes>. Passing 0 for C<delta> makes this call
a no-op.

=cut

sub update_pws_quantity {
    my ( $self, $args ) = @_;

    for my $required_key (qw/action operator_id notes stock_manager delta/) {
        die "You need to provide a value for $required_key"
            unless defined $args->{$required_key};
    }

    my ( $delta, $action, $operator_id, $notes, $stock_manager )
        = @{$args}{qw/delta action operator_id notes stock_manager/};
    return unless $delta;

    # Getting the channel via the product guarantees we always update the
    # correct website as get_product_channel will always return the one
    # it's sold on
    my $product_channel = $self->product->get_product_channel;

    # TODO: Die unless $product_channel->channel_id ==
    # $stock_manager->channel_id. This is pseudo-code, I don't think we
    # currently have code to determine what channel the $stock_manager is
    # updating yet

    # Note that we also send messages for non-live SKUs as the product service
    # needs to know about them even though the public website doesn't
    $stock_manager->stock_update(
        quantity_change => $delta,
        variant_id      => $self->id,
        pws_action_id   => $action,
        operator_id     => $operator_id,
        notes           => $notes,
    );

    return $self;
}

=head2 validate_client_code

Checks that a given client_code matches that associated with this
variant.

param - client_code : The client code to validate
param - throw_on_fail : (Default = 0) If set to 1, an exception will
 be thrown on validation failure

return - $validates : 1 if the client_code validate, else 0
=cut
sub validate_client_code {
    my ($self, $client_code, $throw_on_fail) = validated_list(\@_,
        client_code     => { isa => 'Str'},
        throw_on_fail   => { isa => 'Bool', default => 0, optional => 1 },
    );
    my $actual_client_code = $self->get_client()->get_client_code();
    my $validates = $client_code eq $actual_client_code;
    NAP::XT::Exception::Message::MismatchingClient->throw({
        sku             => $self->sku(),
        supplied_client => $client_code,
        actual_client   => $actual_client_code,
    }) if $throw_on_fail and not $validates;
    return $validates;
}

=head2 quantity_on_channel

Returns how many variants are on the given channel

=cut

sub quantity_on_channel {
    my ( $self, $channel_id ) = @_;
    return $self->search_related('quantities',
        { 'channel_id'  => $channel_id,
          'status_id'   => [
                $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                $FLOW_STATUS__IN_TRANSIT_FROM_PRL__STOCK_STATUS,
                $FLOW_STATUS__IN_TRANSIT_FROM_IWS__STOCK_STATUS
          ] },
    )->get_column('me.quantity')->sum || 0;
}

=head2 picked_shipments_items_on_channel

Returns a C<XTracker::Schema::ResultSet::Public::ShipmentItem> object with rows
picked or pending cancel for the variant

=cut

sub picked_shipment_items_on_channel {
    my ( $self, $channel_id ) = @_;
    return $self->search_related('shipment_items',
        { 'me.shipment_item_status_id' => {
            -in => [
              $SHIPMENT_ITEM_STATUS__PICKED,
              $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
            ]
          },
          'orders.channel_id' => $channel_id, },
        { prefetch => { shipment => { link_orders__shipments => 'orders' } } }
    );
}

=head2 stock_transfers_on_channel

Returns a C<XTracker::Schema::ResultSet::Public::StockTransfer> object that
have this variant on a given channel

=cut

sub stock_transfers_on_channel {
    my ( $self, $channel_id ) = @_;
    return $self->search_related('shipment_items',
        { 'me.shipment_item_status_id' => {
            -in => [
              $SHIPMENT_ITEM_STATUS__PICKED,
              $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
            ]
          },
          'stock_transfer.channel_id' => $channel_id, },
        { prefetch => {
            shipment => { link_stock_transfer__shipment => 'stock_transfer' }
        } }
    );
}

1;
