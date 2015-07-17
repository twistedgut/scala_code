package XT::DC::Messaging::Producer::WMS::PreAdvice;
use NAP::policy "tt", 'class';
use XT::DC::Messaging::Spec::WMS;
use XTracker::Constants::FromDB qw(
                                      :stock_process_status
                                      :stock_process_type
                                      :flow_status
                                      :delivery_item_type
                                      :channel_transfer_status
                                    );
use XTracker::Database::Delivery qw ( get_delivery_channel );
use XTracker::Image;
use XTracker::Config::Local qw( config_var my_own_url );
use Carp;
use JSON::XS;

with 'XT::DC::Messaging::Role::Producer',
     'XTracker::Role::WithIWSRolloutPhase',
     'XTracker::Role::WithPRLs',
     'XTracker::Role::WithSchema';

has '+type' => ( default => 'pre_advice' );
has '+destination' => ( default => config_var('WMS_Queues','wms_inventory') );

sub message_spec {
    return XT::DC::Messaging::Spec::WMS::pre_advice();
}

my %destination_for_status=(
    $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS   => 'main',
    $FLOW_STATUS__SAMPLE__STOCK_STATUS       => 'sample',
    $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS => 'faulty',
    $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS  => 'main', # these are "to be sent back to vendor" (either faulty or not)
    $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS   => 'main',
);

sub transform {
    my ($self, $header, $data) = @_;

    my $payload = { items => [] };
    my $pid_cache = { };

    if (my $sp_group_rs = $data->{sp_group_rs}) {
        while (my $sp=$sp_group_rs->next) {
            $self->_transform_one($payload,$pid_cache,$sp);
        }
    }
    elsif (my $sp = $data->{sp}) {
        $self->_transform_one($payload,$pid_cache,$sp);
    }
    elsif ( my $sr = $data->{sr} ) {
        $self->_recode_one($payload,$pid_cache,$sr);
    }
    else {
        croak "WMS::PreAdvice needs a stock process group result set, or a single stock process record, or a single recode record";
    }

    # XXX TODO:
    # - returns with a list of containers

    unless (exists $payload->{pgid} && $payload->{pgid}) {
        return ;
    }

    $payload->{version} = '1.0';

    return ($header, $payload);

}

sub _transform_one {
    my ($self, $payload, $pid_cache, $stock_process) = @_;

    my $phase = $self->iws_rollout_phase;

    if (!defined $payload->{pgid}) {
        if ($phase > 0) {
            return unless $stock_process->is_handled_by_iws($phase);
        }

        # they will all be the same
        my $status_id = $stock_process->stock_status_for_putaway;

        $payload->{pgid} = 'p-'.$stock_process->group_id;

        $payload->{stock_status} = $self->schema->resultset('Flow::Status')
            ->find($status_id)->iws_name;

        $payload->{destination} = $destination_for_status{$status_id};
        $payload->{destination} = 'sample' if $stock_process->type_id == $STOCK_PROCESS_TYPE__FASTTRACK;

        my $delivery_item = $stock_process->delivery_item;
        my $product = $delivery_item->variant->product;
        my $channel =
            $self->_channel_from_pending_channel_transfer( $product ) ||
            $product->get_product_channel->channel;
        $payload->{channel} = $channel->name;

        if (grep {$delivery_item->type_id == $_} ($DELIVERY_ITEM_TYPE__CUSTOMER_RETURN, $DELIVERY_ITEM_TYPE__SAMPLE_RETURN) ) {
            $payload->{is_return} = JSON::XS::true;
        }
        else {
            $payload->{is_return} = JSON::XS::false;
        }

        my $container = $stock_process->container;

        if ($container) {
            $payload->{container_id}=$container;
        }
    }

    my $variant = $stock_process->variant;
    $self->_populate_payload($payload, $pid_cache, $stock_process);
}

=head2 _recode_one

Method responsible for creating a payload of a stock recode pre-advice

=cut

sub _recode_one {
    my ($self,$payload,$pid_cache,$sr) = @_;

    $payload->{pgid} = 'r-'.$sr->id;

    # Recode is always for main stock
    $payload->{stock_status} = 'main';
    $payload->{destination} = 'main';

    $payload->{channel} = $sr->variant->product->get_product_channel->channel->name;
    $payload->{is_return} = JSON::XS::false;

    my $container=$sr->container;

    if ($container) {
        $payload->{container_id}=$container;
    }

    $self->_populate_payload($payload,$pid_cache,$sr);

}


=head2 _populate_payload

Populates the payload with remainig fields it requires.

=over 4

=item $s - will either be a stock_process rs or a stock_recode rs

=back

=cut

sub _populate_payload {
    my ($self, $payload, $pid_cache, $s) = @_;

    my $variant = $s->variant;
    my $pid=$variant->product_id;
    my $skus_array=$pid_cache->{$pid};

    if (!defined $skus_array) {
        my $product = $variant->product;

        my $description = $product->wms_presentation_name;

        my $shipping_attribute = $product->shipping_attribute;
        my $pid_record = {
            pid => $pid,
            description => $description,
            # some products don't have a storage type yet
            storage_type => ( eval { lc $variant->product->storage_type->iws_name } || 'flat' ),
            length => $shipping_attribute->length,
            width  => $shipping_attribute->width,
            height => $shipping_attribute->height,
            weight => $shipping_attribute->weight,
            skus => [ ],
        };

        $skus_array = $pid_cache->{$pid} = $pid_record->{skus};

        push @{$payload->{items}}, $pid_record;

        my $images = get_images({
            product_id => $product->id,
            live => $product->get_product_channel->live,
            size => 'm',
            schema => $self->schema,
        });
        my $image_url=$images->[0];
        if ($image_url !~ m{^http://}) {
            $image_url = sprintf 'http://%s%s',my_own_url(),$image_url;
        }
        if ($image_url !~ m{/blank\.\w+$}) {
            $pid_record->{photo_url} = $image_url;
        }
    }

    push @{$skus_array}, {
        sku         => $variant->sku,
        quantity    => $s->quantity,
        client      => $variant->get_client()->get_client_code(),
    };

    @{$skus_array} = sort { $a->{'sku'} cmp $b->{'sku'} } @{$skus_array};
}

# If a channel transfer exists for a product, and is in REQUESTED, return the
# originating channel
sub _channel_from_pending_channel_transfer {
    my ( $self, $product ) = @_;

    # See if there's an outstanding channel transfer that's requested but not
    # selected
    my $ct = $self->schema->resultset('Public::ChannelTransfer')->search({
        product_id => $product->id,
        status_id  => $CHANNEL_TRANSFER_STATUS__REQUESTED
    })->first;
    return unless $ct;

    # If we found one, return the originating channel
    return $ct->from_channel;
}

1;
