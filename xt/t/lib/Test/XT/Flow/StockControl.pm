package Test::XT::Flow::StockControl;

use NAP::policy "tt",     qw( test role );

requires 'mech';
requires 'note_status';
requires 'config_var';

#
# Push through the Stock Control Workflow
#
use Test::XTracker::Data;
use XTracker::Config::Local;
use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::MessageQueue;
use XTracker::Database::Stock qw(insert_quantity);

use Test::More::Prefix qw(test_prefix);
use Data::Dump qw(pp);
use XTracker::Constants             qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB qw(
    :channel
    :business
    :channel_transfer_status
    :stock_order_status
    :stock_transfer_type
    :authorisation_level
    :delivery_status
    :flow_status
);
use XTracker::Utilities qw/get_start_end_location/;
use XTracker::Database::Location qw/create_locations/;
use XTracker::PrintFunctions;
use XT::JQ::DC::Receive::Product::ChannelTransfer;
use Readonly;

# The options for these reasons are just hardcoded in
# root/base/stocktracker/inventory/stock_adjustment.tt
# so I guess it's ok to do this here too
Readonly my $STOCK_ADJUSTMENT_REASON => "Extra Stock";

with qw{
    Test::XT::Data::Location
    Test::XT::Flow::AutoMethods
    Test::XT::Flow::WMS
    Test::XT::PRL::Utils
};

############################
# Page workflow methods
############################

sub flow_mech__stockcontrol__inventory {
    my($self) = @_;
    $self->announce_method;

    $self->mech->get_ok('/StockControl/Inventory');
    like($self->mech->uri, qr{/StockControl/Inventory}, 'its the inventory');

    return $self;
}

sub flow_mech__stockcontrol__inventory_submit {
    my($self, $product_id) = @_;
    $self->announce_method;

    $product_id //= $self->product->id;
    $self->mech->submit_form_ok({
        with_fields => {
            product => $product_id,
        },
        button => 'action',
    }, 'enter delivery id');


    my $rx_str="Overview\\?product_id=" .$product_id .'$';
    my $link = $self->mech->look_down(
        'href',
        qr{$rx_str}
    );

    isnt($link, undef, 'link to correct product - '. $product_id);

    return $self;
}

sub flow_mech__stockcontrol__inventory_overview_variant {
    my($self, $variant_id) = @_;
    $self->announce_method;

#    $self->stock_order->stock_order_items->first->variant_id
#    ->deliveries
    $variant_id ||= $self->stock_order->stock_order_items->first->variant_id;

    $self->mech->get_ok('/StockControl/Inventory/Overview?variant_id='
        .$variant_id);

    like($self->mech->uri, qr{/StockControl/Inventory/Overview},
        'overview (variant mode)');

    return $self;
}

=head2 flow_mech__stockcontrol__inventory_overview_variant_recode

Follows the 'Recode Stock' link from a variant inventory overview page.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__stockcontrol__inventory_overview_variant_recode',
    link_description => 'Recode Stock',
    find_link        => { text => 'Recode Stock' },
    assert_location  => qr!^/StockControl/Inventory/Overview\?variant_id=\d+!,
);


# URI: /StockControl/Location
#   get the Inspection Request - Goods In page
#
sub flow_mech__stockcontrol__location {
    my($self) = @_;

    $self->announce_method;

    $self->mech->get_ok('/StockControl/Location');
    like($self->mech->uri, qr{/StockControl/Location},
        'its the Location page');

    return $self;
}


sub flow_mech__stockcontrol__location_create {
    my($self,$opts,$loc) = @_;

    $self->announce_method;

    $self->flow_mech__stockcontrol__location;
    $self->mech->follow_link_ok({text_regex => qr/Create/});

    return $self;
}

sub flow_mech__stockcontrol__location_create_submit {
    my($self,$opts,$loc) = @_;
    my $location_type = defined $opts->{location_type}
        ? $opts->{location_type} : $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;

    note 'location : '. $loc;
    my($dc,$floor,$zone,$location,$level) = $self->data__split_location($loc);

    $self->mech->submit_form_ok({
        with_fields => {
            start_floor     => $floor,
            start_zone      => $zone,
            start_location  => $location,
            start_level     => $level,

            end_floor       => $floor,
            end_zone        => $zone,
            end_location    => $location,
            end_level       => $level,

            frm_sales_channel   => $opts->{channel_id},
            location_type       => $location_type,
                # this should say main stock
        },
    }, 'submitting new location allocation');


    $self->mech->content_contains(
        "creating location $loc",
        'location created '. $loc);

    return $self;
}


# URI: /StockControl/PurchaseOrder
#   Get the Stock Control Purchase Orde page
#
sub flow_mech__stockcontrol__purchaseorder {
    my ($self) = @_;

    $self->announce_method;

    $self->mech->get_ok('/StockControl/PurchaseOrder');
    note $self->mech->uri;

    return $self;

}

# URI: /StockControl/PurchaseOrder
#   Submit the purchase order form
#
sub flow_mech__stockcontrol__purchaseorder_submit {
    my ($self) = @_;

    $self->announce_method;

    # Enter the purchase order in the 'PO Number' field
    my $search_form = $self->mech->form_name('searchForm');

    $self->mech->submit_form_ok({
        with_fields => {
            purchase_order_number   => $self->purchase_order->id,
        },
    }, "Submitting a search for the purchase order");

    return $self;
}

# URI: /StockControl/Location
#   submit the form to create some locations
sub flow_mech__stockcontrol__location_submit {
    my ($self, $loc) = @_;

    $self->announce_method;

    $self->mech->submit_form_ok({
        with_fields => {
            single_location => $loc,
        },
    }, 'search for a location - '. $loc);

    note $self->mech->uri;

    return $self;
}

# URI: /StockControl/PurchaseOrder/Overview?po_id=123
#   Get the Stock Control Purchase Order overview page
#

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__stockcontrol__purchaseorder_overview',
    page_description => 'Purchase Order Overview',
    page_url         => '/StockControl/PurchaseOrder/Overview?po_id=',
    required_param   => 'Purchase Order ID'
);

# URI: /StockControl/PurchaseOrder/Confirm?po_id=123
#   Get the Stock Control Purchase Order confirm page
#
sub flow_mech__stockcontrol__purchaseorder_confirm {
    my ($self) = @_;

    $self->announce_method;
    my $po_id = $self->purchase_order->id;
    unless ($self->purchase_order->is_editable_in_xt){
        $self->mech->get("/StockControl/PurchaseOrder/Confirm?po_id=$po_id");
        ok(!$self->mech->success,"Cannot Confirm PO that\'s has been marked as non editable in XT");
    }else{
        $self->mech->get_ok("/StockControl/PurchaseOrder/Confirm?po_id=$po_id");
    }
    return $self;
}


# URI: /StockControl/PurchaseOrder/Edit?po_id=123
#   Get the Stock Control Purchase Order Edit page
#
sub flow_mech__stockcontrol__purchaseorder_edit {
    my ($self) = @_;

    $self->announce_method;
    my $po_id = $self->purchase_order->id;
    unless ($self->purchase_order->is_editable_in_xt){
        $self->mech->get("/StockControl/PurchaseOrder/Edit?po_id=$po_id");
        ok(!$self->mech->success,"Cannot Confirm PO that\'s has been marked as non editable in XT");
    }else{
        $self->mech->get_ok("/StockControl/PurchaseOrder/Edit?po_id=$po_id");
    }
    return $self;
}


# URI: /StockControl/PurchaseOrder/Reorder?po_id=123
#   Get the Stock Control Purchase Order Reorder page
#
sub flow_mech__stockcontrol__purchaseorder_reorder {
    my ($self) = @_;

    $self->announce_method;
    my $po_id = $self->purchase_order->id;

    unless ($self->purchase_order->is_editable_in_xt){
        $self->mech->get("/StockControl/PurchaseOrder/ReOrder?po_id=$po_id");
        ok(!$self->mech->success,"Cannot Confirm PO that\'s has been marked as non editable in XT");
    }else{
        $self->mech->get_ok("/StockControl/PurchaseOrder/ReOrder?po_id=$po_id");
    }
    return $self;
}

# URI: /StockControl/PurchaseOrder/ReOrder?po_id=123
#   submit the form to reorder a purchase order
sub flow_mech__stockcontrol__purchaseorder_reorder_submit {
    my ($self, $args) = @_;

    $self->announce_method;

    SKIP: {
        skip "Edit PO features are disabled",2 unless $self->purchase_order->is_editable_in_xt;

        # Set up an AMQ test client
        my $destination
            =  config_var('Producer::Stock::DetailedLevelChange', 'destination');
        my $sender = Test::XTracker::MessageQueue->new();
        $sender->clear_destination( $destination );

        my $quantity            = defined $args->{quantity}         ? $args->{quantity}         : 5;
        my $start_ship_date     = defined $args->{start_ship_date}  ? $args->{start_ship_date}  : '2010-03-01';
        my $cancel_ship_date    = defined $args->{cancel_ship_date} ? $args->{cancel_ship_date} : '2010-04-01';

        my ($stock_order_item)  = $self->stock_order->stock_order_items;
        my $prod_id             = $self->stock_order->product_id;
        my $var_id              = $stock_order_item->variant_id;
        my $po_id               = $self->purchase_order->id;

        $self->mech->submit_form_ok({
            with_fields => {
                po_number                       => "$po_id - reorder",
                start_ship_date                 => $start_ship_date,
                cancel_ship_date                => $cancel_ship_date,
                "quantity_${prod_id}_${var_id}" => $quantity,
                purchase_order_id               => $po_id,
            },
            button => 'submit',
        }, "Submitting a search to re-order");

        # Check that it was submitted correctly

        my $message     = $self->mech->look_down('class', 'display_msg');
        my ($content)   = $message->content_list;
        is ($content, 'Re-Order successfully created', 'Created re-order');

        # Did we send the expected stock broadcast?
        $sender->assert_messages({
            destination => $destination,
            assert_body => superhashof({
                product_id => $prod_id,
            }),
            assert_count => 1,
        }, 'Stock broadcast sent');
    };
    return $self;
}


# URI: /StockControl/PurchaseOrder/StockOrder?so_id=123
#   Get the Stock Control Purchase Order Stock Order page
#
sub flow_mech__stockcontrol__purchaseorder_stockorder {
    my ($self) = @_;

    $self->announce_method;

    my $so_id           = $self->stock_order->id;
    note "stock_order ID = $so_id";

    $self->mech->get_ok("/StockControl/PurchaseOrder/StockOrder?so_id=$so_id");

    return $self;
}

# URI: /StockControl/PurchaseOrder/StockOrder?so_id=123
#   submit the form
sub flow_mech__stockcontrol__purchaseorder_stockorder_submit {
    my ($self, $args) = @_;

    $self->announce_method;
    note "URI ".$self->mech->uri;

    # Set up an AMQ test client
    my $destination
        =  config_var('Producer::Stock::DetailedLevelChange', 'destination');
    my $sender = Test::XTracker::MessageQueue->new();
    $sender->clear_destination( $destination );

    my $schema  = Test::XTracker::Data->get_schema;

    my $quantity            = defined $args->{quantity}         ? $args->{quantity}         : 5;
    my $start_ship_year     = defined $args->{start_ship_year}  ? $args->{start_ship_year}  : '2008';
    my $cancel_ship_year    = defined $args->{cancel_ship_year} ? $args->{cancel_ship_year} : '2008';

    my ($stock_order_item)  = $self->stock_order->stock_order_items;
    my $soi_id              = $stock_order_item->id;

    # If Purchase Order is NOT editable in XT, check submit button does not exist
    if ( !$self->stock_order->purchase_order->is_editable_in_xt ) {
        ok( !$self->mech->findnodes('//div[@id="submit_stock_order_details"]//input[@class="button"]') );
    }
    else {
        $self->mech->submit_form_ok({
            with_fields => {
                start_ship_year     => $start_ship_year,
                cancel_ship_year    => $cancel_ship_year,
                "cancel-$soi_id"    => 'on',
                "ordered-$soi_id"   => $quantity,
            },
            button => 'submit',
        }, "Submitting a search to change the start/cancel year");

        # Check that it was submitted correctly

        note "URI ".$self->mech->uri;

        # Confirm that the date change happened
        my ($stock_order) = $schema->resultset('Public::StockOrder')->search({purchase_order_id => $self->purchase_order->id});
        isnt($stock_order, undef, 'Got a stock order');
        like($stock_order->start_ship_date, qr/^$start_ship_year/, 'Start ship date changed');
        like($stock_order->cancel_ship_date, qr/^$cancel_ship_year/, 'Cancel ship date changed');

        $stock_order_item = $schema->resultset('Public::StockOrderItem')->find($soi_id);
        is($stock_order_item->quantity, $quantity, 'Stock Order Item Quantity change');
        is($stock_order_item->cancel, 1, 'Stock Order Item Cancelled');

        my $prod_id             = $self->stock_order->product_id;
        # Did we send the expected stock broadcast?
        $sender->assert_messages({
            destination => $destination,
            assert_body => superhashof({
                product_id => $prod_id,
            }),
            assert_count => 1,
        }, 'Stock broadcast sent');
    }

    return $self;
}

=head2 flow_mech__stockcontrol__inventory_product_overview_link

Calls the 'Product Overview' left hand menu option on the Stock Control Inventory pages.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__stockcontrol__inventory_product_overview_link',
    link_description => 'Product Overview',
    find_link        => { text => 'Product Overview' },
    assert_location  => qr!^/StockControl/Inventory/.*!,
);


sub flow_mech__stockcontrol__inventory_productdetails {
    my($self, $pid) = @_;
    $self->announce_method;

    $pid ||= $self->product->id;
    my $uri = "/StockControl/Inventory/ProductDetails?product_id=$pid";

    $self->mech->get_ok( $uri );

    like($self->mech->uri, qr{/StockControl/Inventory/ProductDetails},
        'its the ProductDetails page');

    return $self;

}
# URI: /StockControl/Inventory/ProductDetails
#   submit the form to update product details
sub flow_mech__stockcontrol__inventory_productdetails_submit {
    my ($self, $fields) = @_;

    $self->announce_method;
    return unless keys %$fields;

    # each field needs and '_edit' = on field
    my $form_params = {map {$_ => $fields->{$_}, "edit_$_" => 'on'}  keys %$fields};

    $self->mech->submit_form_ok({
        with_fields => $form_params,
    }, 'update details - '. pp($form_params));

    note $self->mech->uri;

    return $self;
}

sub flow_mech__stockcontrol__inventory_pricing {
    my($self) = @_;
    $self->announce_method;

    my $uri = '/StockControl/Inventory/Pricing?product_id='
        .$self->product->id;

    $self->mech->get_ok( $uri );

    like($self->mech->uri, qr{/StockControl/Inventory/Pricing},
        'its the Pricing page');

    return $self;
}

sub flow_mech__stockcontrol__inventory_sizing {
    my($self) = @_;
    $self->announce_method;

    my $uri = '/StockControl/Inventory/Sizing?product_id='
        .$self->product->id;

    $self->mech->get_ok( $uri );

    like($self->mech->uri, qr{/StockControl/Inventory/Sizing},
        'its the Sizing page');

    return $self;
}

=head2 flow_mech__stockcontrol__product_overview__measurement_link

Click on the 'Measurements' link on the Stock Overview page.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__stockcontrol__product_overview__measurement_link',
    link_description => 'Measurements',
    find_link        => { text => 'Measurements' },
    assert_location  => qr!^/StockControl/Inventory/.*!,
);

sub flow_mech__stockcontrol__measurement {
    my($self) = @_;
    $self->announce_method;

    $self->mech->get_ok('/StockControl/Measurement');

    like($self->mech->uri, qr{/StockControl/Measurement},
        'its the Measurement page');

    return $self;
}

sub flow_mech__stockcontrol__measurement_submit {
    my($self) = @_;
    $self->announce_method;

    my $pid = $self->product->id;
    note "PID: $pid";

    $self->mech->submit_form_ok({
        with_fields => {
            product_id => $pid,
        },
        button => 'submit',
    }, "submitting PID");

    return $self;
}

sub flow_mech__stockcontrol__measurement_edit_submit {
    my($self, $args) = @_;
    $self->announce_method;

    my %measurement_fields;
    if ( exists $args->{'measurements'} ) {
        # Measurements fields
        foreach my $variant ($self->product->variants) {
            next unless ($args->{'measurements'}->{$variant->id});
            foreach my $measurement (@{$self->attr__measurements__measurement_types}) {
                my $field_name = "measure-".$variant->id."-".$measurement->measurement;
                my $field_value = $args->{'measurements'}->{$variant->id}->{$measurement->id};
                $measurement_fields{$field_name} = $field_value;
            }
        }
    }

    $self->mech->submit_form_ok({
        with_fields => {
            prodid => $self->product->id,
            %measurement_fields,
        },
        button => 'submit',
    }, "submitting measurements");

    $self->note_status();

    return $self;
}



sub flow_mech__stockcontrol__stockcheck {
    my($self) = @_;
    $self->announce_method;

    $self->mech->get_ok('/StockControl/StockCheck');

    like($self->mech->uri, qr{/StockControl/StockCheck},
        'its the Stock Check page');

    return $self;
}

sub flow_mech__stockcontrol__stockcheck_submit {
    my($self,$loc) = @_;
    $self->announce_method;

    note "location : $loc";
    $self->mech->submit_form_ok({
        with_fields => {
            location => $loc,
        },
        button => 'submit',
    }, "submitting location");

    return $self;
}

sub flow_mech__stockcontrol__stockcheck_product {
    my($self) = @_;
    $self->announce_method;

    $self->mech->get_ok('/StockControl/StockCheck/Product');

    like($self->mech->uri, qr{/StockControl/StockCheck/Product},
        'its the Stock Check Product page');

    return $self;
}

sub flow_mech__stockcontrol__stockcheck_product_submit {
    my($self) = @_;
    $self->announce_method;

    my $pid = $self->product->id;
    note "pid : $pid";
    $self->mech->submit_form_ok({
        with_fields => {
            product_id => $pid,
        },
        button => 'submit',
    }, "submitting PID");

    return $self;
}

sub flow_mech__stockcontrol__stockrelocation {
    my($self) = @_;
    $self->announce_method;

    $self->mech->get_ok('/StockControl/StockRelocation');

    like($self->mech->uri, qr{/StockControl/StockRelocation},
        'its the Stock Relocation page');

    return $self;
}

sub _channel_name_or_unknown {
    map { defined $_->channel?$_->channel->name:'unknown channel' } @_;
}

sub flow_mech__stockcontrol__stockrelocation_submit {
    my($self,$from_loc_name,$to_loc_name) = @_;
    $self->announce_method;

    $self->scan( $from_loc_name );
    $self->scan( $to_loc_name   );

    my $schema = Test::XTracker::Data->get_schema;

    my $from_location = $schema->resultset('Public::Location')->search({
        'location' => $from_loc_name,
    })->first;

    my $to_location = $schema->resultset('Public::Location')->search({
        'location' => $to_loc_name,
    })->first;

    # Complete the move
    $self->mech->submit_form_ok({
    with_fields => {
        to_location     => $to_loc_name,
        from_location   => $from_loc_name,
    },
    button => 'submitbutton',
    }, "completing move");

    $self->note_status();

    return $self;
}

sub flow_mech__stockcontrol__inventory_stockadjustment_variant {
    my($self) = @_;
    $self->announce_method;

    my $variant_id = $self->stock_order->stock_order_items->first->variant_id;
    $self->mech->get_ok(
        "/StockControl/StockAdjustment/AdjustStock?variant_id=$variant_id");

    note $self->mech->uri;

    like($self->mech->uri, qr{/StockControl/StockAdjustment/AdjustStock},
        'its the Stock Adjustment page');

    return $self;
}


# Make some adjustments
# This ensures things show up when we look at the variant transaction
# log later
sub flow_mech__stockcontrol__inventory_stockadjustment_variant_submit {
    my($self) = @_;
    $self->announce_method;

    my $variant_id = $self->stock_order->stock_order_items->first->variant_id;
    my $location_id = $self->stock_order->stock_order_items->first->variant->quantities->first->location_id;
    my $field_name_postfix = join '_', $variant_id, $location_id, $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;

    $self->mech->submit_form_ok({
        with_fields => {
            'quantity_' . $field_name_postfix => 23,
              'reason_' . $field_name_postfix => $STOCK_ADJUSTMENT_REASON,
               'notes_' . $field_name_postfix => "Test adjustment",

        },
        button => 'submit',
    }, "submitting stock adjustment");

    isnt($self->mech->app_status_message, undef, "Confirmation message displayed");
    is($self->mech->app_error_message, undef, "No error message displayed");

    return $self;
}

sub flow_mech__stockcontrol__inventory_log_product_deliverylog {
    my($self) = @_;
    $self->announce_method;
    my $pid = $self->product->id;

    $self->mech->get_ok(
        '/StockControl/Inventory/Log/Product/DeliveryLog?product_id='
        . $pid);

    like($self->mech->uri, qr{/StockControl/Inventory/Log/Product/DeliveryLog},
        'its the Delivery Log page');

    return $self;
}

sub flow_mech__stockcontrol__inventory_log_product_allocatedlog {
    my($self) = @_;
    $self->announce_method;
    my $pid = $self->product->id;

    $self->mech->get_ok(
        '/StockControl/Inventory/Log/Product/AllocatedLog?product_id='
        . $pid);

    like($self->mech->uri, qr{/StockControl/Inventory/Log/Product/AllocatedLog},
        'its the Allocated Log page');

    return $self;
}

sub flow_mech__stockcontrol__inventory_log_variant_transactionlog {
    my($self) = @_;
    $self->announce_method;
    my $pid = $self->product->id;

    my $variant_id = $self->stock_order->stock_order_items->first->variant_id;
    $self->mech->get_ok(
        '/StockControl/Inventory/Log/Variant/StockLog?variant_id='
        . $variant_id);

    like($self->mech->uri, qr{/StockControl/Inventory/Log/Variant/StockLog\?variant_id},
        'its the Variant Transaction Log page');

    return $self;
}

sub flow_mech__stockcontrol__inventory_log_variant_rtvlog {
    my($self) = @_;
    $self->announce_method;
    my $pid = $self->product->id;

    my $variant_id = $self->stock_order->stock_order_items->first->variant_id;
    $self->mech->get_ok(
        '/StockControl/Inventory/Log/Variant/RTVLog?variant_id='
        . $variant_id);

    like($self->mech->uri, qr{/StockControl/Inventory/Log/Variant/RTVLog\?variant_id},
        'its the Variant RTV Log page');

    return $self;
}

sub flow_mech__stockcontrol__inventory_log_variant_pwslog {
    my($self) = @_;
    $self->announce_method;
    my $pid = $self->product->id;

    my $variant_id = $self->stock_order->stock_order_items->first->variant_id;
    $self->mech->get_ok(
        '/StockControl/Inventory/Log/Variant/PWSLog?variant_id='
        . $variant_id);

    like($self->mech->uri, qr{/StockControl/Inventory/Log/Variant/PWSLog\?variant_id},
        'its the Variant PWS Log page');

    return $self;
}

sub flow_mech__stockcontrol__inventory_log_variant_locationlog {
    my($self) = @_;
    $self->announce_method;
    my $pid = $self->product->id;

    my $variant_id = $self->stock_order->stock_order_items->first->variant_id;
    $self->mech->get_ok(
        '/StockControl/Inventory/Log/Variant/LocationLog?variant_id='
        . $variant_id);

    like($self->mech->uri, qr{/StockControl/Inventory/Log/Variant/LocationLog\?variant_id},
        'its the Variant Location Log page');

    return $self;
}

sub flow_mech__stockcontrol__finalpick {
    my($self) = @_;

    $self->announce_method;
    $self->mech->get_ok('/StockControl/FinalPick');

    like($self->mech->uri, qr{/StockControl/FinalPick},
        'its the Final Pick page');

    return $self;
}

sub flow_mech__stockcontrol__dead_stock_add_item{
    my ($self) = @_;
    $self->announce_method;

    return $self;
}

sub flow_mech__stockcontrol__dead_stock_view_list{
    my ($self) = @_;
    $self->announce_method;
    $self->mech->get_ok('/StockControl/DeadStock');

    return $self;
}

sub flow_mech__stockcontrol__dead_stock_update{
    my ($self) = @_;
    $self->announce_method;

    return $self;
}

=head2 flow_mech__stockcontrol__inventory_moveaddstock

Retrieve C</StockControl/Inventory/MoveAddStock>. You must provide the
variant ID as the single argument.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__stockcontrol__inventory_moveaddstock',
    page_description => 'Move/Add Stock Page',
    page_url         => '/StockControl/Inventory/MoveAddStock?variant_id=',
    required_param   => 'Variant ID'
);

=head2 flow_mech__stockcontrol__inventory_moveaddstock_submit

Set a new location value for some stock item, posting
to C</StockControl/Inventory/SetStockLocation>.

 1234_5678 => { quantity => 5, location => '01ZZ31NC' }

where  1234 is variant ID, and 5678 is the current location ID.

You can derive this information by calling as_data following
a successful invocation of flow_mech__stockcontrol__inventory_moveaddstock,
and examining the input tag names returned in the 'Stock by Location' form.

=cut

sub  flow_mech__stockcontrol__inventory_moveaddstock_submit {
    my ($self, $args) = @_;

    $self->assert_location(qr!^/StockControl/Inventory/MoveAddStock!);

    # mangle the hash into compatible form fields that SetStockLocation
    # expects to see; so:
    #
    # { 1234_5678 => { quantity => 5, location => '01ZZ31NC' } }
    #
    # becomes:
    #
    #  { nquantity_1234_5678 => 5, nlocation_1234_5678 => '01ZZ31NC' }
    #

    my %form_fields = map {
        my $var_loc = $_;
        map { my $prop = $_;
          'n' . $prop . '_' . $var_loc => $args->{$var_loc}->{$prop}
        } keys %{$args->{$var_loc}};
    } keys %{$args};

    $self->mech->submit_form( with_fields => \%form_fields );

    $self->note_status;

    return $self;
}

sub  flow_mech__stockcontrol__inventory_moveaddstock_assign_submit {
    my ($self, $args) = @_;

    $self->assert_location(qr!^/StockControl/Inventory/MoveAddStock!);

    # mangle the hash into compatible form fields that SetStockLocation
    # expects to see; so:
    #
    # { 1234_5678 => {  location => '01ZZ31NC' } }
    #
    # becomes:
    #
    #  { assign_1234_5678_1 => '01ZZ31NC' }
    #

    my %form_fields = map {
          'assign_' . $_ . '_1' => $args->{$_}->{location}
    } keys %{$args};

    $self->mech->submit_form( with_fields => \%form_fields );

    $self->note_status;

    return $self;
}
__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__stockcontrol__sample_request_stock__by_product',
    page_description => 'Request Stock Page',
    page_url         => '/StockControl/Sample/RequestStock?product_id=',
    required_param   => 'Product ID'
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__stockcontrol__sample_request_stock__by_variant',
    page_description => 'Request Stock Page',
    page_url         => '/StockControl/Sample/RequestStock?variant_id=',
    required_param   => 'Variant ID'
);

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__stockcontrol__sample_request_stock_submit',
    form_name         => 'search',
    form_description  => 'stock request',
    assert_location   => qr!^/StockControl/Sample/RequestStock!,
    transform_fields  => sub {
        my $reason = $_[1] || $STOCK_TRANSFER_TYPE__SAMPLE;
        note "\nstock_transfer_type: [$reason]";
        return { type_id => $reason }
    },
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__stockcontrol__sample_requests',
    page_description => 'Sample Requests Page',
    page_url         => '/StockControl/Sample',
);

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__stockcontrol__sample_requests_submit',
    form_name => 'search_1',  # it does not matter if the request we
                              # want to submit is in another "tab" in
                              # the page, the submitted fields will be
                              # the same
    form_description  => 'sample request approval',
    assert_location   => qr!^/StockControl/Sample!,
    transform_fields  => sub {
        my ($self,$transfer_id) = @_;

        return { "approve-$transfer_id" => 1 }
    },
);

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__stockcontrol__sample_cancel_shipment',
    form_name => sub { 'cancelShipment'.$_[1] },
    form_description  => 'sample request cancel',
    assert_location   => qr!^/StockControl/Sample!,
    transform_fields  => sub {
        my ($self,$shipment_id) = @_;

        return { shipment_id => $shipment_id }
    },
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__stockcontrol__sample_return_stock__by_product',
    page_description => 'Return Stock Page',
    page_url         => '/StockControl/Sample/ReturnStock?product_id=',
    required_param   => 'Product ID'
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__stockcontrol__sample_return_stock__by_variant',
    page_description => 'Return Stock Page',
    page_url         => '/StockControl/Sample/ReturnStock?variant_id=',
    required_param   => 'Variant ID'
);

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__stockcontrol__sample_return_submit',
    form_name         => 'return_stock',
    form_description  => 'sample return',
    assert_location   => qr!^/StockControl/Sample/ReturnStock!,
    transform_fields  => sub {
        my ($self,$args) = @_;

        my $variant_id = $args->{variant_id};
        my $location_id = $args->{location_id};
        my $channel_id = $args->{channel_id};

        return { return => "return_${variant_id}-${location_id}-${channel_id}" }
    },
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__stockcontrol__sample_goods_in_variant',
    page_description => 'Vendor Sample Goods In',
    page_url         => '/StockControl/Sample/SamplesIn?variant_id=',
    required_param   => 'Variant ID'
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__stockcontrol__sample_goods_in_submit',
    form_name        => 'SetVendorSampleGoodsIn',
    form_description => 'Vendor Sample Goods in',
    assert_location  => qr'^/StockControl/Sample/SamplesIn',
    transform_fields => sub {
        my ( $self, $args ) = @_;
        my %form_fields;

        if ( exists $args->{'goods_in'} ) {
            my %page_skus = map {
                my $sku = $_->{'SKU'};
                my $id  = $_->{'Delivered'}->{'input_name'};
                $id =~ s/.+_//;
                $sku => $id;
            } @{ $self->mech->as_data->{'goods_in'} };

            for my $sku ( keys %{ $args->{'goods_in'} } ) {
                my $id = $page_skus{ $sku } || croak "Can't find SKU [$sku] for QC";
                $form_fields{"delivered_$id"} = $args->{'fast_track'}->{$sku};
            }
        }

        return \%form_fields;
    }
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__stockcontrol__sample_goods_out_variant',
    page_description => 'Vendor Sample to Stock',
    page_url         => '/StockControl/Sample/GoodsOut?variant_id=',
    required_param   => 'Variant ID'
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__stockcontrol__sample_goods_out_submit',
    form_name        => 'VendorSampleGoodsOut',
    form_description => 'Vendor Sample to Stock',
    assert_location  => qr'^/StockControl/Sample/GoodsOut',
    transform_fields => sub {
        my ( $self, $args ) = @_;
        my %form_fields;

        if ( exists $args->{'goods_out'} ) {
            my %page_skus = map {
                my $sku = $_->{'SKU'};
                my $id  = $_->{'Move to Stock'}->{'input_name'};
                my $value  = $_->{'Move to Stock'}->{'input_value'};
                $sku => [$id,$value];
            } @{ $self->mech->as_data->{'goods_out'} };

            for my $sku ( @{ $args->{'goods_out'} } ) {
                my $input = $page_skus{ $sku } || croak "Can't find SKU [$sku] for QC";
                $form_fields{$input->[0]} = $input->[1];
            }
        }

        return \%form_fields;
    }
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__stockcontrol__channel_transfer',
    page_description => 'Channel Transfer',
    page_url         => '/StockControl/ChannelTransfer',
);
__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__stockcontrol__channel_transfer__select',
    form_name        => 'SelectTransfers_1',
    form_description => 'Channel Transfer selection',
    assert_location  => qr'^/StockControl/ChannelTransfer',
    transform_fields => sub {
        my ( $self, $transfers ) = @_;
        my %form_fields;

        my @ids = (ref($transfers) ? @$transfers : $transfers);
        for my $id (@ids) {
            $form_fields{"select_$id"}=1
        }

        return \%form_fields;
    },
);

# Channel transfer picking
__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__stockcontrol__channel_transfer_picking',
    page_description => 'Channel Transfer',
    page_url         => '/StockControl/ChannelTransfer?list_type=Picking',
);
__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__stockcontrol__channel_transfer_picking_submit',
    scan_description => 'Channel transfer picking submit',
    assert_location  => '/StockControl/ChannelTransfer?list_type=Picking',
);
__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__stockcontrol__channel_transfer_picking_submit_location',
    form_name        => 'pickTransfer',
    form_description => 'Channel transfer picking location',
    assert_location  => qr'^/StockControl/ChannelTransfer/Pick',
    transform_fields => sub {
        my ($self, $location) = @_;
        return {'location' => $location};
    },
);
__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__stockcontrol__channel_transfer_picking_submit_sku',
    form_name        => 'pickTransfer',
    form_description => 'Channel transfer picking sku',
    assert_location  => qr'^/StockControl/ChannelTransfer/Pick',
    transform_fields => sub {
        my ($self, $sku) = @_;
        return {'sku' => $sku};
    },
);
__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__stockcontrol__channel_transfer_picking_submit_quantity',
    form_name        => 'pickTransfer',
    form_description => 'Channel transfer picking quantity',
    assert_location  => qr'^/StockControl/ChannelTransfer/Pick',
    transform_fields => sub {
        my ($self, $quantity) = @_;
        return {'quantity' => $quantity};
    },
);
__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__stockcontrol__channel_transfer_complete_pick',
    form_name        => 'pickTransferComplete',
    form_description => 'Channel transfer complete pick',
    assert_location  => qr'^/StockControl/ChannelTransfer/Pick',
    transform_fields => sub {
        my ($self, $args) = @_;
        return {'action' => 'Complete'};
    },
);


# Channel transfer putaway
__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__stockcontrol__channel_transfer_putaway',
    page_description => 'Channel Transfer putaway',
    page_url         => '/StockControl/ChannelTransfer?list_type=Putaway',
);
__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__stockcontrol__channel_transfer_putaway_submit',
    scan_description => 'Channel transfer putaway submit',
    assert_location  => '/StockControl/ChannelTransfer?list_type=Putaway',
);
__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__stockcontrol__channel_transfer_putaway_submit_location',
    form_name        => 'putawayTransfer',
    form_description => 'Channel transfer putaway location',
    assert_location  => qr'^/StockControl/ChannelTransfer/Putaway',
    transform_fields => sub {
        my ($self, $location) = @_;
        return {'putaway_location' => $location};
    },
);
__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__stockcontrol__channel_transfer_complete_putaway',
    form_name        => 'putawayComplete',
    form_description => 'Channel transfer complete putaway',
    assert_location  => qr'^/StockControl/ChannelTransfer/Putaway',
    transform_fields => sub {
        my ($self, $args) = @_;
        return {'action' => 'Complete'};
    },
);




__PACKAGE__->create_fetch_method(
    method_name => 'flow_mech__stockcontrol__recode',
    page_description => 'Recode',
    page_url => '/StockControl/Recode',
);

__PACKAGE__->create_fetch_method(
    method_name => 'flow_mech__stockcontrol__recode_variant',
    page_description => 'Recode',
    page_url => '/StockControl/Recode?variant_id=',
    required_param => 'Variant ID',
);

__PACKAGE__->create_form_method(
    method_name => 'flow_mech__stockcontrol__recode_select_skus',
    form_name => 'recode',
    form_description => 'recoding',
    assert_location => qr'^/StockControl/Recode$',
    transform_fields => sub {
        my ($self,@skus) = @_;
        my %fields;
        foreach my $sku (@skus) {
            $fields{$sku} = 'on';
        }
        return \%fields;
    },
);

__PACKAGE__->create_form_method(
    method_name => 'flow_mech__stockcontrol__recode_submit',
    form_name => 'recode',
    form_description => 'recoding',
    assert_location => qr'^/StockControl/Recode(\?variant_id=.+)?$',
    transform_fields => sub {
        my ($self,$args) = @_;
        my %fields;
        $args->{destroy}||={};keys %{$args->{destroy}};
        $args->{create}||={};keys %{$args->{create}};
        while (my ($sku,$quant) = each %{$args->{destroy}}) {
            $fields{"destroyquantity-$sku"}=$quant;
        }
        my $i=1;
        while (my ($sku,$quant) = each %{$args->{create}}) {
            $fields{"newsku_$i"}=$sku;
            $fields{"newquantity_$i"}=$quant;
            ++$i;
        }
        return \%fields;
    },
);

## Channel transfer task

=head2 task__stock_control__channel_transfer

A wrapper sub that is DC independent and will delegate executing the channel
transfer to the correct method. See docs for the methods as the phase 0 method
requires more arguments than the iws one.

=cut

sub task__stock_control__channel_transfer {
    my $self = shift;
    my $result = config_var('IWS', 'rollout_phase') || config_var('PRL', 'rollout_phase')
                 ? $self->flow_task__stock_control__channel_transfer_auto(@_)
                 : $self->flow_task__stock_control__channel_transfer_phase_0(@_);
    test_prefix;
    return $result;
}

=head2 flow_task__stock_control__channel_transfer_auto

 ->flow_task__strock_control__channel_transfer_iws({
   product      => Product-Row, [required]
   channel_from => Channel-Row, [required]
   channel_to   => Channel-Row, [required]
   transfer     => Channel Transfer object, [optional - we'll make one for you]

   # Not all channel transfers are expected to pass. If this one is meant to
   # fail, you can specify a regex here of how it's expected to fail.
   # IMPORTANT!!!!!! This will return the transfer that failed. If you're going
   # to retry it, you should hold on to that so you can re-use it later.
   expect_error => qr/Some error message/, [optional]

   schema       => Schema,    [optional - we'll pick one for you]
 })

Performs a Channel Transfer of one product to another. Returns the DBIC row
(matching the public.channel_transfer table) for the transfer it performed.

NB: This assumes an IWS world. See
    flow_task__stock_control__channel_transfer_phase_0
for (the start of) a manual equivalent (e.g. pre-automation dc2)

B<WARNING!!!!! DANGER!!!!> This will log your user in as:

    {
        perms => { $AUTHORISATION_LEVEL__MANAGER => [
            'Stock Control/Inventory',
            'Stock Control/Channel Transfer',
        ]},
        dept => 'Stock Control'
    }

You'll need to fix that afterwards if that doesn't work for you. You can set
C<extra_permissions> for other stuff to throw in the Manager Auth.

=cut

sub flow_task__stock_control__channel_transfer_auto {
    my ( $framework, $args ) = @_;

    my $schema = $args->{'schema'} || Test::XTracker::Data->get_schema();

    for my $monitor (qw/sent_monitor received_monitor/) {
        warn( join q{ - },
            "You could pass a value for $_ from the caller, but please don't",
            "it can call all sorts of scoping headaches. Consider refactoring."
        ) if $args->{$monitor};
    }

    my $product        = $args->{'product'}      || croak "You need to specify a product";
    my $source_channel = $args->{'channel_from'} || croak "You need to specify a channel_from";
    my $dest_channel   = $args->{'channel_to'}   || croak "You need to specify a channel_to";

    my ($auto_location, $cfg);
    if ( $args->{prl_loc} ) {
        $auto_location = $framework->data__location__get_named_location( $args->{prl_loc} );
        $cfg = 'prls';
    }
    else {
        $auto_location = $framework->data__location__get_invar_location();
        $cfg = 'wms';
    }
    # We shouldn't really be passing values for the monitors - it's too easy
    # for these to catch files they shouldn't be looking for
    my $stocksys_to_xt = $args->{received_monitor}
                      // Test::XTracker::Artifacts::RAVNI->new("${cfg}_to_xt");

    my $print_monitor = Test::XTracker::PrintDocs->new();

    # We only transfer products that are already live on the source channel
    $product->search_related('product_channel',
        { channel_id => $source_channel->id, },
    )->update({ live => 1, visible => 0 });
    is( $product->get_product_channel->channel_id,
        $source_channel->id,
        'DBIC get_product_channel returns correct channel_id before transfer' );
    $product->get_product_channel->update({visible=>0});
    my @variants = $schema->resultset('Public::Variant')
        ->search({
            product_id => $product->id,
        })->all;

    for my $variant (@variants) {
        $schema->resultset('Public::Quantity')
            ->update_or_create({
                status_id => $args->{status_id} || $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                location_id => $auto_location->id,
                variant_id => $variant->id,
                channel_id => $source_channel->id,
                quantity => 100,
            });
    }
    my @statuses = ($FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,$FLOW_STATUS__DEAD_STOCK__STOCK_STATUS);
    my $quantity_rs = $schema->resultset('Public::Quantity')
        ->search({
            status_id => { -in => \@statuses},
            location_id => $auto_location->id,
            variant_id => { -in => [ map { $_->id} @variants ] },
        });

    my $initial_quantity = $quantity_rs->search({channel_id => $source_channel->id})
        ->get_column('quantity')->sum();

    test_prefix( $Test::More::Prefix::prefix || 'Test'  . ': Initiate channel transfer');

    my $transfer_rs = $schema->resultset('Public::ChannelTransfer')->search({
        product_id => $product->id,
        from_channel_id => $source_channel->id,
        to_channel_id => $dest_channel->id,
    });

    my @old_ids = $transfer_rs->get_column('id')->all;

    note sprintf 'Going to transfer PID %d from %s to %s',
        $product->id,$source_channel->name,$dest_channel->name;

    my $transfer;
    if ($args->{transfer}){
        $transfer = $args->{transfer};
    } else {
        my $jq_task = XT::JQ::DC::Receive::Product::ChannelTransfer->new({
            schema => $schema,
            payload => {
                source_channel => $source_channel->id,
                dest_channel => $dest_channel->id,
                currency => '', # unused,
                operator_id => $APPLICATION_OPERATOR_ID,
                products => [ {
                    product => $product->id,
                    price => 0, # unused,
                    # navigation => {} # not necessary
                } ],
            },
        });
        lives_ok { $jq_task->do_the_task() } 'channel transfer initiated';
        is( $product->get_product_channel->channel_id,
            $source_channel->id,
            'DBIC get_product_channel returns correct channel_id after initiating transfer' );

        my @new_transfers = $transfer_rs->search({
            id => { -not_in => \@old_ids }
        })->all;

        is(scalar(@new_transfers),1,'one channel_transfer created');
        $transfer = $new_transfers[0];
    }

    test_prefix( $Test::More::Prefix::prefix || 'Test'  . ': Select channel transfer');

    # Login with the permissions we need. We'll perform a login at the end of
    # this to login with the right permissions again...
    $framework->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__MANAGER => [
            'Stock Control/Inventory',
            'Stock Control/Channel Transfer',
            @{ $args->{'extra_permissions'} || []}
        ]},
        dept => 'Stock Control'
    });

    $framework->flow_mech__stockcontrol__channel_transfer();

    # You will get a failure if you pass this key *without* a value for 'expect_error'
    if ($args->{double_submit}){
        my $framework2 = Test::XT::Flow->new_with_traits(
                traits => [
                'Test::XT::Flow::StockControl',
            ],
        );
        $framework2->login_with_permissions({
            perms => { $AUTHORISATION_LEVEL__MANAGER => [
                'Stock Control/Channel Transfer',
            ]},
            dept => 'Stock Control'
        });
        $framework2->flow_mech__stockcontrol__channel_transfer();
        $framework2->flow_mech__stockcontrol__channel_transfer__select($transfer->id);
    }

    if ($args->{expect_error}){
        my $xt_to_stocksys = $args->{sent_monitor}
                          // Test::XTracker::Artifacts::RAVNI->new("xt_to_${cfg}");
        $framework->catch_error(
            $args->{expect_error},
            "Expect to fail channel transfer with: '$args->{expect_error}'",
            flow_mech__stockcontrol__channel_transfer__select => [$transfer->id]
        );
        my $new_messages =()= $xt_to_stocksys->new_files();
        is ($new_messages, 0, 'no new messages sent as transfer failed');
        # no point carrying on this test, but will need to reuse transfer_id.
        return $transfer;
    }

    my $xt_to_stocksys = $args->{sent_monitor}
                      // Test::XTracker::Artifacts::RAVNI->new("xt_to_${cfg}");
    my $stock_topic = Test::XTracker::Artifacts::RAVNI->new('stock_topic');
    $framework->flow_mech__stockcontrol__channel_transfer__select($transfer->id);

    test_prefix( $Test::More::Prefix::prefix || 'Test'  . ': Check');

    my $printed_stuff =()= $print_monitor->new_files();
    is($printed_stuff,0,'nothing printed, we are using IWS/PRL');

    $args->{'transfer'} = $transfer;
    $args->{'xt_to_stocksys'} = $xt_to_stocksys;
    $args->{'stocksys_to_xt'} = $stocksys_to_xt;
    if ( $args->{prl_loc} ) {
        $framework->_prl_channel_transfer_check($args);
        return $transfer if $args->{stop_after_selection};
    }
    else {
        $framework->_iws_channel_transfer_check($args);
        return $transfer if $args->{stop_after_selection};
        $framework->_iws_channel_transfer_fake_messages($args);
    }

    $transfer->discard_changes;
    $product->discard_changes;

    is($transfer->status_id,
       $CHANNEL_TRANSFER_STATUS__COMPLETE,
       'transfer completed');

    is( $product->get_product_channel->channel_id,
        $dest_channel->id,
        'DBIC get_product_channel returns correct channel_id after transfer' );

    is($quantity_rs->search({channel_id => $source_channel->id})
           ->get_column('quantity')->sum(),
       undef,
       'no stock in old channel');

    is($quantity_rs->search({channel_id => $dest_channel->id})
           ->get_column('quantity')->sum(),
       $initial_quantity,
       'all stock in new channel');

    my (@stock_updates) = $stock_topic->expect_messages({
        messages => [
            ({ type => 'DetailedStockLevelChange' }) x 2,
        ]
    });

    my @from_stock = grep
        { $_->payload_parsed->{channel_id} == $source_channel->id }
            @stock_updates;
    my @to_stock = grep
        { $_->payload_parsed->{channel_id} == $dest_channel->id }
            @stock_updates;

    cmp_deeply(
        [ map { $_->payload_parsed->{product_id} } @from_stock ],
        [ $product->id ],
       '(from) PID correct');
    cmp_deeply(
        [ map { $_->payload_parsed->{product_id} } @to_stock ],
        [ $product->id ],
       '(to) PID correct');
    return $transfer;
}


sub _iws_channel_transfer_check {
    my ( $framework, $args ) = @_;

    my ( $xt_to_stocksys, $product, $transfer, $dest_channel, $source_channel ) =
        map { $args->{$_} } qw{ xt_to_stocksys product transfer channel_to channel_from};

    my ($stock_change) = $xt_to_stocksys->expect_messages({
        messages => [ { type => 'stock_change' } ]
    });

    ok(defined($stock_change),'stock_change message sent');
    is($stock_change->payload_parsed->{what}{pid},
       $product->id,
       'PID correct');
    is($stock_change->payload_parsed->{from}{stock_status},
       'main',
       'from status correct');
    is($stock_change->payload_parsed->{from}{channel},
       $source_channel->name,
       'from channel correct');
    is($stock_change->payload_parsed->{to}{stock_status},
       'main',
       'to status correct');
    is($stock_change->payload_parsed->{to}{channel},
       $dest_channel->name,
       'to channel correct');

    $transfer->discard_changes;
    $product->discard_changes;

    # make sure the transfer hasn't actually happened yet
    is( $product->get_product_channel->channel_id,
        $source_channel->id,
        'DBIC get_product_channel returns correct channel_id after selecting transfer' );

    # transfer should stay in SELECTED until we receive stock_changed
    is($transfer->status_id,
       $CHANNEL_TRANSFER_STATUS__SELECTED,
       'transfer selected');
}


sub _iws_channel_transfer_fake_messages {
    my ( $framework, $args ) = @_;

    # Fake the message from IWS saying it's been done
    $framework->flow_wms__send_stock_changed($args->{transfer}->id);

    my ($stock_changed) = $args->{stocksys_to_xt}->expect_messages({
        messages => [ { type => 'stock_changed' } ]
    });
    ok(defined($stock_changed),'stock_changed message sent');
}


sub _prl_channel_transfer_check {
    my ( $framework, $args ) = @_;

    $framework->check_sku_updates_for_product( $args->{product}, $args->{xt_to_stocksys} );
}


=head2 flow_task__stock_control__channel_transfer_phase_0

 ->flow_task__strock_control__channel_transfer_phase_0({
   product      => Product-Row, [required]
   channel_from => Channel-Row, [required]
   channel_to   => Channel-Row, [required]
   transfer     => Channel Transfer object, [optional - we'll make one for you]

   # Not all channel transfers are expected to pass. If this one is meant to
   # fail, you can specify a regex here of how it's expected to fail.
   # IMPORTANT!!!!!! This will return the transfer that failed. If you're going
   # to retry it, you should hold on to that so you can re-use it later.
   expect_error => qr/Some error message/, [optional]

   schema       => Schema,    [optional - we'll pick one for you]
 })

Performs a manual, non-IWS Channel Transfer of one product to another.

B<WARNING!!!!! DANGER!!!!> This will log your user in as:

    {
        perms => { $AUTHORISATION_LEVEL__MANAGER => [
            'Stock Control/Inventory',
            'Stock Control/Channel Transfer',
        ]},
        dept => 'Stock Control'
    }

You'll need to fix that afterwards if that doesn't work for you. You can set
C<extra_permissions> for other stuff to throw in the Manager Auth.

=cut

sub flow_task__stock_control__channel_transfer_phase_0 {
    my ( $framework, $args ) = @_;

    my $schema = $args->{'schema'} || Test::XTracker::Data->get_schema();

    my $product             = $args->{'product'}      || croak "You need to specify a product";
    my $source_channel      = $args->{'channel_from'} || croak "You need to specify a channel_from";
    my $dest_channel        = $args->{'channel_to'}   || croak "You need to specify a channel_to";
    my $src_location_name   = $args->{'src_location'} || croak "You need to specify a src_location";
    my $dst_location_name   = $args->{'dst_location'} || croak "You need to specify a dst_location";

    my $src_location = $schema->resultset('Public::Location')->get_location({'location'=>$src_location_name});
    my $dst_location = $schema->resultset('Public::Location')->get_location({'location'=>$dst_location_name});

    my $xt_to_wms = $args->{'sent_monitor'} || Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
    my $stock_topic = Test::XTracker::Artifacts::RAVNI->new('stock_topic');

    my $print_monitor = Test::XTracker::PrintDocs->new();

    # We only transfer products that are already live on the source channel
    $product->search_related('product_channel',
        { channel_id => $source_channel->id, },
    )->update({ live => 1, visible => 0 });
    is( $product->get_product_channel->channel_id,
        $source_channel->id,
        'DBIC get_product_channel returns correct channel_id before transfer' );
    $product->get_product_channel->update({visible=>0});
    my @variants = $schema->resultset('Public::Variant')
        ->search({
            product_id => $product->id,
        })->all;

    for my $variant (@variants) {
        $variant->discard_changes();
        note 'Update or create variant '.$variant->id;
        $schema->resultset('Public::Quantity')
            ->update_or_create({
                status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                location_id => $src_location->id,
                variant_id => $variant->id,
                channel_id => $source_channel->id,
                quantity => 100,
            });
    }

    my $quantity_rs = $schema->resultset('Public::Quantity')
        ->search({
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            variant_id => { -in => [ map { $_->id} @variants ] },
        });
    my $src_quantity_rs = $quantity_rs->search({ location_id => $src_location->id });
    my $dst_quantity_rs = $quantity_rs->search({ location_id => $dst_location->id });

    my $initial_quantity = $src_quantity_rs->search({channel_id => $source_channel->id})
        ->get_column('quantity')->sum();

    test_prefix( $Test::More::Prefix::prefix || 'Test'  . ': Initiate channel transfer');

    my $transfer_rs = $schema->resultset('Public::ChannelTransfer')->search({
        product_id => $product->id,
        from_channel_id => $source_channel->id,
        to_channel_id => $dest_channel->id,
    });

    my @old_ids = $transfer_rs->get_column('id')->all;

    note sprintf 'Going to transfer PID %d from %s to %s',
        $product->id,$source_channel->name,$dest_channel->name;

    my $transfer;
    if ($args->{transfer}){
        $transfer = $args->{transfer};
    } else {
        my $jq_task = XT::JQ::DC::Receive::Product::ChannelTransfer->new({
            schema => $schema,
            payload => {
                source_channel => $source_channel->id,
                dest_channel => $dest_channel->id,
                currency => '', # unused,
                operator_id => $APPLICATION_OPERATOR_ID,
                products => [ {
                    product => $product->id,
                    price => 0, # unused,
                    # navigation => {} # not necessary
                } ],
            },
        });
        lives_ok { $jq_task->do_the_task() } 'channel transfer initiated';
        is( $product->get_product_channel->channel_id,
            $source_channel->id,
            'DBIC get_product_channel returns correct channel_id after initiating transfer' );

        my @new_transfers = $transfer_rs->search({
            id => { -not_in => \@old_ids }
        })->all;

        is(scalar(@new_transfers),1,'one channel_transfer created');
        $transfer = $new_transfers[0];
    }

    test_prefix( $Test::More::Prefix::prefix || 'Test'  . ': Select channel transfer');

    # Login with the permissions we need. We'll perform a login at the end of
    # this to login with the right permissions again...
    $framework->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__MANAGER => [
            'Stock Control/Inventory',
            'Stock Control/Channel Transfer',
            @{ $args->{'extra_permissions'} || []}
        ]},
        dept => 'Stock Control'
    });

    $framework->flow_mech__stockcontrol__channel_transfer();

    if ($args->{expect_error}){
        $framework->catch_error(
            $args->{expect_error},
            "Expect to fail channel transfer",
            flow_mech__stockcontrol__channel_transfer__select => [$transfer->id]
        );
        my $new_messages =()= $xt_to_wms->new_files();
        is ($new_messages, 0, 'no new messages sent as transfer failed');
        # no point carrying on this test, but will need to reuse transfer_id.
        return $transfer;
    } else {
        $framework->flow_mech__stockcontrol__channel_transfer__select($transfer->id);
    }

    test_prefix( $Test::More::Prefix::prefix || 'Test'  . ': Check');

    my (@printed_files) = $print_monitor->new_files();
    is(scalar @printed_files, 1, 'correct number of files printed');
    is ($printed_files[0]->{file_type}, 'channeltransfer', 'channel transfer document printed');
    my $printer_info = XTracker::PrintFunctions::get_printer_by_name( 'Channel Transfer' );
    is ($printed_files[0]->{printer_name}, $printer_info->{lp_name}, 'document printed to correct queue');

    $transfer->discard_changes;
    $product->discard_changes;

    # make sure the transfer hasn't actually happened yet
    is( $product->get_product_channel->channel_id,
        $source_channel->id,
        'DBIC get_product_channel returns correct channel_id after selecting transfer' );

    # transfer should stay in SELECTED until we receive stock_changed
    is($transfer->status_id,
       $CHANNEL_TRANSFER_STATUS__SELECTED,
       'transfer selected');


    # So, er, now we should do something, not sure what the process is though...

    $framework->flow_mech__stockcontrol__channel_transfer_picking();
    $framework->flow_mech__stockcontrol__channel_transfer_picking_submit($transfer->id);
    foreach my $variant (@variants) {
        my $sku      = $variant->sku;
        $framework->flow_mech__stockcontrol__channel_transfer_picking_submit_location( $src_location->location );
        $framework->flow_mech__stockcontrol__channel_transfer_picking_submit_sku( $sku );
        $framework->flow_mech__stockcontrol__channel_transfer_picking_submit_quantity( 100 );
    }
    $framework->flow_mech__stockcontrol__channel_transfer_complete_pick();


    $framework->flow_mech__stockcontrol__channel_transfer_putaway();
    $framework->flow_mech__stockcontrol__channel_transfer_putaway_submit($transfer->id);
    foreach my $variant (@variants) {
        my $sku      = $variant->sku;
        $framework->flow_mech__stockcontrol__channel_transfer_putaway_submit_location( $dst_location->location );
    }
    $framework->flow_mech__stockcontrol__channel_transfer_complete_putaway();


    $transfer->discard_changes;
    $product->discard_changes;

    is($transfer->status_id,
       $CHANNEL_TRANSFER_STATUS__COMPLETE,
       'transfer completed');

    is( $product->get_product_channel->channel_id,
        $dest_channel->id,
        'DBIC get_product_channel returns correct channel_id after transfer' );

    is($src_quantity_rs->search({channel_id => $source_channel->id})
           ->get_column('quantity')->sum(),
       undef,
       'no stock in old channel');
    is($dst_quantity_rs->search({channel_id => $dest_channel->id})
           ->get_column('quantity')->sum(),
       $initial_quantity,
       'all stock in new channel');

    my (@stock_updates) = $stock_topic->expect_messages({
        messages => [
            ({ type => 'DetailedStockLevelChange' }) x 2,
        ]
    });

    my @from_stock = grep
        { $_->payload_parsed->{channel_id} == $source_channel->id }
            @stock_updates;
    my @to_stock = grep
        { $_->payload_parsed->{channel_id} == $dest_channel->id }
            @stock_updates;

    cmp_deeply(
        [ map { $_->payload_parsed->{product_id} } @from_stock ],
        [ $product->id ],
       '(from) PID correct');
    cmp_deeply(
        [ map { $_->payload_parsed->{product_id} } @to_stock ],
        [ $product->id ],
       '(to) PID correct');

   return $transfer;
}


1;

# WIP
