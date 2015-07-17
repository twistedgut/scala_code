package Test::XT::Flow::Reservations; ## no critic(ProhibitExcessMainComplexity)

use NAP::policy "tt",     qw( test role );

use Data::Dump qw(pp);

use Test::XT::Flow;

with 'Test::XT::Flow::AutoMethods';

=head1 NAME

Test::XT::Flow::Reservations

=head1 DESCRIPTION

A Moose role with reservations-related helper methods

=head1 METHODS

=head2 mech__reservation__summary

Fetch the StockControl/Reservation summary page.

=cut

__PACKAGE__->create_fetch_method(
    method_name => 'mech__reservation__summary',
    page_description => 'Reservation Summary',
    page_url => '/StockControl/Reservation',
);

=head2 mech__reservation__product_search

Fetch the reservation product search page.

=cut

__PACKAGE__->create_fetch_method(
    method_name => 'mech__reservation__product_search',
    page_description => 'Reservation Product Search',
    page_url => '/StockControl/Reservation/Product',
);

=head2 mech__reservation__customer_search

Fetch the reservation customer search page.

=cut

__PACKAGE__->create_fetch_method(
    method_name => 'mech__reservation__customer_search',
    page_description => 'Reservation Customer Search',
    page_url => '/StockControl/Reservation/Customer',
);


=head2 mech__reservation__product_search_submit

Submit the product search parameters provided.

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__product_search_submit',
    form_name => 'reservationSearch',
    form_description => 'Reservation product search',
    assert_location => qr{StockControl/Reservation/Product},
    transform_fields => sub {
        return {
            map { $_ => $_[1]{$_} }
                grep { defined $_[1]{$_} }
                    qw{sku product_id designer season type}
        };
    },
);

=head2 mech__reservation__customer_search_submit

Submit the Customer search parameters provided.

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__customer_search_submit',
    form_name => 'reservationCustomerSearch',
    form_description => 'Reservation Customer search',
    assert_location => qr{StockControl/Reservation/Customer},
    transform_fields => sub {
        my ( $mech, $args )     = @_;
        return {
            map { $_ => $args->{$_} }
                grep { defined $args->{$_} }
                    qw{ customer_number first_name last_name email }
        };
    },
);

=head2 mech__reservation__customer_search_results_click_on_customer

From the Search Results for a Customer Search click on a Particular Customer Number.

Remember to pass the 'is_customer_number'.

=cut

__PACKAGE__->create_link_method(
    method_name     => 'mech__reservation__customer_search_results_click_on_customer',
    link_description=> "Go to a Customer's Reservations",
    transform_fields=> sub {
                    my ( $mech, $cust_nr )  = @_;
                    return { text => $cust_nr };
                },
    assert_location => qr!^/StockControl/Reservation/Customer!,
);

=head2 mech__reservation__customer_reservation_list_click_on_sku

On the Customer Reservations page click on a supplied SKU.

=cut

__PACKAGE__->create_link_method(
    method_name     => 'mech__reservation__customer_reservation_list_click_on_sku',
    link_description=> "Go to the SKU's Reservations",
    transform_fields=> sub {
                    my ( $mech, $sku )  = @_;
                    return { text => $sku };
                },
    assert_location => qr!^/StockControl/Reservation/Customer!,
);

=head2 mech__reservation__upload_reservation

Pass in a Reservation Id and it will Upload it.

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__upload_reservation',
    form_name => sub {
            my ( $self, $reservation_id )   = @_;
            return "updateForm" . $reservation_id;
        },
    form_description => 'Upload a Reservation',
    assert_location => qr{/StockControl/Reservation/Product},
    transform_fields => sub {
            my ( $self, $reservation_id )   = @_;
            return {
                    special_order_id    => $reservation_id,
                    action              => 'Upload',
                };
        },
);

=head2 mech__reservation__cancel_reservation

Pass in a Reservation Id and it will Cancel it or 'Delete' it as it says on the page.

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__cancel_reservation',
    form_name => sub {
            my ( $self, $reservation_id )   = @_;
            return "updateForm" . $reservation_id;
        },
    form_description => 'Delete or Cancel a Reservation',
    assert_location => qr{/StockControl/Reservation/Product},
    transform_fields => sub {
            my ( $self, $reservation_id )   = @_;
            return {
                    special_order_id    => $reservation_id,
                    action              => 'Delete',
                };
        },
);

=head2 mech__reservation__edit_reservation

Pass in a Reservation Object and Arguments and it will Edit a Reservation

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__edit_reservation',
    form_name => 'editForm',
    form_description => 'Edit a Reservation',
    assert_location => qr{/StockControl/Reservation/Product},
    transform_fields => sub {
            my ( $self, $reservation_id, $args )    = @_;

            $args   ||= {};

            # get the reservation record
            my $res = $self->schema->resultset('Public::Reservation')->find( $reservation_id );

            return {
                    special_order_id    => $res->id,
                    action              => 'Edit',
                    variant_id          => $res->variant_id,
                    current_position    => $res->ordering_id,
                    ordering            => $res->ordering_id,
                    changeSize          => $res->variant_id,
                    expireDay           => '00',
                    expireMonth         => '00',
                    expireYear          => '0000',
                    notes               => '',
                    operator_id         => $res->operator_id,
                    newOperator         => $res->operator_id,
                    new_reservation_source_id => $res->reservation_source_id,
                    new_reservation_type_id   => $res->reservation_type_id,
                    %{ $args },
                };
        },
);

=head2 mech__reservation__product_create_reservation_submit

Get to the create reservation page for the given variant from the product
reservation page (using C<L</mech__reservation__product_search_submit>>).

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__product_create_reservation_submit',
    form_name => sub { return
        'createReservation'
      . q{-}
      . $_[1]{channel_id}
      . q{-}
      . $_[1]{variant_id}
    },
    form_description => 'Get to the create reservation page from the reservation product page',
    assert_location => qr{/StockControl/Reservation/Product},
    transform_fields => sub {
        return {
            variant_id => $_[1]{variant_id},
            channel => $_[1]{channel_name},
        };
    },
);

=head2 mech__reservation__create_reservation_submit

Create the reservation for the customer. This sub can be called in three ways,
as the same form has different behaviours.

=over

=item Enter customer number

The first step is to pass a customer number or/and an email:

    mech__reservation__create_reservation_submit({
        customer_number => $customer->is_customer_number,
        email           => $customer->email,
    });

=item Enter further customer details

If the customer does not exist in XT the form will then prompt the user to
enter further details:

    mech__reservation__create_reservation_submit({
        customer_first_name
        customer_last_name
        customer_email
    });

=item Confirm reservation

And finally the user is asked to confirm the reservation, in which case the
sub can be called with no further parameters:

    mech__reservation__create_reservation_submit();

=back

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__create_reservation_submit',
    form_name => 'createReservation',
    form_description => 'Create a reservation for the product',
    assert_location => qr{/StockControl/Reservation/Create},
    transform_fields => sub {
        # Step 1 - The user passed a customer number
        return {
            email => $_[1]{email},
            is_customer_number => $_[1]{is_customer_number},
            reservation_source => $_[1]{reservation_source},
            reservation_type   => $_[1]{reservation_type},
            override_pws_customer_check => 1,
        } if grep { defined $_[1]{$_} } qw{email is_customer_number reservation_source};
        # Step 2 - The user's customer number wasn't found in XTracker so the
        # system is prompting for customer details
        my @fields = (qw<
            customer_first_name
            customer_last_name
            customer_email
        >);
        return { map { $_ => $_[1]{$_} } grep { defined $_ } @fields }
            if @{$_[1]}{@fields};
        # Step 3 - Confirm the reservation
        return {};
    },
);

=head2 mech__reservation__summary_customer_notification_submit

Given a Reservation this will tick the appropriate check-box and submit the form to
send a Customer Notification for a Customer's reservation.

    mech__reservation__summary_customer_notification_submit( $reservation );

This page has Sales Channel Tabs so passing the Channel Name Makes identifying the check-box easier.

=cut

__PACKAGE__->create_form_method(
    method_name         => 'mech__reservation__summary_customer_notification_submit',
    form_name           => sub {
            my ( $self, $args )  = @_;
            my $form_name   = "emailCustomer-" . $args->{customer_id};
            note "Using Form Name: $form_name";
            return $form_name;
        },
    form_description    => 'Send a Customer Notification',
    assert_location     => qr{/StockControl/Reservation/Email},
    transform_fields    => sub {
            my ( $self, $args ) = @_;

            my $reservation_id  = $args->{reservation_id};
            my $cust_number     = $args->{is_customer_number};
            my $channel_name    = $args->{channel_name};

            # simulate not selecting any Reservations
            return      if ( $reservation_id eq 'none' );

            # find the correct Customer on the page
            my ($cust)  = grep { $_->{customer_info}{'Customer Number'} == $cust_number }
                                        @{ $self->mech->as_data->{customer_emails}{ uc( $channel_name ) } };
            if ( !defined $cust ) {
                die "Couldn't Find Customer: ".$cust_number." in page";
            }

            # find the Reservation for the Customer
            my ($row)   = grep { $_->{Notify}{input_name} =~ m/inc-$reservation_id/ } @{ $cust->{list} };
            if ( !defined $row ) {
                die "Couldn't Find Reservation ($reservation_id) for Customer: ".$cust_number." in page";
            }

            return {
                    "inc-$reservation_id" => 1,
                };
        },
);


=head2 mech__reservation__overview_click_upload

Find and click through on the 'Upload' link under the 'Overview' heading.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'mech__reservation__overview_click_upload',
    link_description => 'Overview - Upload',
    find_link        => { text => 'Upload' },
    assert_location  => qr!^/StockControl/Reservation!,
);

=head2 mech__reservation__overview_click_pending

Find and click through on the 'Pending' link under the 'Overview' heading.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'mech__reservation__overview_click_pending',
    link_description => 'Overview - Pending',
    find_link        => { text => 'Pending' },
    assert_location  => qr!^/StockControl/Reservation!,
);

=head2 mech__reservation__overview_click_waiting_list

Find and click through on the 'Waiting List' link under the 'Overview' heading.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'mech__reservation__overview_click_waiting_list',
    link_description => 'Overview - Waiting List',
    find_link        => { text => 'Waiting List' },
    assert_location  => qr!^/StockControl/Reservation!,
);


=head2 mech__reservation__overview_upload__generate_pdf_submit

    $self->mech__reservation__overview_upload__generate_pdf_submit( $channel_name, $upload_date );

This will get an Un-Filtered Upload PDF by clicking on the 'Generate PDF' button on the
'Overview - Upload' page for a given Sales Channel and Upload Date.

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__overview_upload__generate_pdf_submit',
    form_name => sub {
            my ( $self, $channel_name ) = @_;
            return "upload_date-${channel_name}";
        },
    form_description => 'Generate Upload PDF',
    assert_location => qr{/StockControl/Reservation/Overview\?view_type=Upload},
    transform_fields => sub {
            my ( $self, $channel_name, $upload_date )   = @_;

            return {
                    upload_date => $upload_date,
                };
        },
);

=head2 mech__reservation__overview_upload__filter_pdf_submit

    $self->mech__reservation__overview_upload__filter_pdf_submit( $channel_name, $upload_date );

This will Simulate clicking on the 'Apply Filter to PDF' button.

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__overview_upload__filter_pdf_submit',
    form_name => sub {
            my ( $self, $channel_name ) = @_;
            return "upload_date-${channel_name}";
        },
    form_description => 'Apply Filter to PDF',
    assert_location => qr{/StockControl/Reservation/Overview\?view_type=Upload},
    transform_fields => sub {
            my ( $self, $channel_name, $upload_date )   = @_;

            # change the Action in the Form which is simulating
            # what a Javascript function does in the form when
            # the 'Apply Filter to PDF' button is clicked
            my $form    = $self->mech->form_name( "upload_date-${channel_name}" );
            my $action  = $form->action;
            $action     =~ s{(http://.*?)/.*}{$1/StockControl/Reservation/Overview/Upload/Filter};
            $form->action( $action );

            return {
                    upload_date => $upload_date,
                };
        },
);

=head2 mech__reservation__overview_upload__apply_filter_pdf_submit

    $self->mech__reservation__overview_upload__apply_filter_pdf_submit( {
                                                                        exclude_designer_ids => [
                                                                                list of designer Id's
                                                                                ...
                                                                            ],
                                                                        exclude_product_ids => "text string of pids",
                                                                    } );

This will request a PDF to be generated with Designers & Products Excluded.

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__overview_upload__apply_filter_pdf_submit',
    form_name => 'upload_filter_options',
    form_description => 'Generate Filtered PDF',
    assert_location => qr{/StockControl/Reservation/Overview/Upload/Filter},
    transform_fields => sub {
            my ( $self, $args )     = @_;
            my $mech    = $self->mech;

            $mech->form_name("upload_filter_options");
            foreach my $designer_id ( @{ $args->{exclude_designer_ids} } ) {
                $mech->untick( 'include_designers', $designer_id );
            }

            return {
                    (
                        exists( $args->{exclude_product_ids} )
                        ? ( exclude_pids => $args->{exclude_product_ids} )      # only Submit PIDs if something has been passed
                        : ()                                                    # else submit what is on the page already
                    )
                };
        },
);

=head2 mech__reservation__overview_upload__re_filter_submit

    $self->mech__reservation__overview_upload__re_filter_submit();

This will Re-Filter an Upload PDF giving the User the ability to refine Filtering that they have just done.

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__overview_upload__re_filter_submit',
    form_name => 're_apply_filter',
    form_description => 'Re-Filter PDF',
    assert_location => qr{/StockControl/Reservation/Overview/Upload/ApplyFilter},
    form_button  => 're_apply_filter',
);

=head2 mech__reservation__overview_upload__filter_backto_upload_click

This will click on the Left Hand Menu Option 'Upload' on the Filter PDF confirmation page
taking you back to the 'Overview - Upload' page.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'mech__reservation__overview_upload__filter_backto_upload_click',
    link_description => 'Back to Overview - Upload',
    find_link        => { text => 'Upload' },
    assert_location  => qr!^/StockControl/Reservation/Overview/Upload/ApplyFilter!,
);


=head2 mech__reservation__summary_click_live

Find and click through on the 'Live Reservations' link

=cut

__PACKAGE__->create_link_method(
    method_name      => 'mech__reservation__summary_click_live',
    link_description => 'Live Reservations',
    find_link        => { text => 'Live Reservations' },
    assert_location  => qr!^/StockControl/Reservation!,
    #url_regex        => qr!^/StockControl/Reservation/Listing?list_type=Live!
);

=head2 mech__reservation__listing_reservations__change_operator

Sets the operator and returns a list of reservations for that operator

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__listing_reservations__change_operator',
    form_name => 'select_alternative_operator',
    form_description => 'Select Alternative Operator',
    assert_location => qr{/StockControl/Reservation/Listing?},
    transform_fields => sub {
        my ($self, $operator_id) = @_;
        return {
            list_type => 'Live',
            show => 'Personal',
            alt_operator_id => $operator_id
        };
    },
);

=head2 mech__reservation__listing_reservations__edit

Allows you to Edit and/or Delete Reservation(s) in the Reservation List.

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__listing_reservations__edit',
    form_name => sub {
            my ( $self, $cust_id )  = @_;
            return "editForm";
        },
    form_description => 'Delete or Cancel a Reservation',
    assert_location => qr{/StockControl/Reservation/Listing},
    transform_fields => sub {
            my ( $self, $cust_id, $args )   = @_;

            my $fields  = {
                    action  => 'Edit_Delete',
                };

            # any Expiry Dates to Edit
            if ( exists $args->{edit_expiry} ) {
                foreach my $expiry ( @{ $args->{edit_expiry} } ) {
                    my ( $res_id, $date )   = each %{ $expiry };
                    $fields->{ "expiry-${res_id}" } = $date;
                }
            }

            # any Reservations to Delete
            if ( exists $args->{delete_res} ) {
                foreach my $res_id ( @{ $args->{delete_res} } ) {
                    $fields->{ "delete-${res_id}" } = 1;
                }
            }

            return $fields;
        },
);

=head2 mech__reservation__summary_click_pending

Find and click through on the 'Pending Reservations' link

=cut

__PACKAGE__->create_link_method(
    method_name      => 'mech__reservation__summary_click_pending',
    link_description => 'Pending Reservations',
    find_link        => { text => 'Pending Reservations' },
    assert_location  => qr!^/StockControl/Reservation!,
);

=head2 mech__reservation__summary_click_waiting

Find and click through on the 'Waiting Reservations' link

=cut

__PACKAGE__->create_link_method(
    method_name      => 'mech__reservation__summary_click_waiting',
    link_description => 'Waiting Lists',
    find_link        => { text => 'Waiting Lists' },
    assert_location  => qr!^/StockControl/Reservation!,
);

=head2 mech__reservation__summary_click_waiting__notification_email

    __PACKAGE__->mech__reservation__summary_click_waiting__notification_email( $customer_id );

Clicks on the 'Send Notification Email >' link for a Customer in the
'Items in Next Upload' section on the 'Waiting Lists' page.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'mech__reservation__summary_click_waiting__notification_email',
    link_description => 'Send Notification Email',
    transform_fields=> sub {
        my ( $mech, $customer_id ) = @_;

        return {
            text_regex => qr/Send Notification Email/,
            url_regex  => qr/customer_id=${customer_id}/,
        };
    },
    assert_location  => qr!^/StockControl/Reservation/Listing!,
);

=head2 mech__reservation__summary_click_waiting__notification_email__send

Sends the Email from the page that calling 'mech__reservation__summary_click_waiting__notification_email'
goes to.

=cut

__PACKAGE__->create_form_method(
    method_name         => 'mech__reservation__summary_click_waiting__notification_email__send',
    form_name           => 'sendNotification',
    form_description    => 'Send Reservation Notification Email',
    assert_location     => qr{/StockControl/Reservation/Notification.*},
    form_button         => 'submit',
    transform_fields    => sub {
            my ( $self, $fields ) = @_;

            return $fields;
        },
);

=head2 mech__reservation__summary_click_customer_notification

Find and click thorugh to the 'Customer Notification' link

=cut

__PACKAGE__->create_link_method(
    method_name      => 'mech__reservation__summary_click_customer_notification',
    link_description => 'Customer Notification',
    find_link        => { text => 'Customer Notification' },
    assert_location  => qr!^/StockControl/Reservation!,
);

=head2 mech__reservation__apply_filter

Will allow toggling between 'Show All' & 'Show Personal' for some of the list pages.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'mech__reservation__apply_filter',
    link_description => 'Filter Lists',
    transform_fields => sub {
            my ( $self, $filter )   = @_;

            my %filters = (
                all     => 'Show All',
                personal=> 'Show Personal',
            );

            return { text => $filters{ lc( $filter ) } };
        },
    assert_location  => qr!^/StockControl/Reservation!,
);



=head2 mech__reservation__pre_order_summary

=cut

__PACKAGE__->create_fetch_method(
    method_name     => 'mech__reservation__pre_order_summary',
    page_description=> 'Pre-Order Summary Page',
    page_url        => '/StockControl/Reservation/PreOrder/Summary?pre_order_id=',
    required_param  => 'PreOrder Id',
);

=head2 mech__reservation__pre_order_summary_cancel_items

    $framework->mech__reservation__pre_order_summary_cancel_items( [ list of Pre-Order Item Ids ] );

This will cancel a list of given Pre-Order Items.

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__pre_order_summary_cancel_items',
    form_name => 'summary__complete_pre_order_form',
    form_description => 'Pre-Order Cancel Items',
    assert_location => qr{/StockControl/Reservation/PreOrder/Summary},
    form_button  => 'cancel_items',
    transform_fields => sub {
            my ( $self, $item_ids ) = @_;

            my $mech    = $self->mech;

            # need to set the form name before using 'tick' functions
            $mech->form_name('summary__complete_pre_order_form');

            foreach my $item_id ( @{ $item_ids } ) {
                $mech->tick( "item_to_cancel_${item_id}", '1' );
            }

            return;
        },
);

=head2 mech__reservation__pre_order_confirmation_email_page

    $framework->mech__reservation__pre_order_confirmation_email_page($pre_orer_id_);

would fetch pre-order confirmation email page

=cut

__PACKAGE__->create_fetch_method(
    method_name     => 'mech__reservation__pre_order_confirmation_email_page',
    page_description=> 'Pre-Order Confirmation Email Page',
    page_url        => '/StockControl/Reservation/PreOrder/Completed?pre_order_id=',
    required_param  => 'PreOrder Id',
);

=head2 mech__reservation__send_ pre_order_confirmation_email

    $framework->mech__reservation__send_ pre_order_confirmation_email();

will submit the email sending form.

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__send_pre_order_confirmation_email',
    form_name => 'email_form',
    form_description => 'Send Confirmation Pre-Order Email',
    assert_location => qr{/StockControl/Reservation/PreOrder/Completed.*},
    transform_fields => sub {
            my ( $self, $args ) = @_;

            my %fields;
            foreach my $field ( keys %{ $args } ) {
                $fields{ $field }   = $args->{ $field };
            }

            return \%fields;
        },
);


=head2 mech__reservation__pre_order_summary_cancel_pre_order

    $framework->mech__reservation__pre_order_summary_cancel_pre_order();

Will Cancel the whole of a Pre-Order.

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__pre_order_summary_cancel_pre_order',
    form_name => 'summary__complete_pre_order_form',
    form_description => 'Pre-Order Cancel Whole Pre-Order',
    assert_location => qr{/StockControl/Reservation/PreOrder/Summary},
    form_button  => 'cancel_pre_order',
);

=head2 mech__reservation__pre_order_summary_send_cancel_email

    $framework->mech__reservation__pre_order_summary_send_cancel_email( {
                                                                        ... # optional fields to submit
                                                                    } );

This will Send the Cancel Pre-Order Email. Pass fields if you want to override the page's values.

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__pre_order_summary_send_cancel_email',
    form_name => 'cancel_email_form',
    form_description => 'Send Cancel Pre-Order Email',
    assert_location => qr{/StockControl/Reservation/PreOrder/SendCancelEmail},
    form_button  => 'send_email_button',
    transform_fields => sub {
            my ( $self, $args ) = @_;

            my %fields;
            foreach my $field ( keys %{ $args } ) {
                $fields{ $field }   = $args->{ $field };
            }

            return \%fields;
        },
);

=head2 mech__reservation__pre_order_summary_skip_cancel_email

    $framework->mech__reservation__pre_order_summary_skip_cancel_email();

Skips sending a Cancel Pre-Order Email.

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__pre_order_summary_skip_cancel_email',
    form_name => 'cancel_email_form',
    form_description => 'Skip Sending Cancel Pre-Order Email',
    assert_location => qr{/StockControl/Reservation/PreOrder/SendCancelEmail},
    form_button  => 'send_email_button',
    transform_fields => sub {
            return { send_email => '0' };
        },
);

=head2 mech__reservation__pre_order_click_change_item_size

Click through to the Change Pre-Order Item Size page from the Pre-Order Summary page.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'mech__reservation__pre_order_click_change_item_size',
    link_description => 'Change Pre-Order Item Sizes',
    find_link        => { text => 'Change Sizes for Pre-Order Items' },
    assert_location  => qr!^/StockControl/Reservation/PreOrder/Summary!,
);

=head2 mech__reservation__pre_order_change_item_size_submit

    $framework->mech__reservation__pre_order_change_item_size_submit();

This will submit the Form on the Pre-Order Size Change page to change sizes.

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__pre_order_change_item_size_submit',
    form_name => 'pre_order_item_size_change',
    form_description => 'Change Pre-Order Item Sizes',
    assert_location => qr{/StockControl/Reservation/PreOrder/ChangeItemSize},
    transform_fields => sub {
            my ( $self, $args )     = @_;

            my $form    = $self->mech->form_name('pre_order_item_size_change');

            my $fields;
            while ( my ( $item_id, $var_id ) = each %{ $args } ) {
                $fields->{ "pre_order_item-${item_id}" }    = 1;
                my $field_name  = "item_new_size-${item_id}";
                $fields->{ $field_name }    = $var_id;

                # un-disable the field, it's a SELECT so you have to use 'option'
                my $field   = $form->find_input( $field_name, 'option' );
                $field->disabled(0);
            }

            return $fields;
        },
);

=head2 mech__reservation__pre_order_change_item_size_send_email

    $framework->mech__reservation__pre_order_change_item_size_send_email( {
                                                                        ... # optional fields to submit
                                                                    } );

This will Send the Pre-Order - Size Change Email. Pass fields if you want to override the page's values.

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__pre_order_change_item_size_send_email',
    form_name => 'pre_order_size_change_email_form',
    form_description => 'Send Pre-Order Size Change Email',
    assert_location => qr{/StockControl/Reservation/PreOrder/ActionChangeItemSize},
    form_button  => 'send_email_button',
    transform_fields => sub {
            my ( $self, $args ) = @_;

            my %fields;
            foreach my $field ( keys %{ $args } ) {
                $fields{ $field }   = $args->{ $field };
            }

            return \%fields;
        },
);

=head2 mech__reservation__pre_order_change_item_size_skip_email

    $framework->mech__reservation__pre_order_change_item_size_skip_email();

Skips sending a Pre-Order Size Change Email.

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__pre_order_change_item_size_skip_email',
    form_name => 'pre_order_size_change_email_form',
    form_description => 'Skip Sending Pre-Order Size Change Email',
    assert_location => qr{/StockControl/Reservation/PreOrder/ActionChangeItemSize},
    form_button  => 'send_email_button',
    transform_fields => sub {
            return { send_email => '0' };
        },
);


=head2 mech__reservation__uploaded_reports

Fetches /StockControl/Reservation/Reports/Uploaded/P

=cut

__PACKAGE__->create_fetch_method(
    method_name     => 'mech__reservation__uploaded_reports',
    page_description=> 'Uploaded Report Page',
    page_url        => '/StockControl/Reservation/Reports/Uploaded/P',
);


=head2 mech__reservation__uploaded_report__change_operator

Sets the operator and returns a list of uploaded reservations for that operator

=cut

__PACKAGE__->create_form_method(
    method_name => 'mech__reservation__uploaded_report__change_operator',
    form_name => 'select_alternative_operator',
    form_description => 'Select Alternative Operator',
    assert_location => qr{/StockControl/Reservation/Reports/Uploaded/P},
    transform_fields => sub {
        my ($self, $operator_id) = @_;
        return {
            alt_operator_id => $operator_id
        };
    },
);

=head2 flow_mech__preorder__select_products

    __PACKAGE__->flow_mech__preorder__select_products( {
            customer_id             => $customer_id,
            shipment_address_id     => $address_id,
            skip_pws_customer_check => 1 or 0,
        ) };

Goes to the Pre-Order Select Products page which is the start of the Pre-Order
process.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__preorder__select_products',
    page_description => 'Pre-Order Select Products',
    page_url         => '/StockControl/Reservation/PreOrder/SelectProducts',
    params           => [ qw( customer_id shipment_address_id skip_pws_customer_check ) ],
);

=head2 flow_mech__preorder__select_products_submit

    __PACKAGE__->flow_mech__preorder__select_products_submit( { ... } );

Submits Products that can then be Selected when placing a Pre-Order.

=cut

__PACKAGE__->create_form_method(
    method_name     => 'flow_mech__preorder__select_products_submit',
    form_name       => 'pid_search',
    form_description=> 'Submitting List of PIDs wanted for a Pre-Order',
    assert_location => qr{/StockControl/Reservation/PreOrder/SelectProducts.*},
    transform_fields=> sub {
        my ( $self, $args ) = @_;

        if ( defined $args->{with_discount_if_on} ) {
            my $discount = delete $args->{with_discount_if_on};
            my $pg_data = $self->mech->as_data;
            $args->{discount_percentage} = $discount
                        if ( $pg_data->{product_search_box}{'Select Discount'} );
        }

        my %fields = (
            skip_pws_customer_check => 1,
            %{ $args },
        );

        return \%fields;
    },
);

=head2 flow_mech__preorder__select_products__submit_skus_submit

    __PACKAGE__->flow_mech__preorder__select_products__submit_skus_submit( {
        reservation_source_id => 4,         # Id of the Reservation Source to use
        variant_ids => [ 345_1, 656_2, ... ],   # list of Variant Ids to pick to Pre-Order (<variant_id>_<quantity>
        ...
    } );

Submits the SKUs that will be Pre-Ordered. This is from the list of Products page that
gets displayed after doing 'flow_mech__preorder__select_products_submit'.

=cut

__PACKAGE__->create_form_method(
    method_name     => 'flow_mech__preorder__select_products__submit_skus_submit',
    form_name       => 'variant_select_products',
    form_description=> 'Submitting List of SKUs wanted for a Pre-Order',
    assert_location => qr{/StockControl/Reservation/PreOrder/SelectProducts},
    transform_fields=> sub {
        my ( $self, $args ) = @_;
        my $mech = $self->mech;

        # need to set the form so the 'variants' dropboxes selected
        $mech->form_name('variant_select_products');

        my %fields = (
            skip_pws_customer_check => 1,
            %{ $args },
        );
        return \%fields;
    },
);

=head2 flow_mech__preorder__basket

    __PACKAGE__->flow_mech__preorder__basket( $pre_order_id );

Goes to the Pre-Order Basket page which can be reached by using this method
or by going through the Product Select page flow methods:

    __PACKAGE__->flow_mech__preorder__select_products( ... )
                ->flow_mech__preorder__select_products_submit( ... )
                 ->flow_mech__preorder__select_products__submit_skus_submit( ... );

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__preorder__basket',
    page_description => 'Pre-Order Basket',
    page_url         => '/StockControl/Reservation/PreOrder/Basket?pre_order_id=',
    required_param   => 'Pre-Order Id',
);

=head2 flow_mech__preorder__basket__edit_items

    __PACKAGE__->flow_mech__preorder__basket__edit_items();

Emulates clicking on the 'Edit Items' button on the Pre-Order Basket page.

=cut

__PACKAGE__->create_form_method(
    method_name     => 'flow_mech__preorder__basket__edit_items',
    form_name       => 'edit_item_selection',
    form_description=> 'Pre-Order Basket Edit Items',
    assert_location => qr{/StockControl/Reservation/PreOrder/Basket},
    transform_fields=> sub {
        my ( $self, $fields ) = @_;

        return {
            skip_pws_customer_check => 1,
            ( $fields ? %{ $fields } : () ),
        };
    },
);

=head2 flow_mech__preorder__basket__change_discount

    __PACKAGE__->flow_mech__preorder__change_discount( $new_discount );

Change the Discount on the Pre-Order Basket page.

=cut

__PACKAGE__->create_form_method(
    method_name     => 'flow_mech__preorder__basket__change_discount',
    form_name       => 'basket__page_options_form',
    form_description=> 'Pre-Order Basket Change Discount',
    assert_location => qr{/StockControl/Reservation/PreOrder/Basket},
    transform_fields=> sub {
        my ( $self, $discount ) = @_;

        return {
            discount_to_apply => $discount,
        };
    },
);

=head2 flow_mech__preorder__basket__payment

    __PACKAGE__->flow_mech__preorder__basket__payment;

Go to the Pre-Order Payment page.

=cut

__PACKAGE__->create_form_method(
    method_name     => 'flow_mech__preorder__basket__payment',
    form_name       => 'basket__complete_pre_order_form',
    form_description=> 'Goto Pre-Order Payment page',
    assert_location => qr{/StockControl/Reservation/PreOrder/Basket},
    transform_fields=> sub {
        my ( $self, $args ) = @_;
        return $args;
    },
);

=head2 flow_mech__preorder__search

    __PACKAGE__->flow_mech__preorder__search;

Goes to the Pre-Order Search page using either Customer or Pre-Order Number.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__preorder__search',
    page_description => 'Pre-Order Search page',
    page_url         => '/StockControl/Reservation/PreOrder/PreOrderSearch',
);

=head2 flow_mech__preorder__search_submit

    __PACKAGE__->flow_mech__preorder__search_submit( {
            customer_number => 1231231
                or
            preorder_number => P121212
        } );

Will submit a search on the Pre-Order search page.

=cut

__PACKAGE__->create_form_method(
    method_name     => 'flow_mech__preorder__search_submit',
    form_name       => 'reservationPreOrderSearch',
    form_description=> 'Pre-Order Search Form',
    assert_location => qr{/StockControl/Reservation/PreOrder/PreOrderSearch},
    transform_fields=> sub {
        my ( $self, $args ) = @_;
        return $args;
    },
);

=head2 flow_mech__preorder__search_results__continue

    __PACKAGE__->flow_mech__preorder__search_results__continue( $pre_order_number );

Clicks on the 'continue' link for a Pre-Order in the Pre-Order Search Results table
next to the 'Status' of the Pre-Order. Pass in the Pre-Order number so the correct
'continue' link is clicked on.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__preorder__search_results__continue',
    link_description => 'Continue with Pre-Order',
    transform_fields=> sub {
        my ( $mech, $pre_order_number ) = @_;

        # remove leading 'P'
        $pre_order_number =~ s/^P//gi;

        return {
            text_regex => qr/continue/i,
            url_regex  => qr/pre_order_id=${pre_order_number}/,
        };
    },
    assert_location  => qr{/StockControl/Reservation/PreOrder/PreOrderSearch},
);


=head2 flow_mech__preorder__listing_page

    __PACKAGE__->flow_mech__preorder__listing_page()

Goes to the StockControl/Reservation/PreOrder/PreOrderList page

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__preorder__listing_page',
    page_description => 'Pre-Order Listing Page',
    page_url         => '/StockControl/Reservation/PreOrder/PreOrderList'
);

=head2 flow_mech_preorder_listing__change_operator

Sets the operator to given operator for PreOrder Listing page

=cut

__PACKAGE__->create_form_method(
    method_name => 'flow_mech_preorder_listing__change_operator',
    form_name => 'select_alternative_operator',
    form_description => 'Select Alternative Operator',
    assert_location => qr{/StockControl/Reservation/PreOrder/PreOrderList?},
    transform_fields => sub {
        my ($self, $operator_id) = @_;
        return {
            alt_operator_id => $operator_id
        };
    },
);

=head2 mech__reservation__pre_orders_on_hold

Fetch the reservation Pre-Order on hold page.

=cut

__PACKAGE__->create_fetch_method(
    method_name => 'mech__reservation__pre_orders_on_hold',
    page_description => 'Reservation - Pre-Orders on Hold',
    page_url => '/StockControl/Reservation/PreOrder/PreOrderOnhold',
);

=head2 mech__reservation__pre_orders_on_hold__operator_submit

Submit the alternative operator form on the reservation Pre-Order on hold page.

=cut

__PACKAGE__->create_form_method(
    method_name     => 'mech__reservation__pre_orders_on_hold__operator_submit',
    form_name       => 'select_alternative_operator',
    form_description=> 'Reservation - Pre-Orders on Hold - Change Operator',
    assert_location => qr{/StockControl/Reservation/PreOrder/PreOrderOnhold},
    transform_fields=> sub {
        my ( $self, $args ) = @_;
        return $args;
    },
);

=head2 mech__reservation__bulk_reassign

Fetch the reservation Bulk Reassign page.

=cut

__PACKAGE__->create_fetch_method(
    method_name => 'mech__reservation__bulk_reassign',
    page_description => 'Reservation - Bulk Reassign',
    page_url => '/StockControl/Reservation/BulkReassign',
);

=head2 mech__reservation__bulk_reassign__operator_submit

Submit the alternative operator form on the reservation Bulk Reassign page.

=cut

__PACKAGE__->create_form_method(
    method_name     => 'mech__reservation__bulk_reassign__operator_submit',
    form_name       => 'form__operator',
    form_description=> 'Reservation - Bulk Reassign - Change Operator',
    assert_location => qr{/StockControl/Reservation/BulkReassign},
    transform_fields=> sub {
        my ( $self, $args ) = @_;
        return $args;
    },
);

1;
