package Test::XTracker::Data::Order;

use NAP::policy "tt", 'test';
# This library is a work-in-progress - its eventual aim is to contain the
# order-based routines from Test::XTracker::Data.

use XT::Order::Parser;
use Test::XTracker::Data;
use Test::XTracker::Data::Order::Parser::PublicWebsiteXML;
use Test::XTracker::Data::Order::Parser::IntegrationServiceJSON;
use DateTime;
use Scalar::Util qw/ blessed /;
use List::MoreUtils qw/ first_value /;

use XTracker::Config::Local     qw( config_var );
use XTracker::Constants::FromDB qw(
    :allocation_status
    :allocation_item_status
    :cancel_reason
    :prl
    :prl_delivery_destination
    :shipment_status
    :shipment_item_status
    :shipment_type
    :business
);
use vars qw( $PRL__GOH $PRL_DELIVERY_DESTINATION__GOH_DIRECT );
use XTracker::Constants qw( :application );
use XTracker::Database::Shipment qw/ get_address_shipping_charges /;
use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;

use XTracker::AllocateManager;

use XTracker::Database qw/get_schema_and_ro_dbh schema_handle/;

use XT::Order::Parser;

# needed for the Old Importer stuff
use Log::Log4perl::Level;
use XTracker::Logfile   qw( xt_logger );

use Test::XT::Data::Container;

=head2 pending_order_dir

=head2 processed_order_dir

=head2 error_order_dir

Return the path of the appropriate directory from the config.

=cut

# Thin wrappers at the moment until we have a more sensible Config wrapper.
# Note pending_order_dir has removed the s from 'order' in the method name it
# wraps for consistency.
sub pending_order_dir   { return Test::XTracker::Data::pending_orders_dir();  }
sub processed_order_dir { return Test::XTracker::Data::processed_order_dir(); }
sub error_order_dir     { return Test::XTracker::Data::error_order_dir();     }


=head2 purge_order_directories

 Test::XTracker::Data::Order->purge_order_directories( 'JSON' || 'XML' );

Removes files from the various XML/JSON order directories. Defaults to 'XML'.

=cut

sub purge_order_directories {
    my $class   = shift;
    my $type    = shift || 'XML';

    my %classes = (
            'JSON'  => 'IntegrationServiceJSON',
            'XML'   => 'PublicWebsiteXML',
        );

    my $parser = "Test::XTracker::Data::Order::Parser::$classes{$type}"->new();
    return $parser->purge_order_directories();
}

=head2 does_order_exist

    ok( Test::XTracker::Data::Order->does_order_exist( $order ),
        'Order exists in the database' );

Given an L<XT::Data::Order> object, check if it exists in the database and return a
boolean value.

=cut

sub does_order_exist {
    my ( $self, $order ) = @_;
    croak 'Order object required' unless $order and ref( $order ) eq 'XT::Data::Order';

    return 0;
}

=head2 does_order_exist_by_id($order_id)

Return the number of orders in the database matching C<$order_id>

=cut
sub does_order_exist_by_id {
    my ($self, $order_id) = @_;
    croak 'order is required'
        unless defined $order_id;

    #my ( $schema, undef ) = get_schema_and_ro_dbh('xtracker_schema');
    my $schema = schema_handle();

    return
        $schema->resultset('Public::Orders')->count({order_nr => $order_id});
}

sub invoice_address_for_order {
    my ($self, $order_id) = @_;
    croak 'order_id is required'
        unless defined $order_id;

    #my ( $schema, undef ) = get_schema_and_ro_dbh('xtracker_schema');
    my $schema = schema_handle();

    return
        $schema->resultset('Public::Orders')
            ->find({order_nr => $order_id})
                ->invoice_address;
}

sub customer_for_order {
    my ($self, $order_id) = @_;
    croak 'order_id is required'
        unless defined $order_id;

    #my ( $schema, undef ) = get_schema_and_ro_dbh('xtracker_schema');
    my $schema = schema_handle();

    return
        $schema->resultset('Public::Orders')
            ->find({order_nr => $order_id})
                ->customer;
}

=head2 parse_order_file($file) : @$orders[XT::Data::Order]

Parse the test xml order $file, and return parsed orders.

=cut

sub parse_order_file {
    my ($class, $order_file) = @_;

    note "Parsing order file ($order_file)";
    my $order_xml  = $class->slurp_order_xml($order_file);

    #my ( $schema, $dbh ) = get_schema_and_ro_dbh('xtracker_schema');
    my $schema = schema_handle();
    my $parser = XT::Order::Parser->new_parser({
        schema => $schema,
        data   => $order_xml,
    });

    my $orders = $parser->parse;

    return $orders;
}

=head2 create_order_xml_and_parse

    my $order_data_arrayref = Test::XTracker::Data::Order->create_order_xml_and_parse(
        { order data } or [ { order data } ... ],
    );

Given some Order Data will create an XML file and parse it using the New Order Importer.
Will return an array ref of 'XT::Data::Order' objects. Can create multiple files if you
pass in the order data in an Array Ref.

=cut

sub create_order_xml_and_parse {
    my ( $class, $args )  = @_;
    if(blessed($args)) {
        # Once this is in master, the validation can be removed
        croak(q|Test::XTracker::Data::Order->create_order_xml_and_parse($order_args) parameters don't look right. Note that the signature of this method recently changed to not include the $schema or $dc|);
    }

    my $parser = Test::XTracker::Data::Order::Parser::PublicWebsiteXML->new();
    return $parser->create_and_parse_order($args);
}

=head2 create_order_json_and_parse

    my $order_data_arrayref = Test::XTracker::Data::Order->create_order_json_and_parse(
        business_id, { order data } or [ { order data } ... ],
    );

Given some Order Data will create an JSON file and parse it using the New Order Importer.
Will return an array ref of 'XT::Data::Order' objects. Can create multiple files if you
pass in the order data in an Array Ref.

Business_ID is required as JimmyChoo and NapGroup use different JSON formats

=cut

sub create_order_json_and_parse {
    my ( $class, $business_id, $args )  = @_;

    my $parser;

    if ($business_id == $BUSINESS__JC) {
        $parser = Test::XTracker::Data::Order::Parser::IntegrationServiceJSON->new();
    }
    else {
        $parser = Test::XTracker::Data::Order::Parser::NAPGroupJSON->new();
    }

    return $parser->create_and_parse_order($args);
}

=head2 create_promotion_type

    $record = Test::XTracker::Data::Order->create_promotion_type( $name, $description, $PROMOTION_CLAS__, $channel );

This will create a record in the 'promotion_type' table for a given Promotion Class.

=cut

sub create_promotion_type {
    my ( $class, $name, $desc, $class_id, $channel )    = @_;

    # check if one already exists first if it does delete it
    my $record  = $channel->promotion_types->search( { name => $name } )->first;
    if ( defined $record ) {
        $record->order_promotions->delete;
        $record->delete;
    }

    $record = $channel->create_related( 'promotion_types', {
                                name            => $name,
                                product_type    => $desc,
                                weight          => 0.12,
                                fabric          => 'Fabric Content',
                                origin          => 'Some Where on Earth',
                                hs_code         => '123456',
                                promotion_class_id  => $class_id,
                            } );

    note "Promotion Type Created Id/Name/Channel: ".$record->id."/".$record->name."/".$channel->name;

    return $record;
}

=head2 nominated_day_times($day_count, $channel) : %$name_datetime

Return hash ref (keys: nominated_delivery_date,
nominated_dispatch_time; values: DateTime objects) for a Nominated Day
to be dispatched $day_count back. Times are in the TZ of the $channel.

=cut

sub nominated_day_times {
    my ($self, $day_count, $channel) = @_;


    my $import_dispatch_time = DateTime->now()->add(days => $day_count);
    $import_dispatch_time->set_time_zone("Europe/London");

    my $dispatch_time = $import_dispatch_time->clone;
    $dispatch_time->set_time_zone($channel->timezone); # TZ of DC

    my $delivery_date = $dispatch_time->clone->add(hours => 24)
        # Simplification, should really be the customer address' TZ
        ->truncate(to => "day")
        ->set_time_zone($channel->timezone);

    return {
        import_dispatch_time    => $import_dispatch_time,
        nominated_delivery_date => $delivery_date,
        nominated_dispatch_time => $dispatch_time,
    };
}

# Find the premier shipping charge for the postcode in the premier
# address
sub get_premier_shipping_charge {
    my ($class, $channel_row, $premier_routing) = @_;

    my $schema = Test::XTracker::Data->get_schema;
    my $shipping_charge_rs = $schema->resultset("Public::ShippingCharge");

    my $premier_address = Test::XTracker::Data->create_order_address_in(
        "current_dc_premier",
    );

    # Try to get the INTL postcode area, or go with the whole postcode
    my ($major_postcode) = ( $premier_address->postcode =~ /([a-zA-Z]+\d+)/ );
    $major_postcode ||= $premier_address->postcode;

    # first search using the Post Code then try with the State/County
    my $premier_shipping_charge =
        $shipping_charge_rs->search(
            {
                "me.channel_id"                      => $channel_row->id,
                "me.premier_routing_id"              => $premier_routing->{id},
                "postcode_shipping_charges.postcode" => $major_postcode,
            },
            {
                join => "postcode_shipping_charges",
            }
        )->first //
        $shipping_charge_rs->search(
            {
                "me.channel_id"                      => $channel_row->id,
                "me.premier_routing_id"              => $premier_routing->{id},
                "state_shipping_charges.state"       => $premier_address->county,
            },
            {
                join => "state_shipping_charges",
            }
        )->first or die("Could not find premier shipping charge");

    return $premier_shipping_charge;
}

sub create_shipment {
    my ($class, $channel, $setup, $defult_premier_shipping_charge) = @_;

    my $schema = $channel->result_source->schema;
    my $shipping_charge_rs = $schema->resultset("Public::ShippingCharge");

    my (undef, $pids) = Test::XTracker::Data->grab_products({
        how_many => 1,
        channel  => $channel,
    });

    my $carrier_name = $setup->{carrier_name} || "Unknown"; # Premier
    my $shipping_account = Test::XTracker::Data->get_shipping_account($channel->id, $carrier_name);

    my $shipment_type = $setup->{shipment_type} // $SHIPMENT_TYPE__PREMIER;

    # Need the postcode to be correct
    my $address_in = $setup->{address_in} || do {
        my $address_in = "current_dc";
        if ($shipment_type == $SHIPMENT_TYPE__PREMIER) {
            $address_in .= "_premier";
        }
        $address_in;
    };
    my $address = Test::XTracker::Data->create_order_address_in(
        $address_in,
        $setup->{address_in_args} || {},
    );

    my $shipping_charge_id = $setup->{shipping_charge_id};
    if($setup->{shipping_charge_from_address}) {
        $shipping_charge_id = $class->get_shipping_charge_id_from_address(
            $channel,
            { $address->get_columns },
            $shipment_type,
        );
        my $shipping_charge = $shipping_charge_rs->find($shipping_charge_id);
        my $shipping_charge_moniker = join(", ", $shipping_charge->id, $shipping_charge->sku, $shipping_charge->description);
        note("Using shipping_charge from address: ($shipping_charge_moniker)");
    }
    $shipping_charge_id //= $defult_premier_shipping_charge->id;

    my($order, $order_hash) = Test::XTracker::Data->create_db_order({
        base => {
            channel_id           => $channel->id,
            shipping_account_id  => $shipping_account->id,
            shipment_status      => $SHIPMENT_STATUS__PROCESSING, # Not yet dispatched
            shipment_item_status => $setup->{shipment_item_status} // $SHIPMENT_ITEM_STATUS__NEW,
            shipment_type        => $shipment_type,
            shipping_charge_id   => $shipping_charge_id,
            invoice_address_id   => $address->id,
        },
        pids  => $pids,
        attrs => [ { price => 100.00 } ],
    });

    my $shipment = $order->shipments->first;
    note "Created shipment id (" . $shipment->id . ")";

    $shipment->apply_SLAs();

    return $shipment;
}

sub get_shipping_charge_id_from_address {
    my ($class, $channel, $address, $shipment_type) = @_;

    my $dbh = $channel->result_source->storage->dbh;
    my %shipping_charges = get_address_shipping_charges(
        $dbh,
        $channel->id,
        {
            country  => $address->{country},
            postcode => $address->{postcode},
            state    => $address->{state} // $address->{county},
        },
        {
            exclude_nominated_day   => 0,
            always_keep_sku         => "",
            customer_facing_only    => 1,
        }
    );
    # Not true generally, but for test setup, we don't care enough to
    # distinguish
    my $shipment_charge_class = {
        $SHIPMENT_TYPE__PREMIER       => "Same Day",
        $SHIPMENT_TYPE__DOMESTIC      => "Air",
        $SHIPMENT_TYPE__INTERNATIONAL => "Air",
    }->{$shipment_type} // "Same Day";

    my $shipping_charge = first_value(
        sub { $_->{class} eq $shipment_charge_class },
        sort { $a->{id} <=> $b->{id} }
        values %shipping_charges,
    );

    return $shipping_charge->{id};
}

sub create_shipment_and_response {
    my ($class, $channel, $setup, $default_premier_shipping_charge) = @_;

    my $shipment = $class->create_shipment(
        $channel,
        $setup,
        $default_premier_shipping_charge,
    );

    my $nominated_day = $shipment->get_nominated_day({
        nominated_delivery_date => $setup->{nominated_delivery_date},
        nominated_dispatch_date => $setup->{nominated_delivery_date}, # Same
    });

    $shipment->update({
        nominated_delivery_date  => $setup->{nominated_delivery_date},
        nominated_dispatch_time  => $nominated_day->dispatch_time,
        nominated_earliest_selection_time
            => $nominated_day->earliest_selection_time,
    });

    my $response_or_data = $class->create_response($setup);

    return($shipment, $response_or_data);
}

sub create_response {
    my ($class, $setup) = @_;

    my $response_or_data = $setup->{website_response} || do {
        my $setup_available_delivery_dates = $setup->{available_delivery_dates} || [];
        if (@$setup_available_delivery_dates) {
            $setup_available_delivery_dates = [
                map { +{
                    delivery_date => $_,
                    dispatch_date => $_,
                } }
                @$setup_available_delivery_dates
            ];
        }
        $setup_available_delivery_dates;
    };

    return $response_or_data;
}

sub allocate_order {
    my ($self, $order, $args) = @_;
    my $shipment = $order->shipments->first;
    return unless ($shipment);
    return $self->allocate_shipment($shipment, $args);
}


sub allocate_shipment {
    my ($self, $shipment, $args) = @_;

    # Allocate the shipment (won't do or return anything unless PRLs are turned on)
    my @allocations = $shipment->allocate({ operator_id => $APPLICATION_OPERATOR_ID });

    # Might as well stop now if nothing happened.
    return unless (scalar @allocations);

    unless ( $args->{'no_allocate_response'} ) {
        # Then pretend there was a successful allocate response for each allocation
        foreach my $allocation (@allocations) {
            my @allocation_items = $allocation->allocation_items;
            my $sku_data;
            foreach my $allocation_item (@allocation_items) {
                my $sku = $allocation_item->variant_or_voucher_variant->sku;
                $sku_data->{$sku}->{allocated}++;
                $sku_data->{$sku}->{short} = 0;
            }
            XTracker::AllocateManager->allocate_response({
                allocation => $allocation,
                allocation_items => \@allocation_items,
                sku_data => $sku_data,
                operator_id => $APPLICATION_OPERATOR_ID
            });
        }
    }

    return @allocations;
}

sub select_order {
    my ($self, $order, $args) = @_;
    my $shipment = $order->shipments->first;
    return unless ($shipment);
    return $self->select_shipment($shipment, $args);
}

sub _set_shipment_and_allocation_statuses {
    my (
        $self,
        $shipment_item_rs,
        $existing_shipment_item_status_id,
        $shipment_item_status_id,
        $allocation_status_id,
        $allocation_item_status_id,
    ) = @_;

    my $shipment_item_to_update_rs = $shipment_item_rs->search({
        shipment_item_status_id => $existing_shipment_item_status_id
    });

    # Update allocations, etc. before shipment_items, since that
    # changes the status
    my $allocation_item_rs = $shipment_item_to_update_rs
        ->search_related("allocation_items");

    # update allocations
    my $allocation_rs = $allocation_item_rs->search_related("allocation");
    $allocation_rs->update({ status_id => $allocation_status_id });
    if ($allocation_status_id == $ALLOCATION_STATUS__PICKING) {
        $allocation_rs->update({ pick_sent => \"NOW()" });
    }

    # and allocation_items
    $allocation_item_rs
        ->update({ status_id => $allocation_item_status_id });

    # update shipment item
    $shipment_item_to_update_rs->update({
        shipment_item_status_id => $shipment_item_status_id
    });

}

sub allocate_shipment_and_allocation_item {
    my ($self, $shipment_item_row) = @_;
    my $shipment_item_status_id   = $SHIPMENT_ITEM_STATUS__NEW;
    my $allocation_status_id      = $ALLOCATION_STATUS__ALLOCATED;
    my $allocation_item_status_id = $ALLOCATION_ITEM_STATUS__ALLOCATED;

    $shipment_item_row->update({
        shipment_item_status_id => $shipment_item_status_id,
    });

    my @allocation_item_rows = $shipment_item_row->allocation_items;
    $_->update({ status_id => $allocation_item_status_id }) for
        @allocation_item_rows;

    my $allocation_row = $allocation_item_rows[0]->allocation;
    $allocation_row->update({ status_id => $allocation_status_id });
}

sub select_shipment {
    my ($self, $shipment) = @_;
    $self->_set_shipment_and_allocation_statuses(
        scalar $shipment->shipment_items,
        $SHIPMENT_ITEM_STATUS__NEW,
        $SHIPMENT_ITEM_STATUS__SELECTED,
        $ALLOCATION_STATUS__PICKING,
        $ALLOCATION_ITEM_STATUS__PICKING,
    );
}

sub select_shipment_item {
    my ($self, $shipment_item_row) = @_;
    my $schema = $shipment_item_row->result_source->schema;
    my $shipment_item_rs = $schema->resultset("Public::ShipmentItem");
    $self->_set_shipment_and_allocation_statuses(
        scalar $shipment_item_rs->search({ "me.id" => $shipment_item_row->id }),
        $SHIPMENT_ITEM_STATUS__NEW,
        $SHIPMENT_ITEM_STATUS__SELECTED,
        $ALLOCATION_STATUS__PICKING,
        $ALLOCATION_ITEM_STATUS__PICKING,
    );
}

sub allocating_pack_space_for_shipment {
    my ($self, $shipment) = @_;
    $self->_set_shipment_and_allocation_statuses(
        scalar $shipment->shipment_items,
        $SHIPMENT_ITEM_STATUS__SELECTED,
        $SHIPMENT_ITEM_STATUS__SELECTED,
        $ALLOCATION_STATUS__ALLOCATING_PACK_SPACE,
        $ALLOCATION_ITEM_STATUS__PICKED,
    );
}

sub stage_shipment {
    my ($self, $shipment) = @_;

    my @container_ids;
    foreach my $allocation ($shipment->allocations) {
        next unless $allocation->prl->has_staging_area;
        my $shipment_item_rs = $allocation->allocation_items->related_resultset('shipment_item');
        $self->_set_shipment_and_allocation_statuses(
            $shipment_item_rs,
            $SHIPMENT_ITEM_STATUS__SELECTED,
            $SHIPMENT_ITEM_STATUS__PICKED,
            $ALLOCATION_STATUS__STAGED,
            $ALLOCATION_ITEM_STATUS__PICKED,
        );

        my $container_id = Test::XT::Data::Container->get_unique_id;
        $shipment_item_rs->pick_into(
            $container_id,
            $APPLICATION_OPERATOR_ID,
        );
        push @container_ids, $container_id;
    }

    return @container_ids;
}

sub deliver_goh_allocations {
    my ($self, $shipment, $destination_id) = @_;

    $destination_id //= $PRL_DELIVERY_DESTINATION__GOH_DIRECT;

    $self->select_shipment($shipment);
    foreach my $allocation ($shipment->allocations) {
        next unless ($allocation->prl_id == $PRL__GOH);
        $self->allocation_pick_complete($allocation);
        $allocation->update({
            status_id => $ALLOCATION_STATUS__DELIVERED,
        });
        foreach my $allocation_item ($allocation->allocation_items) {
            $allocation_item->update({
                delivered_at   => \"now()",
                delivery_order => \"nextval('allocation_item_delivery_order_seq')",
                actual_prl_delivery_destination_id => $destination_id,
            });

        }
    }
}

sub stage_allocation {
    my ($self, $allocation_row) = @_;

    my $shipment_item_rs = $allocation_row
        ->allocation_items
        ->search_related("shipment_item");

    $self->_set_shipment_and_allocation_statuses(
        scalar $shipment_item_rs,
        $SHIPMENT_ITEM_STATUS__SELECTED,
        $SHIPMENT_ITEM_STATUS__PICKED,
        $ALLOCATION_STATUS__STAGED,
        $ALLOCATION_ITEM_STATUS__PICKED,
    );

    my $container_id = Test::XT::Data::Container->get_unique_id;
    $shipment_item_rs->pick_into(
        $container_id,
        $APPLICATION_OPERATOR_ID,
    );

    return $container_id;
}

=head2 pick_shipment ($shipment_row, ?$container_id) : $container_id

Pick a shipment. The entire shipment is picked into the same container.
If the container doesn't yet exist in the database, it will be created
by the pick_into method that this uses.

NOTE: This method may not be suitable for multi-PRL allocations, because
depending on the purpose of the test, picking everything into the same
container may be unrealistic or even impossible because of the mix rules
build into $shipment_items->pick_into.

Return the container id that the shipment has been picked into.

=cut

sub pick_shipment {
    my ($self, $shipment, $container_id) = @_;

    $self->_set_shipment_and_allocation_statuses(
        scalar $shipment->shipment_items,
        [ $SHIPMENT_ITEM_STATUS__SELECTED, $SHIPMENT_ITEM_STATUS__PICKED ],
        $SHIPMENT_ITEM_STATUS__PICKED,
        $ALLOCATION_STATUS__PICKED,
        $ALLOCATION_ITEM_STATUS__PICKED,
    );

    my @container_ids;

    if ($shipment->allocations->count && !$container_id) {
        # If we've got allocations and the caller didn't supply a container
        # id, we should choose a different container for each allocation.
        # Note: We're getting it all the way to picked, which means that
        # GOH allocation items will no longer be on individual hooks, because
        # the allocation status only moves to Picked status when integration
        # has been completed and they're in a tote.
        foreach my $allocation ($shipment->allocations) {
            my $tote_id = Test::XT::Data::Container->get_unique_id(); # default is tote
            foreach my $allocation_item ($allocation->allocation_items) {
                $allocation_item->shipment_item->pick_into(
                    $tote_id,
                    $APPLICATION_OPERATOR_ID,
                );
            }
            push @container_ids, $tote_id;
        }
    } else {
        $container_id //= Test::XT::Data::Container->get_unique_id;
        $shipment->shipment_items->pick_into(
            $container_id,
            $APPLICATION_OPERATOR_ID,
        );
        push @container_ids, $container_id;
    }

    return @container_ids;
}

=head2 pick_goh_shipment ($shipment_row, ?$container_ids) : $hook_ids

Similar to C<pick_shipment> above, but GOH is different enough that it's
useful to have a separate method for it. Each item is picked onto its own
hook, the allocation status doesn't get as far as Picked until after
integration, and we don't use the pick_into method on shipment items.

If hook ids are supplied, they will be used, but their corresponding
container rows must already exist in the database.

Return arrayref of the hook ids used.

NOTE: This method doesn't currently support doing the right thing for
cancelled items/allocations/shipments.

=cut

sub pick_goh_shipment {
    my ($self, $shipment, $container_ids) = @_;
    $container_ids //= [];

    my @hook_ids_used;
    my $goh_allocations = $shipment->allocations->search({
        prl_id    => $PRL__GOH,
    });
    foreach my $allocation ($goh_allocations->all) {
        foreach my $allocation_item ($allocation->allocation_items) {
            # if we have a spare hook id from those supplied, pick to that, otherwise
            # create a new one
            my $hook_id = shift @$container_ids
                // Test::XT::Data::Container->create_new_container_row({
                        prefix             => 'KT',
                        final_digit_length => 4,
                })->id
            ;
            $allocation_item->update({
                status_id   => $ALLOCATION_ITEM_STATUS__PICKED,
                picked_into => $hook_id,
                picked_at   => \'now()',
            });
            $allocation_item->shipment_item->update({
                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED,
                container_id            => $hook_id,
            });
            push @hook_ids_used, $hook_id;
        }
        $allocation->update({
            status_id => $ALLOCATION_STATUS__ALLOCATING_PACK_SPACE
        });
    }

    return \@hook_ids_used;
}

sub allocation_pick_complete {
    my ($self, $allocation_row) = @_;

    my $shipment_item_rs = $allocation_row
        ->allocation_items
        ->search_related("shipment_item");

    my $new_allocation_status_id
        = $allocation_row->prl->pick_complete_allocation_status;

    $self->_set_shipment_and_allocation_statuses(
        scalar $shipment_item_rs,
        [ $SHIPMENT_ITEM_STATUS__SELECTED, $SHIPMENT_ITEM_STATUS__PICKED ],
        $SHIPMENT_ITEM_STATUS__PICKED,
        $new_allocation_status_id,
        $ALLOCATION_ITEM_STATUS__PICKED,
    );

    my @container_ids_used;

    if ($allocation_row->prl_id == $PRL__GOH) {
        foreach my $allocation_item (sort {$a->id <=> $b->id} $allocation_row->allocation_items) {
            my $hook_id = Test::XT::Data::Container->get_unique_id({
                final_digit_length => 4,
                prefix             => 'KH',
            });
            $allocation_item->shipment_item->pick_into(
                $hook_id,
                $APPLICATION_OPERATOR_ID,
                {dont_validate => 1},
            );
            push @container_ids_used, $hook_id;
        }
    } else {
        my $tote_id = Test::XT::Data::Container->get_unique_id(); # default is tote
        foreach my $allocation_item (sort {$a->id <=> $b->id} $allocation_row->allocation_items) {
            $allocation_item->shipment_item->pick_into(
                $tote_id,
                $APPLICATION_OPERATOR_ID,
            );
        }
        push @container_ids_used, $tote_id;
    }

    return @container_ids_used;
}

=head2 set_item_shipping_restrictions

    $self->set_item_shipping_restrictions( $shipment_obj, $restrictions_hash );

This sets all Shipment Items for a Shipment to have the same Shipping Restrictions.

Pass in a Shipment Object and a HASH of Restrictions that will be applied to the Product's
Shipping Attributes.

Use the key 'ship_restrictions' to put an Array Ref of Ship Restriction Ids to apply
to the Product.

=cut

sub set_item_shipping_restrictions {
    my ( $self, $shipment, $restrictions )  = @_;

    return      if ( !$restrictions );

    my $ship_restrictions = delete $restrictions->{ship_restrictions};

    my $product_rs = $shipment->discard_changes
                                ->shipment_items
                                    ->related_resultset('variant')
                                        ->related_resultset('product');

    if ( scalar keys %{ $restrictions } ) {
        $product_rs->related_resultset('shipping_attribute')
                        ->update( $restrictions );
    }

    if ( $ship_restrictions ) {
        # add Ship Restrictions to each Product
        foreach my $ship_restrict_id ( @{ $ship_restrictions } ) {
            foreach my $product ( $product_rs->reset->all ) {
                $product->create_related( 'link_product__ship_restrictions', {
                    ship_restriction_id => $ship_restrict_id,
                } );
            }
        }
    }

    return;
}

=head2 clear_item_shipping_restrictions

    $self->clear_item_shipping_restrictions( $shipment_obj );

This clears all Shipment Items for a Shipment of having any Restricted Shipping Attributes.

=cut

sub clear_item_shipping_restrictions {
    my ( $self, $shipment ) = @_;

    my $schema = schema_handle();
    my $country = $schema->resultset('Public::Country')
                            ->find_by_name( config_var('DistributionCentre','country') );

    $shipment->shipment_items
                ->related_resultset('variant')
                    ->related_resultset('product')
                        ->related_resultset('shipping_attribute')
                            ->update( {
        # add more restrictions when known
        is_hazmat           => 0,
        fish_wildlife       => 0,
        cites_restricted    => 0,
        country_id          => $country->id,
    } );

    return;
}

=head2 clear_item_ship_restrictions

    $self->item_ship_restriction( $shipment_obj );

This will remove any Ship Restrictions for all the Products for the Shipment.

=cut

sub clear_item_ship_restrictions {
    my ( $self, $shipment ) = @_;

    $shipment->discard_changes
        ->shipment_items
            ->related_resultset('variant')
                ->related_resultset('product')
                    ->related_resultset('link_product__ship_restrictions')
                        ->delete;

    return;
}

sub create_new_order {
    my ($self, $args) = @_;

    use Test::XT::Data;

    my $data = Test::XT::Data->new_with_traits(
        traits => [ 'Test::XT::Data::Order', ]
    );

    return $data->new_order(%$args);
}

sub link_shipment_to_order {
    my ($class, $args) = @_;

    $args->{shipment}->create_related('link_orders__shipment', {
        orders_id => $args->{order}->id()
    });
}

=head2 cancel_shipment

Cancel a whole shipment, doing only the fairly simple bits that set
the statuses, nothing complicated like refunds or updates to the order.

=cut

sub cancel_shipment {
    my ($self, $shipment, $args) = @_;
    return unless ($shipment);

    $shipment->update_status($SHIPMENT_STATUS__CANCELLED, $APPLICATION_OPERATOR_ID);
    foreach my $shipment_item ($shipment->shipment_items) {
        $shipment_item->cancel({
            operator_id => $APPLICATION_OPERATOR_ID,
            customer_issue_type_id  => $CANCEL_REASON__OTHER,
        });
    }
}


1;
