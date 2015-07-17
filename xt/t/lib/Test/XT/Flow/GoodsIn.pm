package Test::XT::Flow::GoodsIn; ## no critic(ProhibitExcessMainComplexity)

use NAP::policy "tt",     qw( test role );

requires 'mech';
requires 'note_status';
requires 'config_var';

with 'Test::XT::Flow::AutoMethods';

#
# Push through the Goods In workflow
#
use XTracker::Config::Local;
use Test::XTracker::Data;


use XTracker::Constants::FromDB qw( :item_fault_type :storage_type );

############################
# Page workflow methods
############################

# URI: /GoodsIn/StockIn
#   get Goods In - Stock In search form
#
__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__goodsin__stockin',
    page_description => 'Goods In - Stock In list',
    page_url         => '/GoodsIn/StockIn'
);

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__goodsin__stockin_search',
    form_name         => 'searchForm',
    form_description  => 'Stock In search',
    assert_location   => '/GoodsIn/StockIn',
    transform_fields => sub {
        my ( $self, $args ) = @_;

        # For now, enforce the only argument we understand. Feel free to change
        # if you add more...
        croak "You must provide a purchase_order_number"
            unless $args->{'purchase_order_number'};

        return $args;
    }
);


# URI: /GoodsIn/StockIn/PackingSlip?so_id=123
#   get the Goods In - Stock In - Packing Slip page
__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__goodsin__stockin_packingslip',
    page_description => 'Packing Slip page',
    page_url         => '/GoodsIn/StockIn/PackingSlip?so_id=',
    required_param   => 'Stock Order ID'
);

# URI: /GoodsIn/StockIn/PackingSlip?so_id=123
#   submit the Packing Slip Values
#
__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__goodsin__stockin_packingslip__submit',
    form_name         => 'create_stock_delivery',
    form_description  => 'Packing Slip values',
    assert_location   => qr!/GoodsIn/StockIn/PackingSlip\?so_id=\d+!,
    transform_fields => sub {
        my ( $self, $incoming_skus ) = @_;

        # Map skus on the page to the correct form element name
        my %page_skus = map {
            $_->{'Sku'} => $_->{'Packing Slip Value'}->{'input_name'}
        } @{ $self->mech->as_data->{'variants'} };

        # Map the user-provided skus to form values
        my %form_data;
        for my $sku ( keys %$incoming_skus ) {
            my $element_name = $page_skus{ $sku };
            croak "Can't find SKU [$sku] on the page" unless defined $element_name;

            $form_data{ $element_name } = $incoming_skus->{ $sku };
        }

        return \%form_data;
    }
);



# URI: /GoodsIn/ItemCount
#   get the Goods In - Stock In - Item Count page
__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__goodsin__itemcount',
    page_description => 'Item Count page',
    page_url         => '/GoodsIn/ItemCount',
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__goodsin__itemcount_deliveryid',
    page_description => 'Item Count page',
    page_url         => '/GoodsIn/ItemCount?delivery_id=',
    required_param   => 'Delivery ID'
);

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__goodsin__itemcount_scan',
    scan_description => 'Delivery ID',
    assert_location  => '/GoodsIn/ItemCount'
);

=head2 flow_mech__goodsin__itemcount_submit_counts

Submits the Product Information and Unit Count form on the Goods In/Item Count
page. Note that this method currently doesn't support submitting product info.

You're expected to pass in a hashref with a key 'counts', which should be a
hashref of SKU and count:

 { count => { '080808-123' => 15 } }

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__goodsin__itemcount_submit_counts',
    form_name         => 'frm_item_count',
    form_description  => 'Item Counts',
    assert_location   => qr!^/GoodsIn/ItemCount!,
    transform_fields => sub {
        my ( $self, $args ) = @_;
        my $incoming_skus = $args->{'counts'} || croak "Please provide item counts";

        # Map skus on the page to the correct form element name
        my %page_skus = map {
            $_->{'SKU'} => $_->{'Count'}->{'input_name'}
        } @{ $self->mech->as_data('GoodsIn/ItemCount/SingleResult')->{'counts_form'} };

        # Map the user-provided skus to form values
        my %form_data;
        for my $sku ( keys %$incoming_skus ) {
            my $element_name = $page_skus{ $sku };
            croak "Can't find SKU [$sku] on the page" unless defined $element_name;

            $form_data{ $element_name } = $incoming_skus->{ $sku };
        }

        $form_data{'weight'} = $args->{weight} if defined($args->{weight});

        return \%form_data;
    }
);

=head2 flow_mech__goodsin__qualitycontrol

Quality Control list

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__goodsin__qualitycontrol',
    page_description => 'Quality Control List',
    page_url         => '/GoodsIn/QualityControl',
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__goodsin__qualitycontrol_deliveryid',
    page_description => 'Quality Control page for delivery',
    page_url         => '/GoodsIn/QualityControl?delivery_id=',
    required_param   => 'Delivery ID'
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__goodsin__fasttrack_deliveryid',
    page_description => 'Fast Track QC page for delivery',
    page_url         => '/GoodsIn/QualityControl/FastTrack?delivery_id=',
    required_param   => 'Delivery ID'
);


__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__goodsin__qualitycontrol_submit',
    scan_description => 'Delivery ID',
    assert_location  => '/GoodsIn/QualityControl'
);

=head2 flow_mech__goodsin__qualitycontrol_processitem_submit

Submits data on the quality control item page. There are three logical forms on
this page all submitted by the same form element. You can provide data for these
using C<info>, C<qc>, and C<measurements>.

=head3 info

Partially implemented.

It supports only C<weight> key, that allows to specify product weight value.

We will force storage type to flat if it's setable. If you need
this functionality, how to add it is documented.

=head3 qc

Accepts keys of SKUs mapping to hashrefs, which should contain a 'checked' and
'faulty' key. Also requires a valid 'faulty_container'. eg:

 {
    qc => {
        'faulty_container' => 'M1234567',
        '12345-678' => { checked => 50, faulty => 10 },
        '34567-890' => { checked =>  5, faulty =>  5 }
    }
 }

Note that for vouchers you'll have to pass the voucher name, not its SKU.

=head3 measurements

Accepts keys of variant ids mapping to hashrefs keyed on measurement id
(as provided by $flow->attr__measurements__variant_measurement_values if
using Test::XT::Data::Measurements)

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__goodsin__qualitycontrol_processitem_submit',
    form_name        => 'quality_control',
    form_description => 'Quality Control Results',
    assert_location  => qr'^/GoodsIn/QualityControl',
    transform_fields => sub {
        my ( $self, $args ) = @_;
        my %form_fields;

        # Look for QC fields. This is the same methodology you will need for
        # implementing the other keys.
        if ( exists $args->{'qc'} ) {
            for my $field ( qw/length width height weight/ ) {
                if ( exists $args->{qc}{$field} ) {
                    $form_fields{$field} = delete $args->{qc}{$field};
                }
                # Since a weight is now required to pass validation, add a
                # default one if nothing has been specified (you can still
                # explicitly set undef if you need to)
                elsif ( $field eq 'weight' ){
                    $form_fields{$field} = 1;
                }
            }

            $form_fields{'faulty_container'} =
                delete $args->{'qc'}->{'faulty_container'};

            # Map SKUs to QC IDs
            my $qc_results = $self->mech
                ->as_data('GoodsIn/QualityControl/ProcessItem')->{'qc_results'};
            # We ignore the last row as it's the totals count and has no inputs
            # if we have products - vouchers don't have a totals row, so we
            # need to process all the rows
            my $last_index
                = $qc_results->[0]{SKU} ? $#{$qc_results}-1 : $#{$qc_results};
            my %page_skus = map {
                my $key = $_->{'SKU'}||$_->{Voucher};
                my $id  = $_->{'Counted'}->{'input_name'};
                $id =~ s/.+_//;
                $key => $id;
            } @{$qc_results}[0..$last_index];

            for my $key ( keys %{ $args->{'qc'} } ) {
                my $id = $page_skus{ $key } || croak "Can't find SKU/Voucher [$key] for QC";
                for my $type ( 'checked', 'faulty' ) {
                    $form_fields{ $type . '_' . $id } = $args->{'qc'}->{$key}->{$type};
                }
            }
        }

        if ( exists $args->{'measurements'} ) {
            # Measurements fields
            foreach my $variant ($self->product->variants) {
                next unless ($args->{'measurements'}->{$variant->id});
                foreach my $measurement (@{$self->attr__measurements__measurement_types}) {
                    my $field_name = "measure-".$variant->id."-".$measurement->measurement;
                    my $field_value = $args->{'measurements'}->{$variant->id}->{$measurement->id};
                    $form_fields{$field_name} = $field_value;
                }
            }
        }

        if ( exists $args->{info} ) {
            my %info = %{ $args->{info} };

            $form_fields{$_} = $info{$_} foreach qw/weight/;
        }

        $form_fields{'storage_type'} = $PRODUCT_STORAGE_TYPE__FLAT;
        return \%form_fields;
    }
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__goodsin__fasttrack_submit',
    form_name        => 'fast_track',
    form_description => 'Fast Track QC',
    assert_location  => qr'^/GoodsIn/QualityControl/FastTrack',
    transform_fields => sub {
        my ( $self, $args ) = @_;
        my %form_fields;

        # Look for QC fields. This is the same methodology you will need for
        # implementing the other keys.
        if ( exists $args->{'fast_track'} ) {
            # Map SKUs to QC IDs
            my %page_skus = map {
                my $sku = $_->{'SKU'};
                my $id  = $_->{'Counted'}->{'input_name'};
                $id =~ s/.+_//;
                $sku => $id;
            } @{ $self->mech->as_data->{'fast_track'} };

            # Web form will include all SKUs whether fast_track or not
            #for my $sku ( keys %{ $args->{'fast_track'} } ) {
            for my $sku ( keys %page_skus ) {
                my $id = $page_skus{ $sku } || croak "Can't find SKU [$sku] for QC";
                $form_fields{"fasttrack_$id"}= exists $args->{'fast_track'}->{$sku} ? 'on' : undef;
                $form_fields{"quantity_$id"} = $args->{'fast_track'}->{$sku} || 0;
            }
        }

        return \%form_fields;
    }
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__goodsin__surplus',
    page_description => 'Surplus List',
    page_url         => '/GoodsIn/Surplus',
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__goodsin__surplus_processgroupid',
    page_description => 'Surplus List',
    page_url         => '/GoodsIn/Surplus?process_group_id=',
    required_param   => 'Process Group ID'
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__goodsin__surplus_processgroupid_submit',
    form_name        => 'surplus',
    form_description => 'Surplus Action',
    assert_location  => qr'^/GoodsIn/Surplus',
    transform_fields => sub {
        my ( $self, $args ) = @_;
        my %form_fields;

        # Map SKUs to QC IDs
        my %page_skus = map {
            my $sku = $_->{'Sku'};
            $sku =~ s/ .+//;
            my $id  = $_->{'Accepted'}->{'input_name'};
            $id =~ s/.+_//;
            $sku => $id;
        } @{ $self->mech->as_data('GoodsIn/Surplus/ProcessItem')->{'process_units'} };

        for my $sku ( keys %{ $args } ) {
            my $id = $page_skus{ $sku } || croak "Can't find SKU [$sku] for QC";
            for my $key ( 'accepted', 'rtv' ) {
                $form_fields{ $key . '_' . $id } = $args->{$sku}->{$key};
            }
        }
        return \%form_fields;
    }
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__goodsin__bagandtag',
    page_description => 'Bag and Tag list',
    page_url         => '/GoodsIn/BagAndTag',
);

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__goodsin__bagandtag_submit',
    scan_description => 'Process Group ID',
    assert_location  => '/GoodsIn/BagAndTag'
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__goodsin__bagandtag_processgroupid',
    page_description => 'Bag and Tag Process Item',
    page_url         => '/GoodsIn/BagAndTag?process_group_id=',
    required_param   => 'Process Group ID'
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__goodsin__bagandtag_processgroupid_submit',
    form_name        => 'set_bag_and_tag',
    form_description => 'Confirm Bag and Tag',
    assert_location  => qr!GoodsIn/BagAndTag!,
    transform_fields => sub {{
        bagandtag => 'on'
    }}
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__goodsin__putaway',
    page_description => 'Putaway list',
    page_url         => '/GoodsIn/Putaway',
);

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__goodsin__putaway_submit',
    scan_description => 'Process Group ID',
    assert_location  => '/GoodsIn/Putaway'
);

# URI: /GoodsIn/Putaway?process_group_id=234
#   display the Goods In - Putaway - Process Item page
#
__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__goodsin__putaway_processgroupid',
    page_description => 'Putaway Process Group',
    page_url         => '/GoodsIn/Putaway?process_group_id=',
    required_param   => 'Process Group ID'
);

# URI: /GoodsIn/Putaway?process_group_id=234
#   submit the Goods In - Putaway - Process Item page
#
__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__goodsin__putaway_book_submit',
    form_name        => 'putawayForm',
    form_description => 'Putaway Location',
    assert_location  => qr!^/GoodsIn/Putaway!,
    transform_fields => sub {
        my ( $self, $location, $count ) = @_;

        # Get the correct form element
        my $product =
            $self->mech->as_data('GoodsIn/Putaway/Product')->{'product_list'}->[-1];
        my $location_field = $product->{'Location'}->{'input_name'};
        my $quantity_field = $product->{'Quantity'}->{'input_name'};

        return {
            ( $location ? ($location_field => $location) : () ),
            ( defined($count) ? ($quantity_field => $count) : () ),
        };
    }
);

=head1 flow_mech__goodsin__putaway_book_complete

Hit the complete button, and putaway actually for real

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__goodsin__putaway_book_complete',
    form_name        => 'putawayForm',
    form_button      => 'submit',
    form_description => 'Confirm Putaway',
    assert_location  => qr!^/GoodsIn/Putaway!,
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__goodsin__returns_in',
    page_description => 'Returns In',
    page_url         => '/GoodsIn/ReturnsIn',
);

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__goodsin__returns_in_submit',
    scan_description => 'Return Number',
    assert_location  => '/GoodsIn/ReturnsIn'
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__goodsin__returns_in__book_in',
    form_name        => 'findReturn',
    form_description => 'Book In Item',
    assert_location  => qr!^/GoodsIn/ReturnsIn!,
    transform_fields => sub {
        return { return_sku => $_[1] }
    },
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__goodsin__returns_in__complete_book_in',
    form_name        => sub {
        return $_[0]->mech->find_xpath(
            q{//form[starts-with(@name,'bookInForm')]/@name}
        )->pop->string_value();
    },
    form_description => 'Complete Book In',
    assert_location  => qr!^/GoodsIn/ReturnsIn!,
    transform_fields => sub {
        return { airwaybill => $_[1], email => ($_[2]||'no') }
    },
);

=head2 task__goodsin__returns_in( $shipment_id, \@skus ) : $self

Book in the given skus for a return matching the given shipment.

=cut

sub task__goodsin__returns_in {
    my ( $self, $shipment_id, $skus ) = @_;

    $self->flow_mech__goodsin__returns_in
        ->flow_mech__goodsin__returns_in_submit( $shipment_id );
    $self->flow_mech__goodsin__returns_in__book_in( $_ ) for @$skus;
    return $self->flow_mech__goodsin__returns_in__complete_book_in();
}

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__goodsin__returns_qc',
    page_description => 'Returns QC',
    page_url         => '/GoodsIn/ReturnsQC',
);

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__goodsin__returns_qc_submit',
    scan_description => 'Delivery Number',
    assert_location  => '/GoodsIn/ReturnsQC',
);

=head1 flow_mech__goodsin__returns_qc_process(\%args) : $form_submit_args

Submit all the items on the returns qc form with the same given arguments. The
argument hashref can contain:

=over

=item 'C<decision>' - pass (default) or fail

=item 'C<large_labels>' - how many large labels to print (default 0)

=item 'C<small_labels>' - how many small labels to print (default 0)

=back

If you need to pass different values to the items, use
L<flow_mech__goodsin__returns_qc__process_item_by_item>.

=cut

sub _returns_qc_process_location_qr {
    # The wildcard is to (optionally) match '&submit=Submit+»', and delivery_id
    # can also be an RMA number
    qr{/GoodsIn/ReturnsQC\?.*delivery_id=(?:\d+|\w?\d+-\d+)}
}

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__goodsin__returns_qc__process',
    form_name        => 'qcForm',
    form_description => 'Returns Quality Control',
    assert_location  => _returns_qc_process_location_qr(),
    transform_fields => sub {
        my ( $self, $args ) = @_;

        my $data = $self->mech->as_data('GoodsIn/ReturnsQC/ProcessItem')
            ->{'qc_results'};

        my $return;
        for my $row ( @$data ) {
            my ($row) = grep { ref $_->{Decision} } @{$data||[]} or next;

            $return->{$row->{Decision}{input_name}} = $args->{decision} || 'pass';
            $return->{$row->{'Large Labels'}{input_name}} = $args->{large_labels} || 0;
            $return->{$row->{'Small Labels'}{input_name}} = $args->{small_labels} || 0;
        }
        return $return;
    }
);

=head2 flow_mech__goodsin__returns_qc__process_item_by_item

    $framework->flow_mech__goodsin__returns_qc__process_item_by_item( {
        $return_item's_stock_process_id => {
            decision    => 'pass' || 'fail',
            large_labels=> $number_of_large_labels,     # default is 1
            small_labels=> $number_of_small_labels,     # default is 0
        },
    } );

This will allow the QC'ing of individual items allowing you to either Pass or Fail
them rather than one blanket decision for all.

Pass in a HashRef with the key being the Stock Process Id of the Returned Item along
with a 'decision' of either 'pass' or 'fail'.

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__goodsin__returns_qc__process_item_by_item',
    form_name        => 'qcForm',
    form_description => 'Returns Quality Control',
    assert_location  => _returns_qc_process_location_qr(),
    transform_fields => sub {
        my ( $self, $args ) = @_;

        my $data;
        foreach my $process_id ( keys %{ $args } ) {
            $data->{ "qc_${process_id}" }   = $args->{ $process_id }{decision};
            $data->{ "large-${process_id}" }= $args->{ $process_id }{large_labels} || 1;
            $data->{ "small-${process_id}" }= $args->{ $process_id }{small_labels} || 0;
        }

        return $data;
    }
);

=head2 flow_mech__goodsin__returns_faulty

Go to the 'Goods In -> Returns Faulty' page which allows users to
make decisions on items that have 'Failed' Returns QC.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__goodsin__returns_faulty',
    page_description => 'Returns Faulty',
    page_url         => '/GoodsIn/ReturnsFaulty',
);

=head2 flow_mech__goodsin__returns_faulty_submit

    $framework->flow_mech__goodsin__returns_faulty_submit( $stock_process_group );

Scan in the Process Group of the Item you wish to make the decision on. All decisions
are made on one Failed Item at a time not groups of Items.

=cut

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__goodsin__returns_faulty_submit',
    scan_description => 'Process Group',
    assert_location  => '/GoodsIn/ReturnsFaulty'
);

=head2 flow_mech__goodsin__returns_faulty_decision('accept'|'reject'|'rtv_repair', $item_fault_type_id? ) : $flow

This will either 'Accept', 'Reject' or 'RTV Repair' a Failed QC item.

After this decision has been made the user will be on the next page which is
handled by 'flow_mech__goodsin__returns_faulty_process' which decides what to
do with the Stock, that page doesn't have to be processed immediately in order
to finish off a Customer's return and release any Refund payments. See the POD
for 'flow_mech__goodsin__returns_faulty_process' on the different ways that
page can be reached. If you pass rtv_repair you can either optionally pass a
fault type (will default to 'Various')

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__goodsin__returns_faulty_decision',
    form_name        => 'faultyReturn',
    form_description => 'Returns Faulty Item Decision',
    assert_location  => qr{/GoodsIn/ReturnsFaulty},
    transform_fields => sub {
        my ( $self, $decision, $item_fault_type_id ) = @_;

        return {
            decision => lc( $decision ),
            (
                $decision eq 'rtv_repair'
              ? ( ddl_item_fault_type => $item_fault_type_id // $ITEM_FAULT_TYPE__VARIOUS )
              : ()
            )
        }
    }
);

=head2 flow_mech__goodsin__returns_faulty_process

    $framework->flow_mech__goodsin__returns_faulty_process( $decision_of_where_to_send_stock );

This decides what to do about the Stock after the decision to 'Accept' or 'Reject' the item has
been done (flow_mech__goodsin__returns_faulty_decision). The allowable decisions are:

    * Return to Stock
    * Return to Vendor - TODO: this isn't supported by this test as more information is
                               required to be submitted in the form if this option is chosen
    * Return to Customer
    * Dead Stock

This page will be reached straight after an 'Accept' or 'Reject' decision
(flow_mech__goodsin__returns_faulty_decision ) has been made or if it isn't done then
the Item will appear on the front list page (flow_mech__goodsin__returns_faulty) in the
table at the bottom of the page headed: 'Faulty Returns Awaiting Process', where the
Process Group can be scanned in (flow_mech__goodsin__returns_faulty_submit) and this
page will be reached. This allows the decision to 'Accept' or 'Reject' a Customer's item
to be seperated from what happens to the stock afterwards, as the result of the 'Accept'
decision will immediately release the Customer's Refund so this shouldn't be held up
just because we can't decide what to do with the Stock.

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__goodsin__returns_faulty_process',
    form_name        => 'faultyReturn',
    form_description => 'Returns Faulty Stock Decision',
    assert_location  => qr{/GoodsIn/ReturnsFaulty},
    transform_fields => sub {
        my ( $self, $decision ) = @_;

        my %decision_map = (
            'return to stock'   => 'rts',
            'return to vendor'  => 'rtv',
            'return to customer'=> 'rtc',
            'dead stock'        => 'dead',
        );
        # translate the decision passed in using the
        # map, else use whatever is passed in
        $decision   = $decision_map{ lc( $decision ) } // $decision;

        return {
            decision => $decision,
        }
    }
);


=head2 flow_mech__goodsin__vendor_sample_in

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__goodsin__vendor_sample_in',
    page_description => 'Vendor Sample in DC',
    page_url         => '/GoodsIn/VendorSampleIn',
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__goodsin__vendor_sample_in_submit',
    form_name        => sub { 'skuForm_'.$_[1]->{channel_id} },
    form_description => 'Vendor Sample in DC scan',
    assert_location  => '/GoodsIn/VendorSampleIn',
    transform_fields => sub {
        my ( $self, $args ) = @_;

        return {
            psku => $args->{sku},
            channel_id => $args->{channel_id},
        }
    },
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__goodsin__vendor_sample_in__process',
    form_name        => 'f_form',
    form_description => 'Vendor Sample Quality Control',
    assert_location  => '/GoodsIn/VendorSampleIn',
    transform_fields => sub {

        my ( $self, $args ) = @_;

        my $decision = ucfirst($args->{decision} || 'pass');
        my $large_lbls = $args->{large_labels} || 0;
        my $small_lbls = $args->{small_labels} || 0;

        my $data=$self->mech->as_data('GoodsIn/VendorSampleIn/ProcessItem')
            ->{'qc_results'}[0];

        my $ret = {
            $data->{$decision}{input_name} => $data->{$decision}{input_value},
            $data->{Large}{input_name} => $large_lbls,
            $data->{Small}{input_name} => $small_lbls,
        };

        if ($decision eq 'Faulty') {
            my $select = $data->{'Faulty Reason'};
            my $faulty_reason = $args->{faulty_reason} || 'unknown';
            my ($faulty_reason_elem) = (grep { lc($_->[1]) eq lc($faulty_reason) }
                                            @{ $select->{select_values} } );
            if (!$faulty_reason_elem) {
                croak qq{Can't find faulty reason $faulty_reason};
            }
            $ret->{ $select->{select_name} } = $faulty_reason_elem->[0];
        }

        return $ret;
    }
);

__PACKAGE__->create_fetch_method(
    method_name      => 'mech__goodsin__returns_delivery',
    page_description => 'Returns Delivery',
    page_url         => '/GoodsIn/ReturnsArrival/Delivery',
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__goodsin__returns_delivery_create_delivery',
    form_name        => 'create_delivery',
    form_description => 'Create Delivery',
    assert_location  => '/GoodsIn/ReturnsArrival/Delivery',
);

__PACKAGE__->create_fetch_method(
    method_name      => 'mech__goodsin__returns_delivery_id',
    page_description => 'Returns Delivery',
    page_url         => '/GoodsIn/ReturnsArrival/Delivery/',
    required_param   => 'Return Delivery ID',
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__goodsin__returns_delivery_id_awb_submit',
    form_name        => 'enter_awb',
    form_description => 'AWB',
    assert_location  => qr!^/GoodsIn/ReturnsArrival/Delivery/\d+!,
    transform_fields => sub { return { awb => $_[1], }; },
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__goodsin__returns_delivery_id_confirm_submit',
    form_name        => 'confirm_delivery',
    form_button      => 'submit',
    form_description => 'Returns Delivery Confirm',
    assert_location  => qr!^/GoodsIn/ReturnsArrival/Delivery/\d+!,
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__goodsin__returns_arrival_submit_details',
    form_name        => 'enter_details',
    form_button      => 'submit',
    form_description => 'Returns Arrival Details Submit',
    assert_location  => qr!^/GoodsIn/ReturnsArrival/Arrival/\d+!,
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__goodsin__returns_arrival_cancel',
    form_name        => 'cancel',
    form_button      => 'submit',
    form_description => 'Returns Arrival Details Cancel',
    assert_location  => qr!^/GoodsIn/ReturnsArrival/Arrival/\d+!,
);

__PACKAGE__->create_fetch_method(
    method_name      => 'mech__goodsin__cancel_delivery',
    page_description => 'Cancel Delivery',
    page_url         => '/GoodsIn/DeliveryCancel',
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__goodsin__cancel_delivery_manual_submit',
    form_name        => 'manual_cancel',
    form_description => 'Manual Cancel Delivery',
    assert_location  => '/GoodsIn/DeliveryCancel',
    transform_fields => sub {
        return { cancel_delivery_number => $_[1] };
    },
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__goodsin__cancel_delivery_list_submit',
    form_name        => sub { "list_cancel_$_[1]{channel_id}" },
    form_description => 'List Cancel Delivery',
    assert_location  => '/GoodsIn/DeliveryCancel',
    transform_fields => sub {
        my $delivery_id = $_[1]{delivery_id};
        $delivery_id = $delivery_id && ref $delivery_id eq 'ARRAY'
                     ? $delivery_id
                     : [$delivery_id];
        return { map {; "cancel-$_" => $_ } @$delivery_id };
    },
);

# Putaway Preparation
__PACKAGE__->create_fetch_method(
    method_name      => 'mech__goodsin__putaway_prep',
    page_description => 'Putaway Prep',
    page_url         => '/GoodsIn/PutawayPrep',
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__goodsin__putaway_prep_submit',
    form_name        => 'putaway_prep',
    form_description => 'Putaway Prep',
    assert_location  => '/GoodsIn/PutawayPrep',
    form_button      => 'scan',
    transform_fields => sub {
        my ( $self, $name, $value ) = @_;
        return { $name => $value };
    },
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__goodsin__putaway_prep_complete_container',
    form_name        => 'putaway_prep',
    form_description => 'Putaway Prep',
    assert_location  => '/GoodsIn/PutawayPrep',
    form_button      => 'container_complete',
    transform_fields => sub {
        my ( $self, $args ) = @_;
        return $args;
    },
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__goodsin__putaway_prep_change_scan_mode',
    form_name        => 'putaway_prep',
    form_description => 'Putaway Prep',
    assert_location  => '/GoodsIn/PutawayPrep',
    form_button      => 'toggle_scan_mode',
);

# Putaway Prep Admin
#
__PACKAGE__->create_fetch_method(
    method_name      => 'mech__goodsin__putaway_prep_admin',
    page_description => 'Putaway Prep Admin',
    page_url         => '/GoodsIn/PutawayPrepAdmin',
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__goodsin__putaway_prep_admin_remove_group',
    form_name        => sub {
        my ($self, $group_id) = @_;
        return "remove_problem_$group_id";
    },
    form_description => 'Putaway Prep Admin Remove',
    assert_location  => '/GoodsIn/PutawayPrepAdmin',
    form_button      => 'remove',
);

# Putaway Problem Resolution
#
__PACKAGE__->create_fetch_method(
    method_name      => 'mech__goodsin__putaway_problem_resolution',
    page_description => 'Putaway Problem Resolution',
    page_url         => '/GoodsIn/PutawayProblemResolution',
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__goodsin__putaway_problem_resolution_submit',
    form_name        => 'putaway_problem_resolution',
    form_description => 'Putaway problem resolution container scan form',
    assert_location  => '/GoodsIn/PutawayProblemResolution',
    form_button      => 'scan',
    transform_fields => sub {
        my ( $self, $args ) = @_;
        return $args;
    },
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__goodsin__putaway_problem_resolution_reputaway_submit',
    form_name        => 'putaway_problem_resolution_reputaway_prep',
    form_description => 'Form for re-completion of putaway prep process',
    assert_location  => '/GoodsIn/PutawayProblemResolution',
    form_button      => 'pprep_scan',
    transform_fields => sub {
        my ( $self, $args ) = @_;
        return $args;
    },
);

# Changes scanning mode of re-putaway prep form on putaway problem resolution page.
# There are two modes: 1) scan SKUs from faulty container into new one,
# 2) scan SKUs out of new container back to faulty one.
#
__PACKAGE__->create_form_method(
    method_name      => 'mech__goodsin__putaway_problem_resolution_reputaway_toggle_scan_mode',
    form_name        => 'putaway_problem_resolution_reputaway_prep',
    form_description => 'Form for re-completion of putaway prep process',
    assert_location  => '/GoodsIn/PutawayProblemResolution',
    form_button      => 'toggle_scan_mode',
    transform_fields => sub {
        my ( $self, $args ) = @_;
        return $args;
    },
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__goodsin__putaway_problem_resolution_reputaway_complete_container',
    form_name        => 'putaway_problem_resolution_reputaway_prep',
    form_description => 'Form for re-completion of putaway prep process',
    assert_location  => '/GoodsIn/PutawayProblemResolution',
    form_button      => 'container_complete',
    transform_fields => sub {
        my ( $self, $args ) = @_;
        return $args;
    },
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__goodsin__putaway_problem_resolution_mark_faulty_container_as_empty',
    form_name        => 'putaway_problem_resolution_container_is_empty',
    form_description => 'Form for confirming faulty container as empty',
    assert_location  => '/GoodsIn/PutawayProblemResolution',
    form_button      => 'empty_faulty_container',
    transform_fields => sub {
        my ( $self, $args ) = @_;
        return $args;
    },
);

# Putaway prep from Packing Exception methods
#
__PACKAGE__->create_fetch_method(
    method_name      => 'mech__goodsin__putaway_prep_packing_exception',
    page_description => 'Putaway Prep for stock from special locations',
    page_url         => '/GoodsIn/PutawayPrepPackingException',
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__goodsin__putaway_prep_packing_exception_submit',
    form_name        => 'putaway_prep_packing_exception',
    form_description => 'Putaway prep Packing Exception container scan form',
    assert_location  => '/GoodsIn/PutawayPrepPackingException',
    form_button      => 'scan',
    transform_fields => sub {
        my ( $self, $args ) = @_;
        return $args;
    },
);

# Changes scanning mode at putaway prep for Packing exception page.
# There are two modes: 1) scan SKUs into container,
# 2) scan SKUs out of container.
#
__PACKAGE__->create_form_method(
    method_name      => 'mech__goodsin__putaway_prep_packing_exception_toggle_scan_mode',
    form_name        => 'putaway_prep_packing_exception',
    form_description => 'Putaway prep Packing Exception scanning form',
    assert_location  => '/GoodsIn/PutawayPrepPackingException',
    form_button      => 'toggle_scan_mode',
    transform_fields => sub {
        my ( $self, $args ) = @_;
        return $args;
    },
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__goodsin__putaway_prep_packing_exception_complete_container',
    form_name        => 'putaway_prep_packing_exception',
    form_description => 'Putaway prep Packing Exception scanning form',
    assert_location  => '/GoodsIn/PutawayPrepPackingException',
    form_button      => 'container_complete',
    transform_fields => sub {
        my ( $self, $args ) = @_;
        return $args;
    },
);


1;
