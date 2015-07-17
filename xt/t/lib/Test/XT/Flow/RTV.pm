package Test::XT::Flow::RTV;

use NAP::policy "tt",     qw( test role );

#
# Push through the RTV workflow
#
use XTracker::Config::Local;
use Test::XTracker::Data;
use XTracker::Database::RTV qw(insert_rtv_quantity);
use XTracker::Database::StockProcess qw(create_stock_process set_putaway_item);
use Data::Dump qw/pp/;

use XTracker::Constants::FromDB qw(
    :channel
    :business
    :stock_order_status
    :authorisation_level
    :delivery_status
    :stock_process_type
    :stock_process_status
);

sub _rtv_inspection_pick_request_id {
    my($self) = @_;

    my $schema  = Test::XTracker::Data->get_schema;

    my $rtv_quantity = $self->purchase_order->stock_orders->first
        ->public_product
        ->variants
            ->search({},{order_by=>{-asc=>'id'}})->first
        ->rtv_quantities->first
        ;
    note "RTV Quantity = [".$rtv_quantity->id."]";

    my ($rtv_inspection_pick_request_details) =
        $schema->resultset('Public::RTVInspectionPickRequestDetail')->search({
            rtv_quantity_id => $rtv_quantity->id,
        });

    note "rtv_inspection_pick_request_details = [".$rtv_inspection_pick_request_details->id."]";

    my $id = $self->purchase_order->stock_orders->first
        ->public_product
        ->variants
            ->search({},{order_by=>{-asc=>'id'}})->first
        ->rtv_quantities->first
        ->rtv_inspection_pick_request_details->first
        ->rtv_inspection_pick_request_id;

    return "RTVI-$id";
}



############################
# Page workflow methods
############################

# URI: /RTV/FaultyGI
#   get the Inspection Request - Goods In page
#
sub flow_mech__rtv__faultygi {
    my ($self) = @_;

    $self->announce_method;

    $self->mech->get_ok('/RTV/FaultyGI');
    like($self->mech->uri, qr{RTV/FaultyGI}, 'The Faulty GI page');
    return $self;
}

# URI: /RTV/FaultyGI
#   Submit the Request Inspection form
#
sub flow_mech__rtv__faultygi__submit {
    my ($self, $po) = @_;

    $self->announce_method;

    my $stock_order = $self->purchase_order->stock_orders->first;
    my $variant     = $self->product->variants
        ->search({},{order_by=>{-asc=>'id'}})->first;
    my $delivery    = $stock_order->deliveries->first;

    # Ensure there is a checkbox, and click it to create a rtv request print document

    my $checkbox_value = $self->product->id.'_'.$delivery->id;

    note "submit checkbox_value [$checkbox_value]";
    $self->mech->submit_form_ok({
        with_fields => {
            "include_$checkbox_value"   => $checkbox_value,
        },
        button => 'submit_inspection_request',
    }, "Submitting a request inspection");

    isnt($self->mech->app_status_message(),undef,"Confirmation message displayed");

    $self->note_status();

    return $self;
}

# URI: /RTV/FaultyGI?display_list=workstation
#   get the Inspection Request - Goods In workstation
#
sub flow_mech__rtv__faultygi__workstation {
    my ($self) = @_;

    $self->announce_method;

    $self->mech->get_ok('/RTV/FaultyGI?display_list=workstation');
    like($self->mech->uri, qr{RTV/FaultyGI\?display_list=workstation}, 'The Faulty GI workstation page');

    return $self;
}

# URI: /RTV/FaultyGI?product_id=123&channel_id=1&sales_channel=NET-A-PORTER.COM&submit_workstation_drilldown=
#   get the Inspection Decision Goods In drilldown page
#
sub flow_mech__rtv__faultygi__goodsin {
    my ($self) = @_;

    $self->announce_method;

    my $pr_id   = $self->product->id;
    my $ch_id   = $self->channel->id;
    my $ch_name = $self->channel->name;

    $self->mech->get_ok('/RTV/FaultyGI?display_list=workstation');

    # Search first, otherwise we might get lots of forms all with
    # the same name and fields.
    $self->mech->submit_form_ok({
        form_name => 'frm_rtv_inspection_stock_select',
        fields => {
            select_product_id   => $self->product->id,
            select_origin       => 'GI',
            display_list        => 'workstation',
        },
        button => 'search_select',
    }, 'Search for our product'
    );

    $self->note_status();

    note $self->product->id;
    $self->mech->submit_form_ok({
        with_fields => {
            product_id                  => $self->product->id,
            channel_id                  => $self->channel->id,
            sales_channel               => $self->channel->name,
        },
        button => 'submit_workstation_drilldown',
    }, 'Get the drilldown page'
    );

    like($self->mech->uri, qr{RTV/FaultyGI}, 'The Faulty GI workstation page');

    return $self;
}

# URI: /RTV/FaultyGI?...
#   Submit the 'quantity' form
#
sub flow_mech__rtv__faultygi__goodsin__submit_quantity {
    my ($self, $args) = @_;

    $self->announce_method;

    my $fault_type  = $self->def($args->{fault_type}, 14); # 14=broken
    my $description = $self->def($args->{description}, 'Borked');
    my $main_qty    = $self->def($args->{main_qty}, 2);
    my $rtv_qty     = $self->def($args->{rtv_qty}, 2);
    my $dead_qty    = $self->def($args->{dead_qty}, 2);

    like($self->mech->uri, qr{RTV/FaultyGI}, 'The RTV Inspection Decision Page');

    my $id = $self->rtv_quantity_id;
    note "rtv_quantity_id = [$id]";

    $self->mech->submit_form_ok({
        with_fields => {
            "ddl_item_fault_type_$id"   => $fault_type,
            "fault_description_$id"     => $description,
            "main_qty_$id"              => $main_qty,
            "rtv_qty_$id"               => $rtv_qty,
            "dead_qty_$id"              => $dead_qty,
        },
        button => 'submit_workstation_decision',
    }, 'Submit the workstation decision'
    );

    if ($args->{expect_failure}) {
        is($self->mech->app_status_message(),undef,'Confirmation message not displayed');
        isnt($self->mech->app_error_message(),undef,'Error message displayed');
    } else {
        isnt($self->mech->app_status_message(),undef,'Confirmation message displayed');
    }

    $self->note_status();

    return $self;
}


# URI: /RTV/InspectPick
#   get the RTV - Inspection Pick page
#
sub flow_mech__rtv__inspectpick {
    my ($self) = @_;

    $self->announce_method;

    $self->mech->get_ok('/RTV/InspectPick');
    like($self->mech->uri, qr{RTV/InspectPick}, 'The Inspect Pick page');

    return $self;
}

# URI: /RTV/InspectPick
#   Submit the Inspection Pick form
#
sub flow_mech__rtv__inspectpick__submit {
    my($self) = @_;

    $self->announce_method;

    my $request_id = $self->_rtv_inspection_pick_request_id;

    note "request_id : [$request_id]";

    $self->mech->submit_form_ok({
        with_fields => {
            rtv_inspection_pick_request_id => $request_id,
        },
        button => 'select_rtv_inspection_pick_request',
    }, "submitting request id - $request_id");
    $self->note_status();

    $self->mech->form_name( 'frm_pick_rtv' );
    $self->mech->submit_form_ok({
        button => 'submit_pick_auto',
    }, "autopicking");
    $self->note_status();


    $self->mech->form_name( 'frm_pick_rtv' );
    $self->mech->submit_form_ok({
        button => 'submit_pick_rtv_commit',
    }, "commit it");
    $self->note_status();

    # This will have deleted the original RTV Quantity item and created a new one
    # (don't ask me why), so update our id
    $self->_update_rtv_quantity_id;
    return $self;
}

# URI: /RTV/RequestRMA
#   get the RTV - Request RMA - Search
#
sub flow_mech__rtv__requestrma {
    my ($self) = @_;

    $self->announce_method;

    $self->mech->get_ok('/RTV/RequestRMA');
    like($self->mech->uri, qr{RTV/RequestRMA}, 'The Request RMA page');

    return $self;
}

# URI: /RTV/RequestRMA
#   Submit the Request RMA Search page
#
sub flow_mech__rtv__requestrma__submit {
    my($self) = @_;

    $self->announce_method;

    my $select_channel_val = $self->channel->id.'__'.$self->channel->name;
    $self->mech->submit_form_ok({
        with_fields => {
            select_channel          => $select_channel_val,
            select_designer_id      => $self->product->designer_id, # 'Rows' currently
            select_product_id       => $self->product->id,
        },
        button => 'submit',
    }, "submitting request RMA");

    return $self;
 }

=head2 flow_mech__rtv__requestrma__submit__find_rtv_id_via_qnote

You may be going through this process in a way that doesn't make finding the
C<rtv_quantity_id> - which we need for selecting stock groups for RMA. Luckily
the page itself has them embedded, if you have a way of identifying which of the
groups on the page you want. If you've set a unique Quarantine Note, you're in
luck. This method will find the C<rtv_quantity_id> based on a passed-in
quarantine-note string, and return it.

It doesn't submit any request of its own, and it requires you to have called the
preceeding C<flow_mech__rtv__requestrma__submit> method correctly to call up the
product before-hand.

=cut

sub flow_mech__rtv__requestrma__submit__find_rtv_id_via_qnote {
    my ( $self, $quarantine_note ) = @_;
    $self->assert_location( '/RTV/RequestRMA' );
    my @process_groups = @{ $self->mech->as_data->{'items'} };
    my $count = @process_groups;
    note "Found $count process groups";
    my ( $matching ) = grep { $_->{'Quarantine Note'} eq $quarantine_note }
        @process_groups;
    croak "Couldn't find a row that matches the quarantine note [$quarantine_note]"
        unless $matching;
    return $matching->{'Quantity ID'};
}

# URI: /RTV/RequestRMA
#   Submit the 'Create RMA Request'
#
sub flow_mech__rtv__requestrma__create_rma_request {
    my($self, $id) = @_;
    $self->announce_method;
    my $user_supplied_id = $id ? 1 : 0;

    unless ( defined $id ) {
        $self->_update_rtv_quantity_id;
        $id = $self->rtv_quantity_id;
    }

    $self->mech->submit_form_ok({
        with_fields => {
            "ddl_item_fault_type_$id"   => 1, # 'various' - not a constant
            "fault_description_$id"     => 'Fault description',
            "include_id_$id"            => 1,
            "request_detail_type_$id"   => 3, # 'replacement' - not a constant
            rma_request_comments        => 'RMA request comments',
        },
        button => 'submit_rma_request',
    }, "submitting RMA request");

    my $rma_request_id;

    # If we were passed in an ID, presumably we're doing this avoiding keeping
    # state in the RTV object, so we'll lookup the RMA Request ID from the URL
    # and return it!
    if ( $user_supplied_id ) {
        ($rma_request_id) =
            $self->mech->uri->path_query =~ m/rma_request_id=(\d+)/;
        note "RMA Request ID = [$rma_request_id] (via URI)";
        return $rma_request_id;
    } else {
        $rma_request_id = $self->data__rtv__rma_request_id;
        note "RMA Request ID = [$rma_request_id] (via DB)";
    }

    # This leaves us on the RMA Email page

    return $self;
}


# URI: /RTV/ListRMA
#   get the RTV - List RMA - View List page
#
sub flow_mech__rtv__listrma {
    my ($self) = @_;

    $self->announce_method;

    $self->mech->get_ok('/RTV/ListRMA');
    like($self->mech->uri, qr{RTV/ListRMA}, 'The List RMA page');

    return $self;
}

# URI: /RTV/RequestRMA
#   submit the RMA List search
#
sub flow_mech__rtv__listrma__submit {
    my ($self, $rma_request_id ) = @_;

    $self->announce_method;

    $rma_request_id = $self->data__rtv__rma_request_id
        unless defined $rma_request_id;

    $self->mech->submit_form_ok({
        with_fields => {
            select_rma_request_id   => $rma_request_id,
        },
        button => 'search_select',
    }, "RMA View list search");

    return $self;
}

# URI: /RTV/ListRMA
#   submit the email
#
sub flow_mech__rtv__requestrma__submit_email {
    my ($self, $args) = @_;

    my $to      = defined $args->{to}       ? $args->{to}       : 'foo@net-a-porter.com';
    my $message = defined $args->{message}  ? $args->{message}  : 'the message body';

    $self->mech->submit_form_ok({
        with_fields => {
            txt_rma_email_to        => $to,
            txt_rma_email_bcc       => $to,
            txta_rma_email_message  => $message,
        },
        button => 'submit_send_rma_email',
    }, "Sending RMA email");

    like($self->mech->uri, qr{/RTV/ListRMA}, 'Email submit URI');

    return $self;
}

# URI: /RTV/ListRMA
#   List RMA - View Request
#
sub flow_mech__rtv__listrma__view_request {
    my ($self, $rma_request_id ) = @_;

    $self->announce_method;

    $rma_request_id = $self->data__rtv__rma_request_id
        unless defined $rma_request_id;

    $self->mech->get_ok("/RTV/ListRMA?rma_request_id=$rma_request_id");
    like($self->mech->uri, qr{RTV/ListRMA\?rma_request_id=$rma_request_id}, 'The RMA View Request page');

    return $self;
}

# URI: /RTV/ListRMA?rma_request_id=...
#   List RMA - Update RMA number
#
sub flow_mech__rtv__listrma__update_rma_number {
    my ($self, $args) = @_;

    $self->announce_method;
    $args->{'rma_request_id'} = $self->data__rtv__rma_request_id
        unless defined $args->{'rma_request_id'};
    $args->{'rma_number'} = $self->data__rtv__rma_number
        unless defined $args->{'rma_number'};
    $args->{'follow_up_date'} = $self->data__rtv__rma_request->date_followup
        unless defined $args->{'follow_up_date'};

    $self->mech->submit_form_ok({
        with_fields => {
            txt_rma_number               => $args->{'rma_number'},
            edit_txt_rma_number          => "on",
            ddl_date_followup_datestring => $args->{'follow_up_date'}
        },
        button => 'submit_update_header',
    }, "Setting RMA number");

    note 'RMA Number = [' . $args->{'rma_number'} . ']';

    my $id = $args->{'rma_request_id'};
    like($self->mech->uri, qr{/RTV/ListRMA\?rma_request_id=$id},
        'The View RMA request page again');
    isnt($self->mech->app_status_message(),undef,"Confirmation message displayed");
    $self->note_status();

    return $self;
}

# URI: /RTV/ListRMA?rma_request_id=...
#   List RMA - Capture Notes
#
sub flow_mech__rtv__listrma__capture_notes {
    my ($self, $rma_request_id) = @_;

    $self->announce_method;

    $rma_request_id = $self->data__rtv__rma_request_id
        unless defined $rma_request_id;

    my $note = "Test note for $rma_request_id at ".time();

    $self->mech->submit_form_ok({
        with_fields => {
            'txta_rma_request_note'  => $note,
        },
        button => 'submit_add_note',
    }, "Adding RMA note");

    like($self->mech->uri, qr{/RTV/ListRMA\?rma_request_id=$rma_request_id}, 'The View RMA request page again');
    isnt($self->mech->app_status_message(),undef,"Confirmation message displayed");
    $self->note_status();

    # check new note is displayed
    $self->mech->content_contains($note, "Page displays new note");

    return $self;
}


# URI: /RTV/ListRMA?rma_request_id=...
#   Create shipment
# URI: /RTV/ListRTV?rtv_shipment_id=...
#   View shipment details
#
sub flow_mech__rtv__create_shipment {
    my ($self, $rma_request_id) = @_;
    my $user_supplied_id = $rma_request_id ? 1 : 0;

    $self->announce_method;

    $rma_request_id = $self->data__rtv__rma_request_id
        unless defined $rma_request_id;

    $self->mech->form_name('frm_rma_request_details');
    $self->mech->submit_form_ok({
        with_fields => {
            txt_contact_name        => 'Mr Test Contact',
            txt_address_one         => 'Big Building',
            txt_address_two         => 'Long Street',
            txt_town_city           => 'Nice Town',
            txt_postcode_zip        => 'SW1A1AA',
            ddl_country             => 'United Kingdom',
            txt_carrier_name_new    => 'New Carrier',
            txt_carrier_account_ref => '1234567',
        },
        button => 'submit_create_rtv_shipment',
    }, "Creating shipment");

    # We should've been redirected to the view shipment page
    like($self->mech->uri, qr{/RTV/ListRTV\?rtv_shipment_id}, 'The View Shipment page');

    isnt($self->mech->app_status_message(),undef,"Confirmation message displayed");
    $self->note_status();

    # check the page links to the right RMA
    my $rma_link = $self->mech->find_xpath(
        "//a[\@href='/RTV/ListRMA?rma_request_id=$rma_request_id']"
    )->pop;
    isnt($rma_link,undef,"Correct RMA link displayed");

    # check the page shows the right RTV shipment id
    if ( $user_supplied_id ) {
        my ($shipment_id) =
            $self->mech->uri->path_query =~ m/rtv_shipment_id=(\d+)/;
        note "Shipment ID: [$shipment_id]";
        return $shipment_id;
    } else {
        note "Shipment ID: [".$self->data__rtv__rtv_shipment->id."]";
        return $self;
    }
}

# URI: /RTV/ListRTV
#   get the RTV - List RTV - View List page
#
sub flow_mech__rtv__listrtv {
    my ($self, $rtv_shipment_id ) = @_;

    $self->announce_method;

    $self->mech->get_ok('/RTV/ListRTV');
    like($self->mech->uri, qr{RTV/ListRTV}, 'The List RTV page');

    $rtv_shipment_id = $self->data__rtv__rtv_shipment->id
        unless defined $rtv_shipment_id;

    # find the rtv shipment we just created
    my $rtv_link = $self->mech->find_xpath(
        "//a[\@href='ListRTV?rtv_shipment_id=$rtv_shipment_id']"
        )->pop;
    isnt($rtv_link,undef,"RTV list contains new RTV shipment");

    return $self;
}

# URI: /RTV/PickRTV
#   Pick Shipment
#
sub flow_mech__rtv__pickrtv {
    my ($self, $rtv_shipment_id) = @_;

    $self->announce_method;

    $self->mech->get_ok('/RTV/PickRTV');
    like($self->mech->uri, qr{RTV/PickRTV}, 'The Pick RTV page');

    $rtv_shipment_id = $self->data__rtv__rtv_shipment->id
        unless defined $rtv_shipment_id;


    $self->mech->form_name('frm_select_rtv_shipment');
    $self->mech->submit_form_ok({
        with_fields => {
            rtv_shipment_id        => $rtv_shipment_id,
        },
        button => 'select_rtv_shipment',
    }, "Picking shipment - enter RTV shipment ID");

    $self->note_status();

    return $self;
}

# URI: /RTV/PickRTV
#   Pick Shipment - autopick and commit
#
sub flow_mech__rtv__pickrtv_autopick_and_commit {
    my ($self, $rtv_shipment_id) = @_;

    $self->announce_method;

    $rtv_shipment_id = $self->data__rtv__rtv_shipment->id
        unless defined $rtv_shipment_id;


    $self->mech->submit_form_ok({
        form_name => 'frm_pick_rtv',
        fields => {
            rtv_shipment_id        => $rtv_shipment_id,
        },
        button => 'submit_pick_auto',
    }, "Picking shipment - Auto-Pick");

    $self->note_status();

    $self->mech->submit_form_ok({
        form_name => 'frm_pick_rtv',
        fields => {
            rtv_shipment_id        => $rtv_shipment_id,
        },
        button => 'submit_pick_rtv_commit',
    }, "Picking shipment - Commit");

    $self->note_status();

    return $self;
}

# URI: /RTV/PackRTV
#   Pack Shipment
#
sub flow_mech__rtv__packrtv {
    my ($self, $rtv_shipment_id) = @_;

    $self->announce_method;

    $rtv_shipment_id = $self->data__rtv__rtv_shipment->id
        unless defined $rtv_shipment_id;

    $self->mech->get_ok('/RTV/PackRTV');
    like($self->mech->uri, qr{RTV/PackRTV}, 'The Pack RTV page');

    $self->mech->submit_form_ok({
        form_name => 'frm_select_rtv_shipment',
        fields => {
            rtv_shipment_id        => $rtv_shipment_id,
        },
        button => 'select_rtv_shipment',
    }, "Packing shipment - enter RTV shipment ID");

    $self->note_status();

    return $self;
}


# URI: /RTV/PackRTV
#   Pack Shipment - autopack and commit
#
sub flow_mech__rtv__packrtv_autopack_and_commit {
    my ($self, $rtv_shipment_id) = @_;

    $self->announce_method;
    $rtv_shipment_id = $self->data__rtv__rtv_shipment->id
        unless defined $rtv_shipment_id;

    $self->mech->submit_form_ok({
        form_name => 'frm_pack_rtv',
        fields => {
            rtv_shipment_id        => $rtv_shipment_id,
        },
        button => 'submit_pack_auto',
    }, "Packing shipment - Auto-Pack");

    $self->note_status();

    $self->mech->submit_form_ok({
        form_name => 'frm_pack_rtv',
        fields => {
            rtv_shipment_id        => $rtv_shipment_id,
        },
        button => 'submit_pack_rtv_commit',
    }, "Packing shipment - Commit");

    $self->note_status();

    return $self;
}


# URI: /RTV/AwaitingDispatch
#   get the View Awaiting Dispatch page
#
sub flow_mech__rtv__view_awaiting_dispatch {
    my ($self, $rtv_shipment_id) = @_;

    $self->announce_method;

    $self->mech->get_ok('/RTV/AwaitingDispatch');
    like($self->mech->uri, qr{/RTV/AwaitingDispatch}, 'The View Awaiting Dispatch page');

    $rtv_shipment_id = $self->data__rtv__rtv_shipment->id
        unless defined $rtv_shipment_id;

    # find the row for the rtv shipment we packed
    my $rtv_link = $self->mech->find_xpath(
        "//a[\@href='AwaitingDispatch?rtv_shipment_id=$rtv_shipment_id']"
        )->pop;
    isnt($rtv_link,undef,"Awaiting dispatch list contains RTV shipment");


    return $self;
}

# URI: /RTV/AwaitingDispatch?rtv_shipment_id=...
#   get the View Shipment Details page
#
sub flow_mech__rtv__view_shipment_details {
    my ($self, $rtv_shipment_id ) = @_;

    $self->announce_method;

    $rtv_shipment_id = $self->data__rtv__rtv_shipment->id
        unless defined $rtv_shipment_id;

    $self->mech->get_ok('/RTV/AwaitingDispatch?rtv_shipment_id='.$rtv_shipment_id);
    like($self->mech->uri, qr{/RTV/AwaitingDispatch}, 'The View Shipment Details page');

    $self->note_status();

    return $self;
}

# URI: /RTV/AwaitingDispatch?rtv_shipment_id=...
#   Update Shipment Details
#
sub flow_mech__rtv__update_shipment_details {
    my ($self, $args) = @_;

    $self->announce_method;

    $args->{'rtv_shipment_id'} = $self->data__rtv__rtv_shipment->id
        unless defined $args->{'rtv_shipment_id'};
    $args->{'airway_bill_id'} = $self->data__rtv__airway_bill_id
        unless defined $args->{'airway_bill_id'};

    $self->mech->submit_form_ok({
        with_fields => {
            txt_airwaybill => $args->{'airway_bill_id'},
        },
        button => 'submit_airwaybill',
    }, "Update shipment - enter airwaybill ID");

    isnt($self->mech->app_status_message(),undef,"Confirmation message displayed");
    $self->note_status();

    my $rtv_shipment_id = $args->{'rtv_shipment_id'};
    like($self->mech->uri, qr{/RTV/ListRTV\?rtv_shipment_id=$rtv_shipment_id}, 'The View Shipment Details page');

    return $self;
}

# URI: /RTV/DispatchedRTV
#   View Dispatched Shipments List
#
sub flow_mech__rtv__view_dispatched_shipments {
    my ($self, $args) = @_;

    $self->announce_method;

    my $rma_number = $args->{'rma_number'} || $self->data__rtv__rma_number();
    my $airway_bill_id = $args->{'airway_bill_id'} || $self->data__rtv__airway_bill_id;

    $self->mech->get_ok('/RTV/DispatchedRTV');
    like($self->mech->uri, qr{/RTV/DispatchedRTV}, 'The Dispatched Shipments search form');

    $self->mech->submit_form_ok({
        form_name => 'frm_rtv_shipment_select',
        fields => {
            select_airwaybill => $args->{'airway_bill_id'}
        },
        button => 'search_select',
    }, "Dispatched shipments search");

    $self->note_status();

    note "Looking for row with [$rma_number]";

    # check there's a row for this item
    my $rtv_td = $self->mech->find_xpath(
        "//td[.='$rma_number']"
    )->pop;
    isnt($rtv_td, undef, "Found matching row");

    return $self;
}

# URI: /RTV/DispatchedRTV?rtv_shipment_id=...
#   View Dispatched Shipment details
#
sub flow_mech__rtv__view_dispatched_shipment_details {
    my ($self, $rtv_shipment_id ) = @_;

    $self->announce_method;

    $rtv_shipment_id = $self->data__rtv__rtv_shipment->id
        unless defined $rtv_shipment_id;

    $self->mech->get_ok('/RTV/DispatchedRTV?rtv_shipment_id='.$rtv_shipment_id);
    like($self->mech->uri, qr{/RTV/DispatchedRTV\?rtv_shipment_id=$rtv_shipment_id}, 'The View Dispatched Shipment Details page');

    return $self;
}


1;
