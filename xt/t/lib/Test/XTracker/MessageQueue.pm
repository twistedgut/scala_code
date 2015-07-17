package Test::XTracker::MessageQueue;

use NAP::policy "tt", "class";
    extends 'Test::NAP::Messaging';
    with 'XTracker::Role::WithSchema';

use Carp;

use Test::XT::Data::Container;
# Make sure that the test config is loaded. ::Data sets the right env var.
use Test::XTracker::Data;
use XTracker::Config::Local qw/config_var config_section_slurp/;

# What's going on here? We have some problems:
# 1. we always want to get the correct configuration
# 2. XT::DC::Messaging and the rest of XT use different configurations
# 3. XT::DC::Messaging::Model::MessageQueue always gets the global XT
#    config, not the XT::DC::Messaging one
# so, we have to convince Test::NAP::Messaging to play along

around BUILDARGS => sub {
    my ( $orig, $self, $args ) = @_;

    # ignore whatever config you were told to use, we know that our
    # producers use this one
    $args->{config_hash} = \%XTracker::Config::Local::config;

    return $self->$orig($args);
};

around new_with_app => sub {
    my ($orig,$self,$args) = @_;
    # we mostly want to load XT::DC::Messaging and its config
    $args->{app_class} //= 'XT::DC::Messaging';
    $args->{config_file} //= $ENV{XTDC_CONF_DIR}.'/xt_dc_messaging.conf';
    return $self->$orig($args);
};

around _build_producer => sub {
    my ($orig,$self,@args) = @_;
    my $p = $self->$orig(@args);
    $p->transformer_args->{schema} = $self->schema;
    return $p;
};

sub build_schema {
    my ($class) = @_;

    return Test::XTracker::Data->get_schema;
}

sub preprocessor {
    state $preprocessor;
    require XT::DC::Messaging::Role::Producer;
    $preprocessor ||= XT::DC::Messaging::Role::Producer->_build_preprocessor();
    return $preprocessor;
}

around request => sub {
    my ($orig,$self,$app,$destination,$message,$headers) = @_;

    $message = $self->preprocessor->visit($message);

    return $self->$orig($app,$destination,$message,$headers);
};

=head2 base_order_payload

Return the base payload form that is common to order messages. Manipulate with
L</change_order_payload> and L</change_order_item_payload>.

=cut

# DC3: This sub appears to always use NAP queues, regardless of
# which channel the order is on. In order to remove the DC specific
# references, we've changed this to use the channel for the order.
# At the time of making these changes, this sub was not used anywhere in
# the codebase, if this is incorrect, please change.

sub base_order_payload {
    my ( $self, $order ) = @_;

    my $shipment = $order->get_standard_class_shipment;
    my @items    = $shipment->shipment_items->order_by_sku;
    my $return   = $shipment->return;

    my $order_items = [
        map {
            {
                sku          => $_->variant->sku,
                unitPrice    => $_->unit_price,
                duty         => $_->duty,
                tax          => $_->tax,
                xtLineItemId => $_->id,
                status       => $_->shipment_item_status->status,
                returnable   => 'Y',
            }
          } @items
    ];

    my $ret = {
        JMSXGroupID => $order->channel->lc_web_name,
        body        => {
            order => {
                orderItems       => $order_items,
                orderNumber      => $order->order_nr,
                returnCutoffDate => $shipment->return_cutoff_date,

                #shippingMethod   => "Domestic",
                status => "Dispatched",
            },
        },
        "content-type" => "json",
        destination    => $order->channel->lc_web_name . '-orders',
        persistent     => "true",
        version        => 1,
    };

    return $self->preprocess_data($ret);
}

sub change_order_payload {
    my ( $self, $payload, $change ) = @_;

    @{ $payload->{body}{order} }{ keys %$change } = values %$change;
    %$payload = %{ $self->preprocess_data($payload) };
    return $payload;
}

sub change_order_item_payload {
    my ( $self, $payload, $change_items ) = @_;

    while ( my ( $id, $change ) = each %$change_items ) {
        my ($i) =
          grep { $_->{xtLineItemId} == $id }
          @{ $payload->{body}{order}{orderItems} };
        @{$i}{ keys %$change } = values %$change;
    }

    %$payload = %{ $self->preprocess_data($payload) };
    return $payload;
}

=head2 send_shipment_ready( $shipment_id, \@skus_in_container_a, \@skus_in_container_b )

Pass this method a C<$shipment_id> and a structure representing containers with
skus in them (an array of arrayrefs) and it will send a C<WMS::ShipmentReady>
message with the given data.

=cut

sub send_shipment_ready {
    my ( $self, $shipment_id, @container_refs ) = @_;

    my @container_ids = Test::XT::Data::Container->get_unique_ids({
        how_many => scalar @container_refs
    });
    my @containers = map {;
        {
            container_id => shift( @container_ids ),
            items => [ map {; { sku => $_, quantity => 1, } } @$_ ],
        }
    } @container_refs;

    return $self->transform_and_send( 'XT::DC::Messaging::Producer::WMS::ShipmentReady', [$shipment_id, \@containers] );
}

=head2 send_picking_commenced( $shipment_id|$shipment, [$username] )

Send a picking commenced message. C<$username> defaults to C<it.god>.

=cut

sub send_picking_commenced {
    my ( $self, $shipment, $username ) = @_;

    $shipment = $self->schema->resultset('Public::Shipment')->find($shipment)
        if $shipment && !ref $shipment;

    croak 'You need to pass a DBIC::Result shipment object or a shipment id'
        unless $shipment;

    return $self->transform_and_send(
        'XT::DC::Messaging::Producer::WMS::PickingCommenced', $shipment, $username // 'it.god'
    );
}

