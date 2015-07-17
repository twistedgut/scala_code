package Test::XT::Feature::Ch11n::RTV;

use NAP::policy "tt", qw( test role );

#
# Tests for pages in the RTV workflow
#
use XTracker::Config::Local;
use Test::XTracker::Data;


# URI: /RTV/FaultyGI
#   test that the page is correctly channelised
#
sub test_mech__rtv__faultygi_ch11n {
    my ($self) = @_;

    $self->announce_method;

    my $stock_order = $self->purchase_order->stock_orders->first;
    my $product     = $stock_order->public_product;
    my $product_id  = $product->id;
    my $variant     = $product->variants
        ->search({},{order_by=>{-asc=>'id'}})->first;
    my $delivery    = $stock_order->deliveries->first;

    # Check the channel is displayed correctly for this row.
    # We want to check the span in the td following the one that contains
    # <a href=...[this PID]...>, because that's where the channel is shown.
    my $channel_name_span = $self->mech->find_xpath(
        "//td/a[\@href =~ 'FaultyGI.*$product_id']/parent::td/following-sibling::td/child::span"
        )->pop;

    $self->mech_row_item_ch11n({
        'element'=>$channel_name_span,
        'channel'=>$self->channel,
    });

    return $self;
}

# URI: /RTV/FaultyGI
#   test that having submitted the Request Inspection form a
#   inspect picklist document has been created
#
sub test_mech__rtv__faultygi__submit_ch11n {
    my ($self) = @_;

    $self->announce_method;

    my $stock_order = $self->purchase_order->stock_orders->first;
    my $product     = $stock_order->public_product;
    my $product_id  = $product->id;
    my $variant     = $product->variants
        ->search({},{order_by=>{-asc=>'id'}})->first;

    my $printdocs = Test::XTracker::PrintDocs->new;

    my $doc_id = $variant
                ->rtv_quantities->first
                ->rtv_inspection_pick_request_details->first
                ->rtv_inspection_pick_request_id;

    # Check that an inspect picklist document has been created
    my ( $printdoc_file ) = $printdocs->wait_for_new_files( files => 1 );
    my $file = $printdoc_file->full_path;
    note "doc_id : $doc_id";
    note "rtv pick list : $file";
    # Just check for something in the file to ensure it is there and can be read
    ok $self->mech->find_text_in_file($file, '>'.$variant->sku.'<'), 'RTV request print doc should exist';

    return $self;
}

sub test_mech__rtv__faultygi__workstation_ch11n {
    my ($self) = @_;

    $self->announce_method;

    my $stock_order = $self->purchase_order->stock_orders->first;
    my $product     = $stock_order->public_product;
    my $product_id  = $product->id;

    # Check the channel is displayed correctly for this row.

    # We want to check the span in the td following the one that contains
    # <a href=...[this PID]...>, because that's where the channel is shown.
    my $channel_name_span = $self->mech->find_xpath(
        "//td/a[\@href =~ 'FaultyGI.*$product_id']/parent::td/following-sibling::td/child::span"
        )->pop;

    $self->mech_row_item_ch11n({
        'element'=>$channel_name_span,
        'channel'=>$self->purchase_order->channel,
    });

    return $self;
}

sub test_mech__rtv__faultygi__goodsin_ch11n {
    my ($self) = @_;

    $self->announce_method;

    # check the logo
    $self->mech_logo_ch11n();

    # check the sales channel is displayed correctly
    my $channel_name_span = $self->mech->find_xpath(
        "//td/span[\@class = 'title ".$self->_title_class()."' ]"
        )->pop;

    is ($channel_name_span->as_text(), $self->channel->name, "channel name displayed correctly");

    return $self;
}


sub test_mech__rtv__requestrma_ch11n {
    my ($self) = @_;

    $self->announce_method;

    # check the right channels appear in the dropdown
    $self->mech_select_box_ch11n({ name => 'select_channel', no_all => 1, long_value => 1 });

    return $self;
}

sub test_mech__rtv__requestrma__submit_ch11n {
    my ($self) = @_;

    $self->announce_method;

    # check the logo
    $self->mech_logo_ch11n();

    # check the right channels appear in the dropdown
    $self->mech_select_box_ch11n({ name => 'select_channel', no_all => 1, long_value => 1 });

    # check the headings are displayed correctly
    $self->mech_title_ch11n(['Search Results']);

    return $self;
}

sub test_mech__rtv__request_rma__email_ch11n {
    my ($self) = @_;

    $self->announce_method;

    # check the logo
    $self->mech_logo_ch11n();

    # check the headings are displayed correctly
    $self->mech_title_ch11n(['RMA Email']);

    # check the subject starts with the channel name
    my $email_subject_field = $self->mech->find_xpath(
        "//input[\@name='txt_rma_email_subject']"
        )->pop();
    my $channel_name=$self->channel->name;
    like ($email_subject_field->attr('value'), qr/^\Q$channel_name/,
        "email subject starts with channel name");

    return $self;
}


sub test_mech__rtv__listrma__submit_ch11n {
    my ($self) = @_;

    $self->announce_method;

    my $rma_request_id = $self->data__rtv__rma_request_id;

    # Check the channel is displayed correctly for this row.
    # We want to check the span in the td following the one that contains
    # <a href=...[RMA req ID]...>, because that's where the channel is shown.
    my $channel_name_span = $self->mech->find_xpath(
        "//td/a[\@href = 'ListRMA?rma_request_id=$rma_request_id']/parent::td/following-sibling::td/child::span"
        )->pop;

    $self->mech_row_item_ch11n({
        'element'=>$channel_name_span,
        'channel'=>$self->channel,
    });

    return $self;
}

sub test_mech__rtv__listrma__view_request_summary_ch11n {
    my ($self) = @_;

    $self->announce_method;

    # check the logo
    $self->mech_logo_ch11n();

    # check the request summary heading is displayed correctly
    $self->mech_title_ch11n(['Request Summary']);

    return $self;
}

sub test_mech__rtv__listrma__view_request_details_ch11n {
    my ($self) = @_;

    $self->announce_method;

    # check the logo
    $self->mech_logo_ch11n();

    # check the headings are displayed correctly
    $self->mech_title_ch11n(['Request Details','Create RTV Shipment','Correspondence Log']);

    return $self;
}

sub test_mech__rtv__view_shipment_details_ch11n {
    my ($self) = @_;

    $self->announce_method;

    # check the logo
    $self->mech_logo_ch11n();

    # check the headings are displayed correctly
    $self->mech_title_ch11n(['Shipment Details','Shipment Items']);

    return $self;
}

sub test_mech__rtv__listrtv_ch11n {
    my ($self) = @_;

    $self->announce_method;

    my $rma_request_id = $self->data__rtv__rma_request_id;

    # Check the channel is displayed correctly for this row.
    # We want to check the span in the td following the one that contains
    # <a href=...[rma request id]...>, because that's where the channel is shown.
    my $channel_name_span = $self->mech->find_xpath(
        "//td/a[\@href = 'ListRMA?rma_request_id=$rma_request_id']/parent::td/following-sibling::td/child::span"
        )->pop;

    $self->mech_row_item_ch11n({
        'element'=>$channel_name_span,
        'channel'=>$self->channel,
    });

    return $self;
}

sub test_mech__rtv__pickrtv_ch11n {
    my ($self) = @_;

    $self->announce_method;

    # check the logo
    $self->mech_logo_ch11n();

    return $self;
}

sub test_mech__rtv__view_awaiting_dispatch_ch11n {
    my ($self) = @_;

    $self->announce_method;

    my $rma_request_id = $self->data__rtv__rma_request_id;

    # Check the channel is displayed correctly for this row.
    # We want to check the span in the td following the one that contains
    # <a href=...[rma request id]...>, because that's where the channel is shown.
    my $channel_name_span = $self->mech->find_xpath(
        "//td/a[\@href = 'ListRMA?rma_request_id=$rma_request_id']/parent::td/following-sibling::td/child::span"
        )->pop;

    $self->mech_row_item_ch11n({
        'element'=>$channel_name_span,
        'channel'=>$self->channel,
    });

    return $self;
}

sub test_mech__rtv__view_dispatched_shipments_ch11n {
    my ($self) = @_;

    $self->announce_method;

    my $rma_number = $self->data__rtv__rma_number;

    # Check the channel is displayed correctly for this row.
    # We want to check the span in the td before the one that contains
    # the RMA number, because that's where the channel is shown.
    my $channel_name_span = $self->mech->find_xpath(
        "//td[.='$rma_number']/preceding-sibling::td/child::span"
        )->pop;

    $self->mech_row_item_ch11n({
        'element'=>$channel_name_span,
        'channel'=>$self->channel,
    });

    return $self;
}

sub test_mech__rtv__view_dispatched_shipment_details_ch11n {
    my ($self) = @_;

    $self->announce_method;

    # check the logo
    $self->mech_logo_ch11n();

    # find the exact content of the "Correspondence Log" heading so we can
    # easily add it to the list for channelisation checks
    my $log_title_span = $self->mech->find_xpath(
        "//span[.=~'Correspondence Log']"
    )->pop;

    note "found ".$log_title_span->as_text." heading" if ($log_title_span);

    # check the headings are displayed correctly
    $self->mech_title_ch11n(['Shipment Details','Shipment Items',$log_title_span->as_text()]);

    return $self;
}

1;
