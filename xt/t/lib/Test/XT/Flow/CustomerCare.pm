package Test::XT::Flow::CustomerCare; ## no critic(ProhibitExcessMainComplexity)

use NAP::policy     qw( test role );

use XTracker::Constants::FromDB ':customer_issue_type';

requires 'mech';
requires 'note_status';
requires 'config_var';

with 'Test::XT::Flow::AutoMethods';

# The middle part of the URL here is unimportant - these are equivalent:
#   /CustomerCare/CustomerSearch/OrderView?order_id=1254765
#   /CustomerCare/OrderSearch/OrderView?order_id=1254765
# For consistency, we knock it out of the method names, and use CustomerSearch
# in our URLs. You'll need to make sure you're logged in to be able to use
# 'Customer Care/Customer Search' as permissions.

#
# Note! CancelShipmentItem URLs have 'orders_id=...' rather
# than 'order_id=...', for no readily apparent reason. Just in case
# you decide to match on that...
#

=head1 METHODS

=head2 flow_mech__customercare__orderview

    Fetch the CustomerCare/CustomerSearch/OrderView page with C<order_id>
    as the required parameter.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__customercare__orderview',
    page_description => 'Order View Page',
    page_url         => '/CustomerCare/CustomerSearch/OrderView?order_id=',
    required_param   => 'Order ID'
);

=head2 flow_mech__customercare_orderview_status_check

    Looks at the order items status and compares to passed-in manifest

=cut

sub flow_mech__customercare__orderview_status_check {
    my ( $self, $order_id, $manifest, $name ) = @_;
    my @items_expected = sort { $a->[0] cmp $b->[0] } @$manifest;

    $self->flow_mech__customercare__orderview( $order_id );
    my @items_received =
        sort { $a->[0] cmp $b->[0] }
        map { [ $_->{'SKU'}, $_->{'Status'} ] }
        @{$self->mech->as_data->{'shipment_items'}};

    eq_or_diff( \@items_received, \@items_expected, $name );

}

=head2 flow_mech__customercare_orderview_delivery_signature_submit

This will change the Delivery Signature Flag on the Order View Page.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare_orderview_delivery_signature_submit',
    form_name         => sub {
                my ( $self, $shipment_id )  = @_;
                return "edit_signature_form_${shipment_id}";
            },
    form_description  => 'delivery Signature change',
    assert_location   => qr!^/CustomerCare/[^/]*Search/OrderView!,
    transform_fields => sub {
        my ( $self, $shipment_id, $state )  = @_;

        # check you can edit the value in the page
        my $details = $self->mech->as_data()->{meta_data}{'Shipment Details'};
        if ( !exists( $details->{'Signature upon Delivery Required'} )
             || !$details->{'Signature upon Delivery Required'}{editable} ) {
            croak( "Can't Edit 'Delivery Signature' field for Shipment Id: $shipment_id" );
        }

        return {
            signature_flag  => ( lc($state) eq 'yes' ? 1 : 0 ),
        },
    },
);

=head2 flow_mech__customercare_orderview_recipient_email_submit

     This will Update the Recipient Email for Virtual Gift Card on order View Page

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare_orderview_recipient_email_submit',
    form_name         => 'email_preview_form',
    form_description  => 'Recipient Email change',
    assert_location   => qr!^/CustomerCare/[^/]*Search/OrderView!,
    transform_fields => sub {
        my ( $self, $item_id, $email )  = @_;

        return {
            "recipient_email_${item_id}"  => $email,
        },
    },
);

=head2 flow_mech__customercare__orderview__send_order_status_submit

     This will Send the Order Status Message via AMQ for an Order.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare__orderview__send_order_status_submit',
    form_name         => 'order_status_message_form',
    form_description  => 'Send Order Status Message',
    assert_location   => qr!^/CustomerCare/[^/]*Search/OrderView!,
);


=head2 flow_mech__customercare__view_status_log

This will go to the 'View Status Log' left hand menu link and show the Various Stauls Logs

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__view_status_log',
    link_description => 'View Status Log',
    find_link        => { text => 'View Status Log' },
    assert_location  => qr!^/CustomerCare/[^/]*Search/OrderView!,
);

=head2 flow_mech__customercare__customerview

    Fetch the CustomerCare/CustomerSearch/OrderView page with C<order_id>
    as the required parameter.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__customercare__customerview',
    page_description => 'Customer View Page',
    page_url         => '/CustomerCare/CustomerSearch/CustomerView?customer_id=',
    required_param   => 'Customer ID'
);

=head2 flow_mech__customercare__customerview_update_category

Changes the Customer Category.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare__customerview_update_category',
    form_name         => 'marketingForm',
    form_description  => 'customer category',
    assert_location   => qr!^/CustomerCare/[^/]*Search/CustomerView\?customer_id=\d+!,
    transform_fields => sub {
        my ( $self, $category ) = @_;

        # check that you can edit the field on the page, Category should be a HASH ref if you can
        my $data    = $self->mech->as_data->{page_data}{customer_details}[0];
        if ( ref( $data->{Category} ) ne 'HASH' ) {
            croak "Can't edit 'Customer Category' there is no '<SELECT>' field of categories in the page.";
        }
        my @values  = @{ $data->{Category}{select_values} };

        # find the cateory that was passed in from the list of values in the page
        my ( $to_use )  = grep { $_->[0] eq $category || $_->[1] eq $category } @values;
        if ( !$to_use ) {
            croak "Couldn't find the Category passed in: $category in the 'category_id' field list of values";
        }

        return { category_id => $to_use->[0] };
    }
);

=head2 flow_mech__customercare__customerview_update_options

Submits the form in the 'Customer Options' part of the Page.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare__customerview_update_options',
    form_name         => 'customerOptions',
    form_button       => 'update_marketing_options',
    form_description  => 'Marketing Options',
    assert_location   => qr!^/CustomerCare/[^/]*Search/CustomerView\?customer_id=\d+!,
    transform_fields => sub {
        my ( $self, $option )   = @_;
        return $option;
    }
);

=head2 flow_mech__customercare__update_contact_options

    $framework->flow_mech__customercare__update_contact_options( {
                                                            subject_id => {
                                                                method_id => TRUE or FALSE,
                                                                ...
                                                            },
                                                            ...
                                                        } );

Allows the changing of the 'Order Contact Options' in both the Customer View &
Order View page for many Correspondence Subjects and Correspondence Methods that
are in the form.

=cut

# to return the FORM name for 'flow_mech__customercare__update_contact_options'
# which is used in a couple of places
sub _update_contact_options_form_name {
    my ( $self, $id )   = @_;
    if ( $self->mech->uri =~ m{/CustomerView} ) {
        return 'contactOptions';
    }
    elsif ( $self->mech->uri =~ m{/OrderView} ) {
        return 'OrderContactOptions';
    }
    else {
        die "Don't Know what FORM to give for page: ".$self->mech->uri;
    }
}

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare__update_contact_options',
    form_name         => sub {
            my $self    = shift;
            return $self->_update_contact_options_form_name();
        },
    form_button       => sub {
            my ( $self, $id )   = @_;
            if ( $self->mech->uri =~ m{/CustomerView} ) {
                return 'update_contact_options';
            }
            elsif ( $self->mech->uri =~ m{/OrderView} ) {
                return 'update_order_contact_options';
            }
            else {
                die "Don't Know what BUTTON to give for page: ".$self->mech->uri;
            }
        },
    form_description  => 'Order Contact Options',
    assert_location   => qr!^/CustomerCare/[^/]*Search/(Customer|Order)View\?\w+_id=\d+!,
    transform_fields => sub {
        my ( $self, $args ) = @_;

        my $mech    = $self->mech;

        # check that you can edit options in the form
        my $data    = $mech->as_data->{page_data}{contact_options}{data};
        if ( grep { ref( $_ ) ne 'HASH' } values %{ $data } ) {
            die "Can't Edit Options in FORM";
        }

        # use the correct FORM in the page
        $mech->form_name( $self->_update_contact_options_form_name() );

        # now tick/untick the checkboxes in the FORM
        foreach my $subject_id ( keys %{ $args } ) {
            my $field_name  = "csm_subject_method_${subject_id}";
            while ( my ( $method_id, $setopt ) = each %{ $args->{ $subject_id } } ) {
                # use 'tick' and 'untick' because setting the fields
                # manually doesn't work properly with checkboxes
                (
                    $setopt
                    ? $mech->tick( $field_name, $method_id )
                    : $mech->untick( $field_name, $method_id )
                );
            }
        }

        return;
    }
);

=head2 flow_mech__customercare__cancel_shipment_item

    Follow the 'Cancel Shipment Item' link on a CustomerCare/...Search/OrderView page.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__cancel_shipment_item',
    link_description => 'Cancel Shipment Item',
    find_link        => { text => 'Cancel Shipment Item' },
    assert_location  => qr!^/CustomerCare/[^/]*Search/OrderView!,
);

=head2 flow_mech__customercare__size_change

    Follow the 'Size Change' link on a CustomerCare/...Search/OrderView page.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__size_change',
    link_description => 'Size Change',
    find_link        => { text => 'Size Change' },
    assert_location  => qr!^/CustomerCare/[^/]*Search/OrderView!,
);

=head2 flow_mech__customercare__size_change_submit

Post to the 'Size Change' form, using the parameters provided.

You must provide a list of array-refs, where the array-ref has two items in it:

- A shipment_item_id or SKU

- The replacement SKU

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare__size_change_submit',
    form_name         => 'sizeChangeForm',
    form_description  => 'item size change',
    assert_location   => qr!^/CustomerCare/[^/]*Search/SizeChange!,
    transform_fields => sub {
        my ( $self, @items ) = @_;
        my $data = $self->mech->as_data();

        # First let's parse some useful information out of the page. I want a
        # list of existing SIDs, and a mapping of SKUs->SIDs.
        my ( %sids, %skus, %exchanges );
        for my $row ( @{ $data->{'size_change_form'}->{'select_items'} } ) {
            my $sku = $row->{'SKU'};
        next unless ref $row->{'select_item'};
            my ($sid) = $row->{'select_item'}->{'name'} =~ m/(\d+)/;

            $sids{ $sid }++;
            $skus{ $sku } = $sid;

            my %item_exchanges = map {
                my $value = $_->{'value'};
                my ($pid) = $value =~ m/_(\d+\-\d+)$/g;
                ($pid => $value)
            } @{$row->{'change_to'}->{'values'}};
            $exchanges{ $sid } = \%item_exchanges;
        }

        # Go through the list we were given, and change it in to reasonable
        # fields...
        my %fields;
        for my $item ( @items ) {
            my ( $id, $to ) = @$item;

            my $sid = $skus{$id} || $id;
            croak "Couldn't find a row matching $id" unless $sids{ $sid };

            my $target_id = $exchanges{ $sid }->{ $to };
            croak "Couldn't find an exchange matching $to"
                unless $target_id;

            $fields{'item-' . $sid} = 1;
            $fields{'exch-' . $sid} = $target_id;
        }
        return \%fields;
    }
);


=head2 flow_mech__customercare__size_change_email_submit

Submits the change email customer page. To be called after
C<flow_mech__customercare__size_change_submit>. Puts dummy values in the form,
currently.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare__size_change_email_submit',
    form_name         => 'sizeChangeForm',
    form_description  => 'exchange item with customer email',
    assert_location   => [
        qr!^/CustomerCare/[^/]*Search/CancelShipmentItem!,
        qr!^/CustomerCare/[^/]*Search/SizeChange!,
    ],
    transform_fields => sub {
        my %fields = map {; "email_$_" => 'test@example.com' }
            (qw/to from replyto/);
        $fields{'send_email'} = 'yes';
        return \%fields;
    }
);


=head2 flow_mech__customercare__cancel_item_submit

Cancel items from the 'Cancel Shipment Item' form. Provide a list of items to
cancel. Each item should either be a string identifying the product, or an
arrayref whose first item is the identifier, and whose second item is the
reason. The identifier can either by the shipment_item_id, or a SKU (if there
are more than one items with that SKU, a random one is cancelled).

The reason should be a regex that matches a reason in the provided dropdown.
We default to qr/^Other/ if you haven't provided one.

This is probably best shown with an example:

 $framework->flow_mech__customercare__cancel_item_submit(
    '32388-012', # A SKU. We look for a '-' to identify as a SKU
    '3073872',   # An item ID
    ['32388-012' => qr/^Stock discrepancy/], # Explicit reason
    [3073872     => qr/DDU/ ]
 );

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare__cancel_item_submit',
    form_name         => 'cancelForm',
    form_description  => 'item cancellation',
    assert_location   => qr!^/CustomerCare/[^/]*Search/CancelShipmentItem!,
    transform_fields => sub {
        my ( $self, @items ) = @_;

        # First let's parse some useful information out of the page. I want a
        # list of possible cancellation reasons, a list of existing SIDs, and
        # a mapping of SKUs->SIDs.
        my $data = $self->mech->as_data();

        my ( $reason_hash ) = grep { ref($_->{'reason_for_cancellation'}) } @{ $data
            ->{'cancel_item_form'}
            ->{'select_items'}
        };

        my %reasons = map {
            $_->{'name'} => $_->{'value'}
        } @{ $reason_hash->{'reason_for_cancellation'} };

        my ( %sids, %skus );
        for my $row ( @{ $data->{'cancel_item_form'}->{'select_items'} } ) {
            my $sku = $row->{'PID'};
            next unless ref $row->{'select_item'}; # already cancelled
            my ($sid) = $row->{'select_item'}->{'name'} =~ m/(\d+)/;

            $sids{ $sid }++;
            $skus{ $sku } = $sid;
        }

        # Go through the list we were given, and change it in to reasonable
        # fields...
        my %fields;
        for my $item ( @items ) {
            my ( $id, $reason ) = ref($item) ? @$item : ( $item );
            $reason ||= qr/Order/;

            my $sid = $skus{$id} || $id;
            croak "Couldn't find a row matching $id" unless $sids{ $sid };

            my ($reason_id) = map {
                my $r = $_;
                if ( $r =~ $reason ) {
                    $reasons{$r};
                } else {
                    ()
                }
            } keys %reasons;
            croak "Couldn't find a reason matching $reason" unless $reason_id;

            $fields{'item-' . $sid} = 1;
            $fields{'reason-' . $sid} = $reason_id;
        }
        return \%fields;
    }
);

=head2 flow_mech__customercare__cancel_item_email_submit

Submits the cancel-item email customer page. To be called after
C<flow_mech__customercare__cancel_order_submit>. Puts dummy values in the form,
currently.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare__cancel_item_email_submit',
    form_name         => 'cancelForm',
    form_description  => 'cancel item with customer email',
    assert_location   => qr!^/CustomerCare/[^/]*Search/CancelShipmentItem!,
    transform_fields => sub {
        my ( $self, $args ) = @_;

        return $args if $args;

        my %fields = map {; "email_$_" => 'test@example.com' }
            (qw/to from replyto/);
        $fields{'send_email'} = 'no';
        return \%fields;
    }
);

=head2 flow_mech__customercare__order_view_cancel_order

Follow the 'Cancel Order' link from Order View

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__order_view_cancel_order',
    link_description => 'Cancel Order',
    find_link        => { text => 'Cancel Order' },
    assert_location  => qr!^/CustomerCare/[^/]*Search/OrderView!,
);

=head2 flow_mech__customercare__cancel_order

Need to get to an order to cancel it, and don't want to use lo-fi
C<flow_mech__customercare__order_view_cancel_order>? You must pass in a sole
order id.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__customercare__cancel_order',
    page_description => 'Cancel Order Page',
    page_url         => '/CustomerCare/OrderSearch/CancelOrder?orders_id=',
    required_param   => 'Order ID'
);

=head2 flow_mech__customercare__cancel_order_submit

Submits the cancel order form. Reason is, for now, hard-coded to 'OTHER'.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare__cancel_order_submit',
    form_name         => 'cancelOrder',
    form_description  => 'cancel order',
    assert_location   => qr!^/CustomerCare/[^/]*Search/CancelOrder!,
    transform_fields => sub {
        { cancel_reason_id =>
            $_[0]->const('CUSTOMER_ISSUE_TYPE__8__OTHER') }
    }
);

=head2 flow_mech__customercare__cancel_order_email_submit

Submits the cancel-order email customer page. To be called after
C<flow_mech__customercare__cancel_order_submit>. Puts dummy values in the form,
currently.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare__cancel_order_email_submit',
    form_name         => 'cancelOrder',
    form_description  => 'cancel order with customer email',
    assert_location   => qr!^/CustomerCare/[^/]*Search/CancelOrder!,
    transform_fields => sub {
        my ( $self, $args ) = @_;

        return $args if $args;

        my %fields = map {; "email_$_" => 'test@example.com' }
            (qw/to from replyto/);
        $fields{'send_email'} = 'no';
        return \%fields;
    }
);

=head2 task__mech__cancel_order($order_row) : $self

Cancel the $order_row, and test that is succeeded.

=cut

sub task__mech__cancel_order {
    my ($self, $order_row) = @_;

    # TODO: find all callers of this and replace with task__ call
    $self
        ->flow_mech__customercare__cancel_order( $order_row->id )
        ->flow_mech__customercare__cancel_order_submit()
        ->flow_mech__customercare__cancel_order_email_submit();

     is(
         $self->mech->as_data->{'meta_data'}->{'Order Details'}->{'Order Status'},
         "Cancelled",
         "Order (" . $order_row->id . ") has been cancelled",
     );

    return $self;
}

=head2 flow_mech__customercare__hold_shipment

Follow the Hold Shipment link from the Customer Care order view page.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__hold_shipment',
    link_description => 'Hold Shipment',
    find_link        => { text => 'Hold Shipment' },
    assert_location  => qr!^/CustomerCare/[^/]*Search/OrderView!,
);

=head2 flow_mech__customercare__hold_click_on_shipment_id

    $framework->flow_mech__customercare__hold_click_on_shipment_id( $shipment_id );

This will click on shipment_id on the Shipment Hold page where there are multiple shipments to choose
from to put on hold.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__hold_click_on_shipment_id',
    link_description => 'Shipment Id',
    transform_fields => sub {
                    my ( $mech, $shipment_id )   = @_;
                    return { text => $shipment_id };
                },
    assert_location  => qr!^/CustomerCare/[^/]*Search/HoldShipment!,
);

=head2 flow_mech__customercare__hold_shipment_submit

Submit the 'Hold Shipment' form with default values.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare__hold_shipment_submit',
    form_name         => 'holdForm',
    form_description  => 'hold shipment',
    assert_location   => qr!^/CustomerCare/[^/]*Search/HoldShipment!,
    transform_fields => sub {
        my ( $self, $args ) = @_;

        return { reason => $_[0]->const('SHIPMENT_HOLD_REASON__OTHER') }
                        if ( !$args );

        return $args;
    }
);

=head2 flow_mech__customercare__hold_release_shipment

Follow the Release Shipment link from the Hold Shipment page.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__hold_release_shipment',
    link_description => 'Release Hold Shipment',
    find_link        => { text => 'Release Shipment' },
    assert_location  => qr!^/CustomerCare/[^/]*Search/HoldShipment!,
);

=head2 flow_mech__customercare__put_shipment_on_hold__wrapper

    $framework = $framework->flow_mech__customercare__put_shipment_on_hold_wrapper( $order_id, {
        # required if Order has more than one Shipment
        shipment_id => $shipment_id,

        # optional
        reason      => $SHIPMENT_HOLD_REASON__ID,
        comment     => 'A Comment for the Hold Reason',
    } );

This is a wrapper used to put a Shipment on Hold for a given Reason (defaults to
'Other' if none specified). The Framework will be left on the Order View page once
completed. Need to pass the Order Id and if the Order has more than one Shipment
then the Shipment Id needs to be passed in the args as well.

It returns the Framework so this can be chained.

=cut

sub flow_mech__customercare__put_shipment_on_hold__wrapper {
    my ( $self, $order_id, $args ) = @_;

    my $shipment_id = delete $args->{shipment_id};

    $self->flow_mech__customercare__orderview( $order_id )
            ->flow_mech__customercare__hold_shipment;

    # click on the Shipment if there is a List of Shipments to choose from
    $self->flow_mech__customercare__hold_click_on_shipment_id( $shipment_id )
            if ( $self->mech->content( format => 'text' ) =~ /Select Shipment/ );

    $self->flow_mech__customercare__hold_shipment_submit( $args );

    return $self;
}

=head2 flow_mech__customercare__release_shipment_hold__wrapper

    $framework = $framework->flow_mech__customercare__release_shipment_hold_wrapper(
        $order_id,
        # required if Order has more than one Shipment
        $shipment_id,
    );

This is a wrapper which will realease a Shipment that is on Hold. The Framework will be left
on the Order View page once completed. Need to pass the Order Id and if the Order has more
than one Shipment then the Shipment Id needs to be passed in as the second parameter.

It returns the Framework so this can be chained.

=cut

sub flow_mech__customercare__release_shipment_hold__wrapper {
    my ( $self, $order_id, $shipment_id ) = @_;

    $self->flow_mech__customercare__orderview( $order_id )
            ->flow_mech__customercare__hold_shipment;

    # click on the Shipment if there is a List of Shipments to choose from
    $self->flow_mech__customercare__hold_click_on_shipment_id( $shipment_id )
            if ( $self->mech->content( format => 'text' ) =~ /Select Shipment/ );

    $self->flow_mech__customercare__hold_release_shipment;

    return $self;
}

=head2 flow_mech__customercare__create_shipment

    Follow the 'Create Shipment Item' link on a CustomerCare/...Search/OrderView page.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__create_shipment',
    link_description => 'Create Shipment',
    find_link        => { text => 'Create Shipment' },
    assert_location  => qr!^/CustomerCare/[^/]*Search/OrderView!,
);

=head2 flow_mech__customercare__create_shipment_select_shipment

    Will pick a Shipment that is listed after clicking on the 'Create Shipment' page, if the Order has multiple Dispatched Shipments.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__create_shipment_select_shipment',
    link_description => 'Create Shipment - Select Shipment',
    transform_fields => sub {
                        my ( $self, $shipment_id )  = @_;
                        return { text => $shipment_id };
                    },
    assert_location  => qr!^/CustomerCare/[^/]*Search/CreateShipment\?order_id=\d+!,
);

=head2 flow_mech__customercare__create_shipment_submit

Submit the 'Create Shipment' form, using Re-Shipment as reason.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare__create_shipment_submit',
    form_name         => 'createShipment',
    form_description  => 'create shipment',
    form_button  => 'submit',
    assert_location   => qr!^/CustomerCare/[^/]*Search/CreateShipment\?order_id=\d+&shipment_id=\d+!,
    transform_fields => sub {
        my ( $self, $type )     = @_;

        my %types   = (
                'Re-Shipment'   => 2,
                'Replacement'   => 4,
            );

        return { shipment_class_id => $types{ $type || 'Re-Shipment' } };       # default to the first option 'Re-Shipment'
    }
);

=head2 flow_mech__customercare__create_shipment_item_submit

Submit the 'Select Item(s)' form to create re-shipment.

Requires an array of shipment item ids to select.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare__create_shipment_item_submit',
    form_name         => 'createShipment',
    form_description  => 'create shipment - select item(s)',
    form_button  => 'submit',
    assert_location   => qr!^/CustomerCare/[^/]*Search/CreateShipment\?order_id=\d+&shipment_id=\d+!,
    transform_fields  => sub {
        my ($self, $shipment_item_ids) = @_;
        my %fields;
        foreach my $shipment_item_id (@$shipment_item_ids) {
           $fields{$shipment_item_id} = "included";
        }
        return \%fields;
    },
);

=head2 flow_mech__customercare__create_shipment_final_submit

Submit the 'Extra Charges' form to create re-shipment.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare__create_shipment_final_submit',
    form_name         => 'createShipment',
    form_description  => 'create shipment - final page',
    form_button  => 'submit',
    assert_location   => qr!^/CustomerCare/[^/]*Search/CreateShipment\?order_id=\d+&shipment_id=\d+!,
    transform_fields  => sub {
        my ($self, $extra_charges) = @_;

        my $fields;

        # see what shipment type the page is for
        my $type    = $self->mech->find_xpath( '//input[@name="shipment_class_id"]' )->get_node;
        if ( $type->attr('value') eq "2" ) {
            # Re-Shipment
            $fields = { 'extra_charges' => ( defined $extra_charges ? $extra_charges : 0 ) }
        }
        else {
            # Replacement
        }

        return $fields;
    },
);

=head2 flow_mech__customercare__edit_shipment

    Fetch the CustomerCare/OrderSearch/EditShipment page with C<shipment_row>
    as the required parameter.

=cut

sub flow_mech__customercare__edit_shipment {
    my ($self, $shipment_row) = @_;

    my $shipment_id = $shipment_row->id;
    my $order_id = $shipment_row->order->id;

    return $self->flow_mech__customercare__edit_shipment__order_shipment({
        order_id    => $order_id,
        shipment_id => $shipment_id,
    });
}

=head2 flow_mech__customercare__edit_shipment__order_shipment({ :$order_id, :$shipment_id })

    Fetch the CustomerCare/OrderSearch/EditShipment page with
    C<order_id> and C<shipment_id> as parameters.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__customercare__edit_shipment__order_shipment',
    page_description => 'Edit Shipment Page',
    page_url         => '/CustomerCare/OrderSearch/EditShipment',
    params           => [qw/ order_id shipment_id /],
);
__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__customercare__edit_shipment_submit',
    form_name        => 'editShipment',
    form_description => 'Edit shipment form',
    assert_location  => qr!/EditShipment!,
    transform_fields  => sub {
        my ($self, $fields) = @_;

        return $fields;
    },
);

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare_create_debit_credit',
    link_description => 'Create Credit/Debit',
    find_link        => { text => 'Create Credit/Debit' },
    assert_location  => qr!^/CustomerCare/CustomerSearch/OrderView!,
);

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare___refundForm_submit',
    form_name         => 'refundForm',
    form_description  => 'Edit invoice form',
    assert_location   => qr!/CustomerCare/CustomerSearch/Invoice!,
    transform_fields  => sub {
        my ($self, $fields) = @_;

        return $fields;
    },
);

=head2 flow__customercare__click_on_invoice_to_view

    $framework->flow__customercare__click_on_invoice_to_view( $renumeration_id );

When on the Order View page will click on the 'View' icon for a particular Invoice
in the 'Payments & Refunds' section.

=cut

__PACKAGE__->create_link_method(
    method_name         => 'flow__customercare__click_on_invoice_to_view',
    link_description    => 'Click to View Invoice',
    assert_location     => qr!^/CustomerCare/[^/]*Search/OrderView!,
    transform_fields => sub {
                    my ( $mech, $invoice_number )   = @_;
                    return {
                        url_regex => qr/
                            Invoice\?.*
                            action=View.*
                            invoice_id=${invoice_number}
                        /x
                    };
                },
);

=head2 flow__customercare__click_on_invoice_to_edit

    $framework->flow__customercare__click_on_invoice_to_edit( $renumeration_id );

When on the Order View page will click on the 'Edit' icon for a particular Invoice
in the 'Payments & Refunds' section.

=cut

__PACKAGE__->create_link_method(
    method_name         => 'flow__customercare__click_on_invoice_to_edit',
    link_description    => 'Click to Edit Invoice',
    assert_location     => qr!^/CustomerCare/[^/]*Search/OrderView!,
    transform_fields => sub {
                    my ( $mech, $invoice_number )   = @_;
                    return {
                        url_regex => qr/
                            Invoice\?.*
                            action=Edit.*
                            invoice_id=${invoice_number}
                        /x
                    };
                },
);

__PACKAGE__->create_fetch_method(
    method_name      => 'mech__customercare__fetch_return_view',
    page_description => 'View Return',
    page_url         => '/CustomerCare/CustomerSearch/Returns/View?return_id=',
    required_param   => 'Return ID',
);

__PACKAGE__->create_link_method(
    method_name      => 'mech__customercare__reverse_booked_in_item',
    link_description => 'Reverse Booked In Item',
    find_link        => { text => 'Reverse Booked In Item' },
    assert_location  => qr!^/CustomerCare/[^/]*Search/Returns/View\?(?:.*&)?return_id=\d+!,
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__customercare__reverse_booked_in_item_submit',
    form_name        => 'cancelForm',
    form_description => 'Reverse Return Items',
    assert_location  => qr!^/CustomerCare/[^/]*Search/Returns/ReverseItem\?(?:.*&)?return_id=\d+!,
    transform_fields => sub {
        my ( $self, $fields ) = @_;
        $fields = ref $fields && ref $fields eq 'ARRAY'
                ? $fields : [$fields];
        return { map {; "returnitemid" => $_ } @$fields };
    },
);

=head2 flow_mech__customercare__click_on_rma

    $framework->flow_mech__customercare__click_on_rma( $rma_number );

This will click on an RMA Number on the Order View page and take you to that RMA's Details page.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__click_on_rma',
    link_description => 'RMA Number',
    transform_fields => sub {
                    my ( $mech, $rma_number )   = @_;
                    return { text => $rma_number };
                },
    assert_location  => qr!^/CustomerCare/[^/]*Search/OrderView!,
);

__PACKAGE__->create_link_method(
    method_name      => 'mech__customercare__link_to_cancel_return',
    link_description => 'Cancel Return',
    find_link        => { text => 'Cancel Return' },
    assert_location  => qr!^/CustomerCare/[^/]*Search/Returns/View\?.*return_id=\d+!,
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__customercare__cancel_return_submit',
    form_name        => 'cancelForm',
    form_description => 'Cancel Return',
    assert_location  => qr!^/CustomerCare/[^/]*Search/Returns/Cancel\?.*return_id=\d+!,
    transform_fields => sub {
        my ( $self, $fields ) = @_;
        $fields->{send_email} //= 'no',
        return $fields;
    },
);

=head2 flow_mech__customercare__view_returns

This will go to the 'Returns' left hand menu link

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__view_returns',
    link_description => 'Returns',
    find_link        => { text => 'Returns' },
    assert_location  => qr!^/CustomerCare/[^/]*Search/OrderView!,
);

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__view_returns_create_return',
    link_description => 'Create Return',
    find_link        => { text => 'Create Return' },
    assert_location  => qr!^/CustomerCare/[^/]*Search/Returns/View!,
);

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare__view_returns_create_return_data',
    form_name         => 'createRetForm',
    form_description  => 'Create Return',
    form_button       => 'submit',
    assert_location   => qr!^/CustomerCare/[^/]*Search/Returns/Create\?order_id=\d+&shipment_id=\d+!,
    transform_fields  => sub {
        my ( $self, $args ) = @_;

        return $self->_helper__make_up_create_return_form_data( $args );
    },
);

=head2 flow_mech__ajax__customercare__preview_refund_split

This calls the '/orders/returns/preview_refund_split' URL which is called using an
AJAX request on the Create Returns page to show a preview of what the amounts will
be for the Refund. This also uses the 'createRetForm' FORM on the Create Reutrn page.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__ajax__customercare__preview_refund_split',
    form_name         => 'createRetForm',
    form_description  => 'Preview Refund Split',
    assert_location   => qr!^/CustomerCare/[^/]*Search/Returns/Create\?order_id=\d+&shipment_id=\d+!,
    transform_fields  => sub {
        my ( $self, $shipment_id, $args ) = @_;

        my $fields = $self->_helper__make_up_create_return_form_data( $args );

        my $form    = $self->mech->form_name('createRetForm');
        my $action  = $form->action;
        $action->path( '/orders/returns/preview_refund_split' );
        $action->query( undef );

        return {
            shipment_id => $shipment_id,
            %{ $fields },
        };
    },
);

# helper to make up the FORM used by:
#
#   - flow_mech__customercare__view_returns_create_return_data
#   - flow_mech__ajax__customercare__preview_refund_split
#
# which submits the request on the first Create Return page as
# the same FORM is used by both flow methods.
sub _helper__make_up_create_return_form_data {
    my ( $self, $args ) = @_;

    my $product_data = { map { %{ $_ } } map { +{
        $_->{Product} => {
            'select' => $_->{Select}->{input_name},
            reason => {
                'select' => $_->{'Reason for Return'}->{select_name},
                'values' => $_->{'Reason for Return'}->{select_values},
            },
            type => {
                'select' => $_->{'Exchange'}->{input_name},
                'values' => [ 'Return', 'Exchange' ],
            },
            exchange => {
                'select' => ref($_->{'Exchange Size'}) ? $_->{'Exchange Size'}->{select_name} : undef,
                'values' => ref($_->{'Exchange Size'}) ? $_->{'Exchange Size'}->{select_values} : undef,
            },
            refund => {
                'select' => $_->{'Full Refund'}->{input_name},
                'values' => [ 0, 1 ],
            }
        } } } grep { exists( $_->{Select} ) } @{ $self->mech()->as_data()->{returns_items} } };

    my $with_fields = { email_type => 'standard', select_items => 1, notes => $args->{notes} // '', pickup => 'false', rma_number => '' };
    foreach my $product ( @{ $args->{products} } ) {
        next if( !defined( $product_data->{ $product->{sku} } ) );
        next if( defined( $product->{selected} ) && !$product->{selected} );

        $with_fields->{ $product_data->{ $product->{sku} }->{'select'} }             = 1;
        $with_fields->{ $product_data->{ $product->{sku} }->{type}->{'select'} }     = $product->{return_type} // 'Return';
        $with_fields->{ $product_data->{ $product->{sku} }->{refund}->{'select'} }   = $product->{refund_value} // 0;
        # Make return_reason optional - in most cases 'any' reason will do
        my $return_reason = $product->{return_reason} // 'Price';
        $with_fields->{ $product_data->{ $product->{sku} }->{reason}->{'select'} }
            = join( '',
                map { $_->[0] }
                grep { $_->[1] eq $return_reason }
                @{ $product_data->{ $product->{sku} }->{reason}->{'values'} }
            );
        if ( defined $product_data->{ $product->{sku} }->{exchange}->{'select'} ) {
            # protect against when there is nothing available to Exchange
            $with_fields->{ $product_data->{ $product->{sku} }->{exchange}->{'select'} } = $product->{exchange_value} // 0;
        }
    }

    return $with_fields;
}

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare__refundForm_confirm_submit',
    form_name         => 'refundForm',
    form_description  => 'refund form Confirm page',
    assert_location   => qr!/CustomerCare/CustomerSearch/ConfirmInvoice!,
    transform_fields  => sub {
        my ($self, $fields) = @_;

        return $fields;
    },
);

=head2 flow_mech__customercare__view_returns_create_return_submit

Submits the request on the final Create Return page to actually Create the Return.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare__view_returns_create_return_submit',
    form_name         => 'createRetForm',
    form_description  => 'Submit Return',
    form_button       => 'submit',
    assert_location   => qr!^/CustomerCare/[^/]*Search/Returns/Create\?order_id=\d+&shipment_id=\d+!,

    transform_fields  => sub {
       my ( $self, $args ) = @_;

        return $args // { send_email => 'no' };
    }
);

=head2 flow_mech__customercare__release_exchange_shipment

    $framework->flow_mech__customercare__click_on_rma( $exchange_shipment_id );

This will Release an Exchange Shipment for the supplied Exchange Shipment Id so that it can be fulfilled.

=cut

__PACKAGE__->create_form_method(
    method_name     => 'flow_mech__customercare__release_exchange_shipment',
    form_name       => sub {
                my ( $self, $exchange_ship_id ) = @_;
                return "releaseExchange_${exchange_ship_id}";
            },
    form_description  => 'Release Exchange Shipment',
    assert_location   => qr!^/CustomerCare/[^/]*Search/OrderView!,
);


=head2 flow_mech__customercare__edit_billing_address

Follow the 'Edit Billing Address' link from Order View

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__edit_billing_address',
    link_description => 'Edit Billing Address',
    find_link        => {
        url_regex => qr|ChooseAddress.*|,
        text      => 'Edit Billing Address'
    },
    assert_location  => qr!^/CustomerCare/[^/]*Search/OrderView!,
);


=head2 flow_mech__customercare__edit_shipping_address

Follow the 'Edit Shipping Address' link from Order View

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__edit_shipping_address',
    link_description => 'Edit Shipping Address',
    find_link        => {
        url_regex => qr|ChooseAddress.*|,
        text      => 'Edit Shipping Address'
    },
    assert_location  => qr!^/CustomerCare/[^/]*Search/OrderView!,
);

=head2 flow_mech__customercare__edit_billing_address

Follow the 'Edit Billing Address' link from Order View

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__edit_billing_address',
    link_description => 'Edit Billing Address',
    find_link        => {
        url_regex => qr|ChooseAddress.*|,
        text      => 'Edit Billing Address'
    },
    assert_location  => qr!^/CustomerCare/[^/]*Search/OrderView!,
);

=head2 flow_mech__customercare__choose_address

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__customercare__choose_address',
    form_name        => 'base_address',
    form_description => 'Choose an address to use or edit',
    assert_location  => qr!^/CustomerCare/[^/]*/ChooseAddress!,
);

=head2 flow_mech__customercare__use_address

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__customercare__use_address',
    form_name        => 'use_address',
    form_button      => sub { return $_[1] },
    form_description => 'Choose an address to use',
    assert_location  => qr!^/CustomerCare/[^/]*/ChooseAddress!,
);

=head2 flow_mech__customercare__new_address

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__customercare__new_address',
    form_name        => 'new_address',
    form_description => 'Create a new address',
    assert_location  => qr!^/CustomerCare/[^/]*/ChooseAddress!,
);

=head2 flow_mech__customercare__edit_address

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__customercare__edit_address',
    form_name        => 'use_address',
    form_description => 'Edit the address to use',
    assert_location  => qr!^/CustomerCare/[^/]*/EditAddress!,
    transform_fields => sub {
        my ( $self, $fields ) = @_;

        return $fields;

    },
);

=head2 flow_mech__customercare__edit_address__confirm_shipping_option

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__customercare__edit_address__confirm_shipping_option',
    form_name        => 'editAddress',
    form_description => 'Confirm the Address and Shipping Option',
    assert_location  => qr!^/CustomerCare/[^/]*/ConfirmAddress!,
);

=head2 flow_mech__customercare__confirm_address

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__customercare__confirm_address',
    form_name        => 'editAddress',
    form_description => 'Confirm the address to use',
    assert_location  => qr!^/CustomerCare/[^/]*/ConfirmAddress!,
    transform_fields => sub {
        my ( $self, $args ) = @_;

        my $mech = $self->mech;

        # use the correct FORM in the page
        $mech->form_name('editAddress');

        if ( exists( $args->{force_update_address_checkbox} ) ) {
            # tick/untick the 'force address' check box
            (
                delete $args->{force_update_address_checkbox}
                ? $mech->tick( 'force_update_address', 1 )
                : $mech->untick( 'force_update_address', 1 )
            );
        }

        return $args;
    },
);

=head2 flow_mech__customercare__send_email

    $framework->flow_mech__customercare__send_email;

This clicks on the 'Send Email' left hand menu option on the Order View page.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__send_email',
    link_description => 'Send Email',
    find_link        => { text => 'Send Email' },
    assert_location  => qr{^/CustomerCare/[^/]*Search/OrderView},
);

=head2 flow_mech__customercare__send_email_select_email_template

    $framework->flow_mech__customercare__send_email_select_email_template( $template_id );

Selects an Email template to send.

=cut

__PACKAGE__->create_form_method(
    method_name     => 'flow_mech__customercare__send_email_select_email_template',
    form_name       => 'sendEmail',
    transform_fields=> sub {
        my ( $self, $template_id ) = @_;

        return {
            template_id => $template_id,
        }
    },
    form_description  => 'Select Email Template',
    assert_location   => qr{^/CustomerCare/[^/]*Search/SendEmail},
);

=head2 flow_mech__customercare__send_an_email

    $framework->flow_mech__customercare__send_an_email

This actually Sends the Email.


* breaking with the naming convention otherwise it becomes ridiculous with 'send_email_send_an_email'.

=cut

__PACKAGE__->create_form_method(
    method_name     => 'flow_mech__customercare__send_an_email',
    form_name       => 'sendEmail',
    form_description  => 'Send an Email',
    assert_location   => qr{^/CustomerCare/[^/]*Search/SendEmail},
);


=head2 flow_mech__customercare__put_on_credit_hold

    $framework->flow_mech__customercare__put_on_credit_hold;

This will put an Order on 'Credit Hold'

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__put_on_credit_hold',
    link_description => 'Credit Hold an Order',
    find_link        => { text => 'Credit Hold' },
    assert_location  => qr{^/CustomerCare/[^/]*Search/OrderView},
    use_referer_work_around => 1,
);

=head2 flow_mech__customercare__put_on_credit_check

    $framework->flow_mech__customercare__put_on_credit_check;

This will put an Order on 'Credit Check'

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__put_on_credit_check',
    link_description => 'Credit Check an Order',
    find_link        => { text => 'Credit Check' },
    assert_location  => qr{^/CustomerCare/[^/]*Search/OrderView},
    use_referer_work_around => 1,
);

=head2 flow_mech__customercare__accept_order

    $framework->flow_mech__customercare__accept_order;

This will Accept an Order that is on 'Credit Hold' or 'Credit Check'

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__accept_order',
    link_description => 'Accept Order an Order',
    find_link        => { text => 'Accept Order' },
    assert_location  => qr{^/CustomerCare/[^/]*Search/OrderView},
    use_referer_work_around => 1,
);

=head2 task_mech__customercare__create_return( $order_id, \@return_sku_hashes )

    task__mech__create_return( 12345, [
        {
            sku => $sku,
            customer_issue_type_id => $customer_issue_type_id (default $CUSTOMER_ISSUE_TYPE__7__FABRIC)
            return_type => 'Return' (default) or 'Exchange'
            exchange_value => $variant_id (only required when type is exchange, defaults to same variant as the one being exchanged),
        },
    ])

=cut

sub task_mech__customercare__create_return {
    my ( $self, $order_id, $return_skus ) = @_;

    my $schema = $self->schema;
    # create return for this order
    my $products = [ map {
        my $args = {
            sku           => $_->{sku},
            selected      => 1,
            return_type   => $_->{return_type} || 'Return',
            return_reason => $schema->resultset('Public::CustomerIssueType')
                                    ->find( $_->{customer_issue_type_id} // $CUSTOMER_ISSUE_TYPE__7__FABRIC )
                                    ->description,
        };
        $args->{exchange_value} = (
            $_->{exchange_value} || $schema->resultset('Public::Variant')->find_by_sku($args->{sku})->id
        ) if $args->{return_type} eq 'Exchange';
        $args;
    } @$return_skus ];
    $self->flow_mech__customercare__orderview( $order_id );
    $self->flow_mech__customercare__view_returns;
    $self->flow_mech__customercare__view_returns_create_return;
    $self->flow_mech__customercare__view_returns_create_return_data( { products => $products } );
    $self->flow_mech__customercare__view_returns_create_return_submit( { send_email => 'no' } );

    return $self;
}

=head2 flow_mech__customercare__check_pricing

    $framework->flow_mech__customercare__check_pricing;

Will click on the Left Hand Menu option on the Order View page 'Check Pricing'.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__check_pricing',
    link_description => 'Check Pricing',
    find_link        => { text => 'Check Pricing' },
    assert_location  => qr!^/CustomerCare/[^/]*Search/OrderView!,
);

=head2 flow_mech__customercare__check_pricing_submit_new_destination

    $framework->flow_mech__customercare__check_pricing_submit_new_destination( {
        country => $country_name,
            and/or
        county  => $county_or_state,
    } );

Will submit a New Destination for the Shipment and then display the new Prices.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare__check_pricing_submit_new_destination',
    form_name         => 'newDestination',
    form_description  => 'Shipping Destination Change',
    assert_location   => qr!^/CustomerCare/[^/]*Search/ChangeCountryPricing!,
    transform_fields => sub {
        my ( $self, $args ) = @_;
        return $args;
    },
);

=head2 flow_mech__customercare__check_pricing_send_email

    $framework->flow_mech__customercare__check_pricing_send_email( {
        # any or none of the following
        send_email          => 'yes' or 'no',
        email_to            => $email_to_address,
        email_from          => $email_from_address,
        email_replyto       => $email_replyto_address,
        email_subject       => $email_subject,
        email_body          => $email_body,
        email_content_type  => 'text' or 'html',
    } );

Send an Email from the Check Pricing page.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare__check_pricing_send_email',
    form_name         => 'amendPricing',
    form_description  => 'Send Customer Email',
    assert_location   => qr!^/CustomerCare/[^/]*Search/ChangeCountryPricing!,
    transform_fields => sub {
        my ( $self, $args ) = @_;
        return $args;
    },
);

############ Fraud Rules Sidenav Options ############

=head2 flow_mech__customercare__fraud_rules__show_outcome

    $framework->flow_mech__customercare__fraud_rules__show_outcome;

This will follow the 'Show Outcome' link under the 'Fraud Rules' section
of the Order View page's Sidenav options.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__fraud_rules__show_outcome',
    link_description => 'Show Outcome',
    find_link        => { text => 'Show Outcome' },
    assert_location  => qr!^/CustomerCare/[^/]*Search/OrderView!,
);

=head2 flow_mech__customercare__fraud_rules__test_using_live

    $framework->flow_mech__customercare__fraud_rules__test_using_live;

This will follow the 'Test Using Live' link under the 'Fraud Rules' section
of the Order View page's Sidenav options.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__fraud_rules__test_using_live',
    link_description => 'Test Using Live',
    find_link        => { text => 'Test Using Live' },
    assert_location  => qr!^/CustomerCare/[^/]*Search/OrderView!,
);

=head2 flow_mech__customercare__fraud_rules__test_using_staging

    $framework->flow_mech__customercare__fraud_rules__test_using_staging;

This will follow the 'Test Using Staging' link under the 'Fraud Rules' section
of the Order View page's Sidenav options.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__customercare__fraud_rules__test_using_staging',
    link_description => 'Test Using Staging',
    find_link        => { text => 'Test Using Staging' },
    assert_location  => qr!^/CustomerCare/[^/]*Search/OrderView!,
);

#####################################################

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__customercare__order_search_results',
    page_description => 'Order Search Results',
    page_url         => '/CustomerCare/OrderSearch/Results',
    params           => []
);

=head2 flow_mech__customercare__quick_search

    $framework->flow_mech__customercare__quick_search( $search_str );

Uses Quick Search to find something.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__customercare__quick_search',
    form_name         => 'quick_search',
    form_description  => 'Quick Search',
    assert_location   => qr!^/.*!,
    transform_fields  => sub {
        my ( $self, $search_str ) = @_;

        return {
            quick_search => $search_str,
        };
    },
);


=head2 flow_mech__customercare__customercategory

    Fetch the CustomerCare/CustomerCategory

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__customercare__customercategory',
    page_description => 'Customer Category Page',
    page_url         => '/CustomerCare/CustomerCategory',
    params           => [],
);

=head2 flow_mech__customercare__customercategory__submit

Submit the form for customer categories to be updated

=cut

__PACKAGE__->create_form_method(
    method_name         => 'flow_mech__customercare__customercategory__submit',
    form_name           => 'bulk_category_update',
    form_description    => 'Bulk Update Customer Category for Customers',
    assert_location     => '/CustomerCare/CustomerCategory',
    transform_fields    => sub {
        my ( $self, $args ) = @_;
        return $args;
    },
    form_button         => 'submit',
);

__PACKAGE__->create_form_method(
    method_name         => 'flow_mech__customercare__customercategory__retry',
    form_name           => 'retry_form',
    form_description    => 'Retry failed customers',
    assert_location     => '/CustomerCare/CustomerCategory',
    transform_fields    => sub {
        my ( $self, $args ) = @_;
        return $args;
    },
    form_button         => 'retry',
);

1;
