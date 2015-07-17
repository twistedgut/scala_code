package Test::XT::Flow::Samples;

use NAP::policy "tt",     qw( test role );

requires 'mech';
requires 'note_status';

with 'Test::XT::Flow::AutoMethods';
with 'Test::Role::DBSamples';

#
# Push through the samples workflow
# Process documented at http://confluence.net-a-porter.com/display/Black/Sample
#
use Test::XTracker::Data;

use Data::Dump qw/pp/;

=head2 flow_mech__stockcontrol__sample

Fetch '/StockControl/Sample'

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__samples__stock_control_sample',
    page_description => 'Sample Transfer Requests list',
    page_url         => '/StockControl/Sample'
);

# URI: /StockControl/Sample
#   Approve transfer request
#
sub flow_mech__samples__stock_control_approve_transfer {
    my ($self, @ids) = @_;

    $self->announce_method;
    like($self->mech->uri, qr{StockControl/Sample}, 'The Sample Transfer Requests page');

    # Approve supplied ids, if there are any, and otherwise approve the sample
    # transfer request
    @ids = ( $self->attr__samples__stock_transfer->id ) unless @ids;
    my %fields = map { ( "approve-$_" => 'yes' ) } @ids;

    note 'submit checkbox_values ['.join(', ', sort keys %fields).']';
    $self->mech->submit_form_ok({
        with_fields => \%fields,
        button => 'submit',
    }, 'Approving stock transfer request'.(scalar(keys(%fields)) > 1 ? 's' : ''));

    $self->note_status();
    isnt($self->mech->app_status_message(),undef,"Confirmation message displayed");

    return $self;
}

=head2 flow_mech__samples__stock_control_sample_goodsin

View samples requests waiting to be checked in - /StockControl/Sample/GoodsIn

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__samples__stock_control_sample_goodsin',
    page_description => 'Sample - Goods In page',
    page_url         => '/StockControl/Sample/GoodsIn'
);

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__samples__stock_control_sample_goodsin__mark_received',
    form_name => 'search_1',  # it does not matter if the request we
                              # want to submit is in another "tab" in
                              # the page, the submitted fields will be
                              # the same
    form_description  => 'sample received ack',
    assert_location   => qr!^/StockControl/Sample/GoodsIn!,
    transform_fields  => sub {
        my ($self,$shipment_id,$channel_id) = @_;

        return { "stock-${shipment_id}-${channel_id}" => 1 }
    },
);

__PACKAGE__->create_fetch_method(
    method_name      => 'mech__samples__sample_adjustment',
    page_description => 'Sample Adjustment',
    page_url         => '/StockControl/SampleAdjustment',
    params           => [qw/product_id variant_id/],
);

# Instead of location_name - location_id or quantity_id?
sub _get_sample_adjustment_row_number {
    my ( $self, $channel_id, $location_name ) = @_;
    # As far as the app is concerned any sample quantity at a given
    # location once it's been dispatched is the same, so we're just
    # submitting the any row that matches the given arguments
    my $el = $self->mech->find_xpath(
        qq{//form[\@name='lose_sample_$channel_id']//td[text()='$location_name']/..//input[\@type='submit']}
    )->pop;
    my ($row_number) = $el->attr('name') =~ m{(\d+)$};
}

__PACKAGE__->create_form_method(
    method_name      => 'mech__samples__lose_sample_submit',
    form_name        => sub { "lose_sample_$_[1]{channel_id}" },
    form_description => 'lose sample',
    assert_location  => qr{^/StockControl/SampleAdjustment\?(?:variant_id|product_id)=\d+$},
    form_button      => sub {
        my ( $self, $args ) = @_;
        my $row_number = $self->_get_sample_adjustment_row_number(@{$args}{qw/channel_id location_name/});
        return "lost_$row_number";
    },
    transform_fields => sub {
        my ( $self, $args ) = @_;
        my $row_number = $self->_get_sample_adjustment_row_number(@{$args}{qw/channel_id location_name/});
        return { "notes_$row_number" => delete $args->{notes} };
    },
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__samples__find_sample_submit',
    form_name        => sub { my $shipment_item_id = $_[1]; "found_shipment_$shipment_item_id"; },
    form_description => 'find sample',
    assert_location  => qr{^/StockControl/SampleAdjustment\?(?:variant_id|product_id)=\d+$},
    form_button      => 'found',
);

1;
