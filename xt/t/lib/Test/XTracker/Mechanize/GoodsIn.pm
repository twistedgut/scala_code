package Test::XTracker::Mechanize::GoodsIn;

use NAP::policy "tt", qw( test class);
use XTracker::Constants::FromDB qw(
    :channel
    :putaway_type
);
use Test::XTracker::Data;
use XTracker::Constants::FromDB qw(
    :channel
    :stock_process_type
    :stock_process_status
    :authorisation_level
);
use XTracker::PrintFunctions;


use Log::Log4perl ':easy';
use Data::Dump 'pp';


extends 'Test::XTracker::Mechanize', 'Test::XTracker::Data';

with 'WWW::Mechanize::TreeBuilder' => {
    tree_class => 'HTML::TreeBuilder::XPath'
};

sub login_as_department {
    my ($self, $department) = @_;

    Test::XTracker::Data->set_department( 'it.god', $department );

    $self->do_login;
}

sub title_class {
    my($self,$channel) = @_;
    return "title-".$channel->business->config_section;
}

sub tab_class {
    my($self,$channel) = @_;
    #return $class_name = "contentTab-". $channel->business->config_section;
    return "contentTab-". $channel->business->config_section;
}

sub test_tab {
    my($self,$channel) = @_;
    note "sub test_tab";

    my $class_name = $self->tab_class($channel);
    my @titles  = $self->look_down('class', $class_name);
    is(scalar @titles, 1, "found tab for '$class_name'") or diag $self->uri;
    return $self;
}

# same page the Purchase Order > Search ( /StockControl/PurchaseOrder ) result
# links through to
sub test_overview {
    my ($self,$po) = @_;

    note 'sub test_overview';
    $self->get_ok('/StockControl/PurchaseOrder/Overview?po_id='. $po->id);

    # It it channelised with the correct logo
    $self->ok_logo_channelisation($po->channel);
    $self->ok_title_channelisation($po->channel, ['Purchase Order Details', 'Stock Orders']);
    return $self;
}

sub test_packing_slip {
    my($self,$po) = @_;

    note 'sub test_packing_slip';
    my $stockorder = $po->stock_orders->first;
    my $soid = $stockorder->id;
    $self->get_ok('/GoodsIn/StockIn/PackingSlip?so_id='. $soid);
    note $soid ." - ". $self->uri;

    # It it channelised with the correct logo
    $self->ok_logo_channelisation($po->channel);

    # check there's a link to the PO
    my $link = $self->look_down(
        'href', '/StockControl/PurchaseOrder/Overview?po_id='.$po->id);
    isnt($link, undef, 'link to PO overview');

    my $chname = $po->channel->name;
    $self->ok_title_channelisation($po->channel, ['Enter Packing Slip Values', $chname]);

    # submit stuff and test the stock sheet
    $self->test_stock_sheet($stockorder);
    return $self;
}

sub test_stock_sheet {
    my($self,$so) = @_;

    note 'sub test_stock_sheet';
    my $form = { };
    my $items = $so->stock_order_items;

    while (my $item = $items->next) {
        $form->{ 'count_'. $item->id } = $item->quantity;
    }

    $self->submit_form_ok({
        with_fields => $form,
        button => 'submit',
    }, 'provide packing slip values');

    # FIXME: delivery should be created now.. how do I find it
    $so->discard_changes;
    my $delivery = $so->deliveries->first;

    my $file = XTracker::PrintFunctions::path_for_print_document({
        document_type => 'delivery',
        id => $delivery->id,
        extension => 'html',
    });
    note "Printed.. $file";

    my $name    = $so->purchase_order->channel->name;
    my $found   = $self->find_text_in_file($file, $name);

    is($found, 1, 'found mention of channel');
    return $self;
}

sub test_item_count {
    my($self,$po) = @_;

    note 'sub test_item_count';
    $self->get_ok('/GoodsIn/ItemCount');

    # Ensure the tab is set up with the correct CSS
    $self->ok_tab_channelisation($po->channel);

    $self->test_item_count_result($po);
    return $self;
}

sub test_item_count_result {
    my($self,$po) = @_;
    note "sub test_item_count_result";

    my $delivery = $po->stock_orders->first->deliveries->first;

    my $form = {
        delivery_id => $delivery->id,
    };

    $self->submit_form_ok({
        with_fields => $form,
        button => 'submit',
    }, 'enter delivery id');

    # It it channelised with the correct logo
    $self->ok_logo_channelisation($po->channel);

    my $chname = $po->channel->name;
    $self->ok_title_channelisation(
        $po->channel,
        ['Product Information', 'Unit Count', $chname]
    );

    # enter values as unit counts
    my $stockorder = $po->stock_orders->first;
    $form = { };
    my $items = $stockorder->stock_order_items;
    my $ditems = $delivery->delivery_items;
    while (my $item = $items->next) {
        my $ditem = $ditems->next;
        $form->{ 'count_'. $ditem->id } = $item->quantity;
    }

    $self->submit_form_ok({
        with_fields => $form,
        button      => 'submit',
    }, 'enter item counts');
    return $self;
}

sub test_surplus {
    my($self,$po) = @_;

    note 'sub test_surplus';
    $self->get_ok('/GoodsIn/Surplus');

    # Ensure the tab is set up with the correct CSS
    $self->ok_tab_channelisation($po->channel);
    return $self;
}

sub test_quality_control_list {
    my($self,$po) = @_;

    note 'sub test_quality_control_list';
    my $delivery        = $po->stock_orders->first->deliveries->first;
    my $delivery_id     = $delivery->id;

    $self->get_ok('/GoodsIn/QualityControl');

    # Ensure the tab is set up with the correct CSS
    note $self->uri;
    $self->ok_tab_channelisation($po->channel);

    # Ensure that the delivery appears in a link
    #  <a href="/GoodsIn/QualityControl?delivery_id=551219">551219</a>
    my @links = $self->look_down('href', "/GoodsIn/QualityControl?delivery_id=$delivery_id");
    is(scalar @links, 1, "found link for delivery $delivery_id");

    $self->submit_form_ok({
        with_fields => {
            delivery_id => $delivery_id,
        },
    }, "Submitting a delivery ID");

    like($self->uri, qr{GoodsIn/QualityControl}, 'Correct URI');
    return $self;
}

sub test_release_hold {
    my ($self, $po, $auth) = @_;

    note 'sub test_release_hold';

    my $schema = Test::XTracker::Data->get_schema;

    my $delivery    = $po->stock_orders->first->deliveries->first;
    my $delivery_id = $delivery->id;

    $self->get_ok('/GoodsIn/DeliveryHold');
    like($self->uri, qr{/GoodsIn/DeliveryHold}, 'Delivery Hold URI');
    my $checkbox = $self->look_down('name', "release_$delivery_id");

    if ($auth == $AUTHORISATION_LEVEL__MANAGER) {
        # Only a Manager should see a 'release' checkbox
        isnt($checkbox, undef, 'Checkbox is present');

        # Ensure we can unhold it
        $self->submit_form_ok({
            with_fields => {"release_$delivery_id"  => 1},
            button => 'submit',
        }, 'Submit Release');

        $delivery->discard_changes;
        is($delivery->on_hold, 0, 'Delivery has been taken off hold');
    }
    else {
        # Everyone else should not see a 'release' checkbox
        is($checkbox, undef, 'Checkbox is not present');
    }
}

sub test_fast_track {
    my ($self, $po) = @_;

    note 'sub test_fast_track';
    my $schema = Test::XTracker::Data->get_schema;

    my $delivery    = $po->stock_orders->first->deliveries->first;
    my $delivery_id = $delivery->id;

    $self->get_ok('/GoodsIn/QualityControl/FastTrack?delivery_id='.$delivery->id);

    # It it channelised with the correct logo
    $self->ok_logo_channelisation($po->channel);

    $self->ok_title_channelisation($po->channel, ['Select Size', $po->channel->name]);
    # Get the stock_process_ids
    my @stock_processes = map {$_->stock_processes->first } $delivery->delivery_items;

    my $form_hash;
    for my $stock_process (@stock_processes) {
        $form_hash->{"counted_".$stock_process->id} = 2;
    }

    # Submit the form
    $self->submit_form_ok({
        with_fields => $form_hash,
        button => 'submit',
    }, 'Submit QC results');

    note "URI is ".$self->uri;
    # Check that we have been directed to the correct page.
    like($self->uri, qr{/GoodsIn/QualityControl/Book\?delivery_id=$delivery_id}, 'Correct URI');

    # Check that a delivery note has been created correctly channelised
    my $file = XTracker::PrintFunctions::path_for_print_document({
        document_type => 'delivery',
        id => $delivery_id,
        extension => 'html',
    });
    my $name    = $po->channel->name;
    my $found   = $self->find_text_in_file($file, $name);
    is($found, 1, 'found mention of channel');
    return $self;
}

sub test_process_surplus {
    my ($self, $po) = @_;

    note 'sub test_process_surplus';

    my $schema = Test::XTracker::Data->get_schema;

    my $delivery = $po->stock_orders->first->deliveries->first;

    my @delivery_item_ids = map {$_->id} $delivery->delivery_items;

    my $surplus_stock_process = $schema->resultset('Public::StockProcess')->search({
        delivery_item_id    => [@delivery_item_ids],
        type_id             => $STOCK_PROCESS_TYPE__SURPLUS,
    })->first;

    my $group_id = $surplus_stock_process->group_id;

    $self->get_ok("/GoodsIn/Surplus?process_group_id=$group_id");

#    note $self->content;

    # It it channelised with the correct logo
    $self->ok_logo_channelisation($po->channel);

    $self->ok_title_channelisation($po->channel, ['Process Surplus Units']);
    return $self;
}

sub test_quality_control_process_item {
    my ($self, $po) = @_;

    note 'sub test_quality_control_process_item';
    my $schema = Test::XTracker::Data->get_schema;

    my $delivery = $po->stock_orders->first->deliveries->first;

    # It it channelised with the correct logo
    $self->ok_logo_channelisation($po->channel);

    $self->ok_title_channelisation($po->channel, ['Product Information', 'QC Results', 'Measurements', $po->channel->name]);

    # Get the stock_process_ids
    my @stock_processes = map {$_->stock_processes->first } $delivery->delivery_items;

    my $form_hash;
    for my $stock_process (@stock_processes) {
        $form_hash->{"counted_".$stock_process->id} = 2;
    }
    # Submit the form
    $self->submit_form_ok({
        with_fields => $form_hash,
        button => 'submit',
    }, 'submit QC results');

    # Check that the item has been taken out of Quality Control
    $self->get_ok('/GoodsIn/QualityControl?delivery_id='.$delivery->id);

    my ($error_msg) = $self->look_down('class', 'error_msg');
    my ($html) = $error_msg->content_list;

    note "HTML = [$html]";
    is($html, "Delivery ".$delivery->id." is not ready for QC", 'delivery taken out of QC');

    my @delivery_item_ids = map {$_->id} $delivery->delivery_items;

    my $surplus_stock_process = $schema->resultset('Public::StockProcess')->search({
        delivery_item_id    => [@delivery_item_ids],
        type_id             => $STOCK_PROCESS_TYPE__SURPLUS,
    })->first;

    my $main_stock_process = $schema->resultset('Public::StockProcess')->search({
        delivery_item_id    => [@delivery_item_ids],
        type_id             => $STOCK_PROCESS_TYPE__MAIN,
    })->first;

    # Get names of surplus and main files
    my $surplus_file = XTracker::PrintFunctions::path_for_print_document({
        document_type => 'surplus',
        id => $surplus_stock_process->group_id,
        extension => 'html',
    });
    my $main_file = XTracker::PrintFunctions::path_for_print_document({
        document_type => 'main',
        id => $main_stock_process->group_id,
        extension => 'html',
    });

    for my $filename ($surplus_file, $main_file) {
        my $found = $self->find_text_in_file($filename, $po->channel->name);
        is ($found, 1, "Found mention of channel in $filename");
    }
    return $self;
}

sub test_any_surplus {
    my ($self, $po) = @_;

    note 'sub test_any_surplus';
    my $schema = Test::XTracker::Data->get_schema;

    my $delivery = $po->stock_orders->first->deliveries->first;
    if ($delivery) {
        my @delivery_item_ids = map {$_->id} $delivery->delivery_items;

        my $surplus_stock_process = $schema->resultset('Public::StockProcess')->search({
            delivery_item_id    => [@delivery_item_ids],
            type_id             => $STOCK_PROCESS_TYPE__SURPLUS,
        })->first;
        if ($surplus_stock_process) {
            note "Surplus group is ".$surplus_stock_process->group_id;
        }
    }
    return $self;
}

sub test_putaway {
    my($self,$po,$locs) = @_;
    note "sub test_putaway";

    $self->get_ok('/GoodsIn/Putaway');
    note $self->uri;

    $self->test_tab($po->channel);
    $self->test_element_classes({
        expect => 1,
        channel => $po->channel,
        # there should be at least this section - others are possible
        names => [ 'Process Groups Awaiting Putaway', ],
    });

    # foreach delivery item put them away
    my $delivery = $po->stock_orders->first->deliveries->first;
    my $ditems = $delivery->delivery_items;
    my $stock_processes = $ditems->search_related('stock_processes', {
        'me.type_id' => $STOCK_PROCESS_TYPE__MAIN,
    });

    cmp_ok($stock_processes->count,'>=', scalar @{$locs}, 'test_putaway: we have enough locations');

    my $item = $stock_processes->next;
    do {
        note $self->uri;

        $self->no_feedback_error_ok;
        # enter the group id
        note "group_id: ". $item->group_id;
        $self->submit_form_ok({
            with_fields => {
                process_group_id => $item->group_id,
            },
            button => 'submit',
        }, 'submit process_group_id');

#        note $self->content;
        my $loc = shift @{$locs};

        my $form  = {
            "location_". $item->id => $loc,
        };
        note $self->uri;
        note pp($form);

        # enter location
        $self->submit_form_ok({
            with_fields => $form,
            button => 'submit',
        }, 'enter quantity/location putaway');
    } while ($item = $stock_processes->next);
    return $self;
}

sub test_element_classes {
    my($self,$opts) = @_;

    note 'sub test_element_classes';
    my $expect  = $opts->{expect} || undef;
    my $channel = $opts->{channel} || undef;
    my $names   = $opts->{names} || [];
    note "test_element_classes";

    $self->ok_title_channelisation($channel, $names);
    return $self;
}

sub ps_visible_on_item_count {
    my ($self) = @_;

    $self->get_ok('/GoodsIn/ItemCount');
    my $ps_th = $self->find_xpath('//div[@id="tab1"]/div/table/thead/tr[2]/td[7]')->pop();
    return $ps_th->string_value() eq 'PS';
}

sub counts_visible_on_view_delivery {
    my ($self, $delivery_id) = @_;

    $self->get_ok("/GoodsIn/ItemCount?delivery_id=$delivery_id");
    my $ps_th = $self->find_xpath('//div[@id="main_form"]/table[1]/thead/tr[2]/td[5]')->pop();
    return $ps_th && $ps_th->string_value() eq 'Packing Slip'
}

sub submit_item_count {
    my ($self, $count) = @_;

    my $input = $self->find_xpath('//div[@id="main_form"]/table[1]/tbody/tr[1]/td/input')->pop();

    unless( $input ) {
        warn "couldn't find input field to enter item count";
        return;
    }

    $self->submit_form_ok({
        with_fields => { scalar $input->attr_get_i('name') => $count, },
        button => 'submit',
    }, "Submit item count");
    return $self;
}

=head2 submit_item_count_quantity_fails_ok

Submitting the Item Count page with the given $count fails due to mismatched
quantities

=cut

sub submit_item_count_quantity_fails_ok {
    my ( $self, $count ) = @_;
    $self->submit_item_count( $count );
    $self->has_feedback_error_ok( qr{Quantities entered different to those expected},
        'quantity error when submitting item count' );
}

=head2 submit_item_count_ok

Test that mech object does not contain 'Quantities entered different to those
expected' error message.

=cut

sub submit_item_count_ok {
    my ( $self, $count ) = @_;
    $self->submit_item_count( $count );
    $self->has_feedback_success_ok( qr{Item count completed for delivery \d+},
        'item count completed successfully' );
}

=head2 recent_delivery_status_ok

Check that the delivery shows up on the /GoodsIn/RecentDeliveries page with the
given status.

C<$delivery> can be an delivery_id or a Result::Public::Delivery row.

=cut

sub recent_delivery_status_ok {
    my ($self, $delivery, $status) = @_;

    note 'sub recent_delivery_status_ok';

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $delivery = $delivery->id if ref $delivery;

    Test::XTracker::Data->grant_permissions('it.god', 'Goods In', 'Recent Deliveries', 2);
    $self->get_ok( '/GoodsIn/RecentDeliveries' );

    my $last_page_link =$self->find_link( url_regex=> qr{page=}, text=> 'Last' );
    if ($last_page_link) { $self->get_ok($last_page_link->url()) };

    my ( $status_row ) =
        grep { $_->{'Delivery'} == $delivery }
        @{ $self->as_data->{'deliveries'} };

    if ($status_row) {
        is(
            lc $self->_strip_ws($status_row->{'Status'}),
            lc $status,
            "Recent Delivery $delivery has status of '$status'"
        );
    }
    else {
        ok(0, "Could not find delivery $delivery in Recent Delivery list");
        note( "Delivery not found in list" );
    }
}

=head2 putaway_stock_process_ok

Puts away a stock process at the given location with the given quantity. If
you don't pass a quantity count it defaults to passing the whole quantity in
the stock process object. Run this after C<submit_putaway_ok> as it doesn't
call a get_ok.

=cut

sub putaway_stock_process_ok {
    my ( $self, $sp, $location, $channel ) = @_;

    note 'sub putaway_stock_process_ok';
    LOGCONFESS "You must pass a StockProcess object: you passed $sp"

        unless ref $sp eq 'XTracker::Schema::Result::Public::StockProcess';
    LOGCONFESS "You must pass a location object: you passed $location"
        unless ref $location eq 'XTracker::Schema::Result::Public::Location';

    my $schema
        = Test::XTracker::Data->get_schema;
    my $submit_fields = {
        active_channel_id   => $channel,
        channel_config      => 'NAP',
        delivery_channel_id => $channel,
        process_group_id    => $sp->group_id,
        putaway_type        => $PUTAWAY_TYPE__GOODS_IN,
        source              => 'desktop',
        'quantity_'.$sp->id => $sp->quantity,
        'location_'.$sp->id => $location->location,
    };
    $self->submit_form_ok({
        with_fields => $submit_fields,
        button => 'submit',
    }, 'submit putaway for process item ' . $sp->id);
    $self->no_feedback_error_ok;
}

=head2 set_delivery_held_ok

=cut

sub set_delivery_held_ok {
    my ( $self ) = @_;

    $self->get_ok( '/GoodsIn/QualityControl' );
}

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
no Moose;

1;
