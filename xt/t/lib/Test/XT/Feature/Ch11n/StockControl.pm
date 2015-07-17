package Test::XT::Feature::Ch11n::StockControl;
use NAP::policy "tt", qw( test role );


sub test_mech__stockcontrol__location_ch11n {
    my($self) = @_;

    $self->announce_method;

    $self->mech_select_box_ch11n({ name => 'frm_sales_channel' });
    return $self;
}

sub test_mech__stockcontrol__location_create_ch11n {
    my($self) = @_;

    $self->announce_method;

    $self->mech_select_box_ch11n({ name => 'frm_sales_channel', no_all => 1 });
#    $self->ok_channel_select_box('frm_sales_channel',
#        { no_all => 1 });
    return $self;
}



# URI: /StockControl/PurchaseOrder
#   Test the Stock Control Purchase Order page
#
sub test_mech__stockcontrol__purchaseorder_ch11n {
    my ($self) = @_;

    $self->announce_method;

    like($self->mech->uri, qr{/StockControl/PurchaseOrder}, 'Stock control - purchase order page');
    # It it channelised correctly
    return $self
        ->mech_select_box_ch11n
    ;
}


# URI: /StockControl/PurchaseOrder
#   Test the Stock Control Purchase Order page after a submit
#
sub test_mech__stockcontrol__purchaseorder_submit_ch11n {
    my ($self) = @_;

    $self->announce_method;

    like($self->mech->uri, qr{/StockControl/PurchaseOrder}, 'Stock control - purchase order page');
    # The page should have been submitted, and show the PO in the list
    my $open_plus = $self->mech->look_down('id', "open_".$self->purchase_order->id);
    isnt($open_plus, undef, 'PO found in list');

    # Ensure that the channel name appears on the list with the correct colour
    my $title_class = "title-".$self->channel->business->config_section;
    my $search_results = $self->mech->look_down('class', $title_class);
    isnt($search_results, undef, 'Channel appears in the list');

    return $self;
}


# URI: /StockControl/PurchaseOrder/Overview?po_id=123
#   Test the Stock Control Purchase Order page
#
sub test_mech__stockcontrol__purchaseorder_overview_ch11n {
    my ($self) = @_;

    $self->announce_method;

    like($self->mech->uri, qr{/StockControl/PurchaseOrder/Overview}, 'Stock control - purchase order overview page');
    # It it channelised correctly
    return $self
        ->mech_logo_ch11n
        ->mech_title_ch11n(['Purchase Order Details', 'Stock Orders'])
        ;
}


# URI: /StockControl/PurchaseOrder/Confirm?po_id=123
#   Test the Stock Control Purchase Order Confirm page
#
sub test_mech__stockcontrol__purchaseorder_confirm_ch11n {
    my ($self) = @_;

    $self->announce_method;

    SKIP: {
        skip "Edit PO features are disabled for this PO",1 unless $self->purchase_order->is_editable_in_xt;

        like($self->mech->uri, qr{/StockControl/PurchaseOrder/Confirm}, 'Stock control - purchase order confirm page');
        # It it channelised correctly
        return $self
            ->mech_logo_ch11n
            ->mech_title_ch11n(['Purchase Order Details','Payment Terms','Shipping Window','Stock Orders','Confirm Purchase Order'])
            ;

    }
    return $self;
}


# URI: /StockControl/PurchaseOrder/Edit?po_id=123
#   Test the Stock Control Purchase Order Edit page
#
sub test_mech__stockcontrol__purchaseorder_edit_ch11n {
    my ($self) = @_;

    $self->announce_method;

    SKIP: {
        skip "Edit PO features are disabled for this PO",2 unless $self->purchase_order->is_editable_in_xt;

        like($self->mech->uri, qr{/StockControl/PurchaseOrder/Edit}, 'Stock control - purchase order edit page');
        # It it channelised correctly
        $self->mech_logo_ch11n;

        my $title_class     = "title title-".$self->channel->business->config_section;
        my $search_results  = $self->mech->look_down('class', $title_class);
        isnt($search_results, undef, 'Purchase order details in the correct colour');
    }
    return $self;
}


# URI: /StockControl/PurchaseOrder/Reorder?po_id=123
#   Test the Stock Control Purchase Order Reorder page
#
sub test_mech__stockcontrol__purchaseorder_reorder_ch11n {
    my ($self) = @_;

    $self->announce_method;

    SKIP: {
        skip "Edit PO features are disabled for this PO",2 unless $self->purchase_order->is_editable_in_xt;

        like($self->mech->uri, qr{/StockControl/PurchaseOrder/ReOrder}, 'Stock control - purchase order reorder page');

        # It it channelised correctly
        return $self
            ->mech_logo_ch11n
            ->mech_title_ch11n(['Purchase Order Information','Stock Orders'])
            ;
    }
    return $self;
}

# URI: /StockControl/PurchaseOrder/Reorder?po_id=123
#   Test the Stock Control Purchase Order Reorder Submit action
#
sub test_mech__stockcontrol__purchaseorder_reorder_submit_ch11n {
    my ($self) = @_;

    $self->announce_method;

    SKIP: {
        my $schema  = Test::XTracker::Data->get_schema;

        skip "Edit PO features are disabled for this PO",2 unless $self->purchase_order->is_editable_in_xt;
        my $poid        = $self->mech->look_down('name', 'purchase_order_id');
        my $new_po_id   = $poid->attr('value');
        my $new_purchase_order = $schema->resultset('Public::PurchaseOrder')->find($new_po_id);


        like($self->mech->uri, qr{/StockControl/PurchaseOrder/Overview}, 'Stock control - purchase order reorder page');

        # Check that the new purchase order is on the correct channel etc.

        is($new_purchase_order->channel_id, $self->channel->id, "New order on correct channel");
    }
    return $self;
}

# URI: /StockControl/PurchaseOrder/StockOrder?so_id=123
#   Test the Stock Control Purchase Order Stock Order page
#
sub test_mech__stockcontrol__purchaseorder_stockorder_ch11n {
    my ($self) = @_;

    $self->announce_method;

    like($self->mech->uri, qr{/StockControl/PurchaseOrder/StockOrder}, 'Stock Control - Purchase Order - Stock Order page.');

    # It it channelised correctly
    my $business_name = $self->channel->business->name;

    return $self
        ->mech_logo_ch11n
        ->mech_title_ch11n(['Stock Order Details','Stock Order Items',$business_name])
        ;
}

sub test_mech__stockcontrol__inventory_overview_variant_ch11n {
    my($self) = @_;

    $self->announce_method;

    $self->mech_title_ch11n([
        'Stock Overview - Main Stock',
        $self->mech->channel->name,
    ]);
    $self->mech_tab_ch11n;


    return $self;
}

sub test_mech__stockcontrol__inventory_productdetails_ch11n {
    my($self) = @_;

    $self->announce_method;

    my $business_name = $self->channel->business->name;

    $self->mech_title_ch11n([$business_name]);

    return $self;
}

sub test_mech__stockcontrol__inventory_pricing_ch11n {
    my($self) = @_;

    $self->announce_method;

    my $business_name = $self->channel->business->name;

    $self->mech_title_ch11n([$business_name]);

    return $self;
}

sub test_mech__stockcontrol__inventory_sizing_ch11n {
    my($self) = @_;

    $self->announce_method;

    my $business_name = $self->channel->business->name;

    $self->mech_title_ch11n([$business_name]);

    return $self;
}

sub test_mech__stockcontrol__location_submit_ch11n {
    my($self) = @_;

    $self->announce_method;

    my $business_name = $self->channel->business->name;
    $self->mech_title_ch11n([$business_name],1);

    return $self;
}

sub test_mech__stockcontrol__measurement_submit_ch11n {
    my($self) = @_;

    $self->announce_method;

    my $business_name = $self->channel->business->name;
    $self->mech_title_ch11n([$business_name,'Edit Measurements',
        'Size Chart Preview']);

    # check that all the fields on the page are Editable
    my $pg_data = $self->mech->as_data()->{measurements};
    my $read_only_field_counter = 0;
    foreach my $row ( @{ $pg_data } ) {
        $read_only_field_counter++      if ( grep { ref( $_ ) && $_->{input_readonly} } values %{ $row } );
    }
    cmp_ok( $read_only_field_counter, '==', 0, "All fields on the Page are Editable" );

    return $self;
}

sub test_mech__stockcontrol__stockcheck_submit_ch11n {
    my($self) = @_;

    $self->announce_method;

    # Check the channel is displayed correctly for this row.
    # We want to check the span in the td following the one that contains
    # this product id, because that's where the channel is shown.
    my $product_id = $self->stock_order->stock_order_items->first->variant->product_id;
    my $channel_name_span = $self->mech->find_xpath(
        "//td[.=~'$product_id']/following-sibling::td/child::span"
        )->pop;

    $self->mech_row_item_ch11n({
        'element'=>$channel_name_span,
        'channel'=>$self->channel,
    });

    return $self;
}

sub test_mech__stockcontrol__inventory_stockadjustment_variant_ch11n {
    my($self) = @_;

    $self->announce_method;

    my $business_name = $self->channel->business->name;
    $self->mech_title_ch11n([$business_name]);
    $self->mech_tab_ch11n;

    return $self;
}

sub test_mech__stockcontrol__inventory_log_product_deliverylog_ch11n {
    my($self) = @_;

    $self->announce_method;

    $self->mech_somewhere_td_span_ch11n();
    my $business_name = $self->channel->business->name;
    $self->mech_title_ch11n([$business_name,"Delivery Log"]);
    $self->mech_tab_ch11n;

    return $self;
}

sub test_mech__stockcontrol__inventory_log_product_allocatedlog_ch11n {
    my($self) = @_;

    $self->announce_method;

    $self->mech_somewhere_td_span_ch11n();
    my $business_name = $self->channel->business->name;
    $self->mech_title_ch11n([$business_name,"Allocated Log"]);
    $self->mech_tab_ch11n;

    return $self;
}

sub test_mech__stockcontrol__stockcheck_product_submit_ch11n {
    my($self) = @_;

    $self->announce_method;

    # Check the channel is displayed correctly for this row.
    # We want to check the span in the td following the one that contains
    # this product id, because that's where the channel is shown.
    my $product_id = $self->stock_order->stock_order_items->first->variant->product_id;
    my $channel_name_span = $self->mech->find_xpath(
        "//td[.=~'$product_id']/following-sibling::td/child::span"
        )->pop;

    $self->mech_row_item_ch11n({
        'element'=>$channel_name_span,
        'channel'=>$self->channel,
    });

    return $self;
}

sub test_mech__stockcontrol__inventory_log_variant_transactionlog_ch11n {
    my($self) = @_;

    $self->announce_method;

    $self->mech_somewhere_td_span_ch11n();
    my $business_name = $self->channel->business->name;
    $self->mech_title_ch11n([$business_name,"Transaction Log"]);
    $self->mech_tab_ch11n;

    return $self;
}

sub test_mech__stockcontrol__inventory_log_variant_rtvlog_ch11n {
    my($self) = @_;

    $self->announce_method;

    $self->mech_somewhere_td_span_ch11n();
    my $business_name = $self->channel->business->name;
    $self->mech_title_ch11n([$business_name,"RTV Log"]);

    $self->mech_tab_ch11n;

    return $self;
}

sub test_mech__stockcontrol__inventory_log_variant_pwslog_ch11n {
    my($self) = @_;

    $self->announce_method;

    $self->mech_somewhere_td_span_ch11n();
    my $business_name = $self->channel->business->name;
    $self->mech_title_ch11n([$business_name,"PWS Log"]);

    $self->mech_tab_ch11n;

    return $self;
}

sub test_mech__stockcontrol__inventory_log_variant_locationlog_ch11n {
    my($self) = @_;

    $self->announce_method;

    $self->mech_somewhere_td_span_ch11n();
    my $business_name = $self->channel->business->name;
    $self->mech_title_ch11n([$business_name,"Location Log"]);
    $self->mech_tab_ch11n;

    return $self;
}

sub test_mech__stockcontrol__final_pick_ch11n {
    my($self) = @_;

    $self->announce_method;

    $self->mech_title_ch11n(["Empty Locations"]);
    $self->mech_tab_ch11n;

    return $self;
}

sub test_mech__stockcontrol__inventory_stockquarantine {
    my($self) = @_;

    $self->announce_method;
    my $business_name = $self->channel->business->name;

    $self->mech_title_ch11n([$business_name,"Quarantine Stock"]);
    $self->mech_tab_ch11n;

    return $self;
}

sub test_mech__stockcontrol__dead_stock_add_item{
    my ($self) = @_;
    $self->announce_method;

    return $self;
}

sub test_mech__stockcontrol__dead_stock_view_list{
    my ($self) = @_;
    $self->announce_method;

    #$self->mech_tab_ch11n;
    return $self;
}

sub test_mech__stockcontrol__dead_stock_update{
    my ($self) = @_;
    $self->announce_method;

    return $self;
}


1;

# WIP
