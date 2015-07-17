package Test::XTracker::Page::TraitFor::PurchaseOrder;

use Moose::Role;

#
# Tests for pages in the Purchase Order Workflow
#
use XTracker::Config::Local;



# URI: /StockControl/PurchaseOrder
#   test that the search form
#
sub test_stock_control_purchase_order {
    my ($self) = @_;

    note "SUB test_stock_control_purchase_order";

    return $self
        ->test_select_box_channelisation                    # The Sales Channel select box is channelised
        ;
}

# URI: /StockControl/PurchaseOrder
#   test that the search form submits and behaves correctly
#
sub submit_stock_control_purchase_order {
    my ($self) = @_;

    note "SUB submit_stock_control_purchase_order";

    # Enter the purchase order in the 'PO Number' field
    my $search_form = $self->form_name('searchForm');

    $self->submit_form_ok({
        with_fields => {
            purchase_order_number   => $self->purchase_order->id,
        },
    }, "Submitting a search for the purchase order");
    like($self->uri, qr{/StockControl/PurchaseOrder}, 'Purchase Order search submitted');

    # The requested purchase order should be on the page

    my $open_plus = $self->look_down('id', "open_".$self->purchase_order->id);
    isnt($open_plus, undef, 'PO found in list');

    # Ensure that the channel name appears on the list with the correct colour
    my $title_class = "title-".$self->channel->business->config_section;
    my $search_results = $self->look_down('class', $title_class);
    isnt($search_results, undef, 'Channel appears in the list');

    # Now search with the purchase order and the correct channel
    $search_form = $self->form_name('searchForm');

    $self->submit_form_ok({
        with_fields => {
            purchase_order_number   => $self->purchase_order->id,
            channel_id              => $self->channel->id,
        },
    }, "Submitting a search with a correct channel");

    # The page should have been submitted, and show the PO in the list
    $open_plus = $self->look_down('id', "open_".$self->purchase_order->id);
    isnt($open_plus, undef, 'PO found in list');

    # Ensure that the channel name appears on the list with the correct colour
    $search_results = $self->look_down('class', $title_class);
    isnt($search_results, undef, 'Channel appears in the list');

    # Now search with the purchase order and the wrong channel
    $search_form = $self->form_name('searchForm');

    $self->submit_form_ok({
        with_fields => {
            purchase_order_number   => $self->purchase_order->id,
            channel_id              => $self->channel->id,
        },
    }, "Submitting a search with a correct channel");

    # The page should have been submitted, and NOT show the PO in the list
    $open_plus = $self->look_down('id', "open_".$self->purchase_order->id);
    is($open_plus, undef, 'PO not found in list');

    return $self;
}

1;
