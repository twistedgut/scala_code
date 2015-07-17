package Test::XTracker::Mechanize::RTV;

use Moose;

use XTracker::Constants::FromDB qw(
    :channel
);
use Test::XTracker::Data;
use XTracker::Constants::FromDB qw(
    :channel
    :stock_process_type
    :stock_process_status
    :authorisation_level
);

use Carp;

use Data::Dump qq/pp/;


#extends 'Test::XTracker::Mechanize', 'Test::XTracker::Data';

with 'WWW::Mechanize::TreeBuilder' => {tree_class => 'HTML::TreeBuilder::XPath'},
    ;

sub get_page_inspection_request {
    my ($self, $po) = @_;

    note 'sub get_page_inspection_request';

    my $stock_order = $po->stock_orders->first;
    my $product     = $stock_order->public_product;
    my $product_id  = $product->id;
    my $variant     = $product->variants->first;
    my $delivery    = $stock_order->deliveries->first;

    $self->get_ok('/RTV/FaultyGI');
    like($self->uri, qr{RTV/FaultyGI}, 'The Faulty GI page');
    return $self;
}

sub test_workstation {
    my ($self, $po) = @_;

    note 'sub test_workstation';

    $self->get_ok('/RTV/FaultyGI?display_list=workstation');
    like($self->uri, qr{RTV/FaultyGI\?display_list=workstation}, 'The RTV Workstation page');

    my $stock_order = $po->stock_orders->first;
    my $product     = $stock_order->public_product;
    my $product_id  = $product->id;

    my $mr_porter_span = $self->find_xpath(
        "//td/a[\@href =~ 'FaultyGI.*$product_id']")->pop;

    isnt($mr_porter_span, undef, 'title channelised correctly');

    my @look = $self->look_down('value', $product_id);
    is(scalar @look, 1, "found product_id in hidden field");

    @look = $self->look_down('value', $po->channel->name);
    is(scalar @look > 0, 1, "found sales_channel in hidden field");

    @look = $self->look_down('value', $po->channel_id);
    is(scalar @look > 0, 1, "found channel_id in hidden field");

    $self->submit_form_ok({
        with_fields => {
            product_id      => $product_id,
            channel_id      => $po->channel_id,
            sales_channel   => $po->channel->name,
        },
        button => 'submit_workstation_drilldown',
    }, "submitting request for workstation drilldown");

    return $self;
}

sub test_inspect_pick {
    my($self,$po) = @_;

    note 'sub test_inspect_pick';

    $self->get_ok('/RTV/InspectPick');
    like($self->uri, qr{RTV/InspectPick}, 'The Inspect Pick page');

    my $request_id = $self->rtv_inspection_pick_request_id_from_po($po);

    note $self->uri;
    note "request_id : $request_id";

    $self->submit_form_ok({
        with_fields => {
            rtv_inspection_pick_request_id => $request_id,
        },
        button => 'select_rtv_inspection_pick_request',
    }, "submitting request id - $request_id");

    $self->form_name( 'frm_pick_rtv' );
    $self->submit_form_ok({
        button => 'submit_pick_auto',
    }, "autopicking");

    $self->form_name( 'frm_pick_rtv' );
    $self->submit_form_ok({
        button => 'submit_pick_rtv_commit',
    }, "commit it");

    return $self;
}

sub rtv_inspection_pick_request_id_from_po {
    my($self,$po) = @_;
    my $id = $po->stock_orders->first
        ->public_product
        ->variants->first
        ->rtv_quantities->first
        ->rtv_inspection_pick_request_details->first
        ->rtv_inspection_pick_request_id;

    return "RTVI-$id";
}

sub test_inspection_decision {
    my ($self, $po) = @_;

    note 'sub test_inspection_decision';

    my $schema          = Test::XTracker::Data->get_schema;
    my $stock_order     = $po->stock_orders->first;
    my $product         = $stock_order->public_product;
    my $product_id      = $product->id;
    my $channel_id      = $po->channel_id;
    my $sales_channel   = $po->channel->name;
    my $variant         = $product->variants->first;
    my ($rtv_quantity)  = $schema->resultset('Public::RTVQuantity')->search({
        variant_id  => $variant->id,
    });
    isnt($rtv_quantity, undef, 'We have an rtv_quantity');

    $self->get_ok("/RTV/FaultyGI?product_id=$product_id&channel_id=$channel_id&sales_channel=$sales_channel&submit_workstation_drilldown=1");
    like($self->uri, qr{RTV/FaultyGI}, 'The RTV Workstation page');

#    note $self->uri;
    # It it channelised with the correct logo
    $self->ok_logo_channelisation($po->channel);
    $self->ok_title_channelisation($po->channel, ['Quantity Breakdown', $po->channel->name]);

    # Fill in the form fault description
    my $rtv_quantity_id = $rtv_quantity->id;

    $self->submit_form_ok({
        with_fields => {
            "edit_ddl_item_fault_type_$rtv_quantity_id" => 14,
            "fault_description_$rtv_quantity_id"        => 'It is brokon',
            "main_qty_$rtv_quantity_id"                 => 2,
            "rtv_qty_$rtv_quantity_id"                  => 2,
            "dead_qty_$rtv_quantity_id"                 => 1,
        },
        button => 'submit_workstation_decision',
    }, 'provide packing slip values');

    note "submit form url ".$self->uri;
    like($self->uri, qr{/RTV/FaultyGI.*product_id=$product_id}, 'Redirect to RTV Workstation');
}


1;
