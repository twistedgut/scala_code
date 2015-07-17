package Test::StockControl::Reservations;

use NAP::policy "tt", 'test';

=head1 NAME

reservations.t

=head1 DESCRIPTION

On each channel:

=over

=item * reserve live products with stock

=item * reserve live products without stock

=item * reserve non-live products

=item * search customer with reservations

=item * search customer without reservations

=item * search customer that exists in XTracker

=item * search customer that doesn't exist in XTracker but does on PWS

=item * search customer that exists nowhere

=item * edit reservations

=item * cancel reservations

=item * summary page

=item * 'Overview' and 'View' left-hand nav entries

=item * 'Reports'?

=back

Also test emails and validation input on the product id and SKU fields.

#TAGS reservation inventory xpath needsrefactor loops pws whm

=head1 TODO

This whole test file needs to be improved so that each Test sets up its own data.
At the moment some tests rely on other tests.

=cut

use FindBin::libs;
use Data::Dump qw(pp);

use Test::More;

use Test::XT::Flow;
use Test::XTracker::Data;

use XTracker::Constants::FromDB qw( :authorisation_level :reservation_status :department );

use XTracker::Constants qw/:application/;

use JSON;
use Test::XTracker::Mechanize;

use base 'Test::Class';

# to be incremented each time we make a customer so we can try to
# ensure unique emails (we shouldn't really need to do this, please
# feel free to avoid the many-customers-with-same-email-address
# issue in some nicer way if you've got one)
my $customer_count = 0;

sub startup : Tests(startup => 1) {
    my ( $self ) = @_;
    $self->{flow} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Reservations',
            'Test::XT::Feature::Ch11n',
            'Test::XT::Feature::Ch11n::Reservations',
            'Test::XT::Data::ReservationSimple',
        ],
    );
    $self->{schema} = Test::XTracker::Data->get_schema;
    ( $self->{reservation_source}, $self->{alt_reservation_source} )    = $self->{schema}->resultset('Public::ReservationSource')
                                                                                ->search( {}, { limit => 2 } )->all;

    ( $self->{reservation_type}, $self->{alt_reservation_type} )        = $self->{schema}->resultset('Public::ReservationType')
                                                                                ->search( {}, { limit => 2 } )->all;

    $self->{enabled_channels} = $self->{schema}->resultset('Public::Channel')->enabled;
    cmp_ok( $self->{enabled_channels}->count, '>', 0, 'There are some enabled channels.' );

}

sub test_reservation_summary : Tests {
    my $self = shift;

    foreach my $channel ( $self->{enabled_channels}->all ) {

        $self->{flow}->mech__reservation__summary
            ->test_mech__reservation__summary_ch11n( $channel );

    }

}

sub create_reservations : Tests {
    my $self = shift;

    # Test creating reservations on all non fulfilment-only channels, as
    # reservations for fulfilment-only channels are not implemented.
    foreach my $channel ( $self->{enabled_channels}->fulfilment_only(0)->all ) {

        $self->test_create_reservation($channel);

    }

}

sub test_create_reservation_do {
    # Returns Array: ( BUTTON_FOUND, CAN_RESERVE, RESERVED )
    my ($self,  $product_channel, $variant, $channel, $customer, $success_str, $prod_live )    = @_;

    my $flow = $self->{flow};
    my @result = (1, 1, 1);

    for my $field ( qw{email is_customer_number} ) {

        # Search for product.
        $flow->mech__reservation__product_search
            ->mech__reservation__product_search_submit(
                { product_id => $product_channel->product_id, }
            );

        # Check for 'Create Reservation' button.

        my $config_section = $product_channel->channel->business->config_section;
        $result[0] = 0
            if $flow->mech->find_xpath( "//div[starts-with(\@class, 'tabWrapper-$config_section')]//input[starts-with(\@value, 'Create Reservation')]" )->size == 0;

        $flow->errors_are_fatal(0);

        # Attempt to create a reservation.
        $flow->mech__reservation__product_create_reservation_submit({
            variant_id      => $variant->id,
            channel_name    => $channel->name,
            channel_id      => $channel->id,
        });

        $flow->errors_are_fatal(1);

        my $error_message = $flow->mech->app_error_message;

        if ( defined $error_message && $error_message =~ /Insufficient permissions - It is not possible to create reservations on pre-uploaded SKU\(s\)/ ) {

            @result[1,2] = (0, 0);

        } else {

            # delete any existing reservations
            Test::XTracker::Data->delete_reservations( { customer => $customer } );

            $flow->errors_are_fatal(0);

            note "Test that when NO Source is Selected when Creating a Reservation it Errors";
            $flow->mech__reservation__create_reservation_submit(
                                { $field => $customer->$field }
                            );
            $error_message  = $flow->mech->app_error_message;
            like( $error_message, qr/You MUST Select a Source for the Reservation/i, "Got Error Message when NO Source was selected" );

            $flow->errors_are_fatal(1);

            note "Now Create a Reservation, Reserving a Product for a Customer";
            $flow->mech__reservation__create_reservation_submit(
                {
                    $field => $customer->$field,
                    reservation_source => $self->{reservation_source}->id,
                    reservation_type   => $self->{reservation_type}->id,
                }
            )->mech__reservation__create_reservation_submit();

            cmp_ok( $customer->discard_changes->reservations->count(), '==', 1, "ONE Reservation was Created" );
            my $reservation = $customer->reservations->first;
            my %reservation = $reservation->get_columns;
            my %expected    = (
                            variant_id            => $variant->id,
                            channel_id            => $channel->id,
                            status_id             => ( $prod_live ? $RESERVATION_STATUS__UPLOADED : $RESERVATION_STATUS__PENDING ),
                            reservation_source_id => $self->{reservation_source}->id,
                            reservation_type_id   => $self->{reservation_type}->id,
                        );
            my %got         = map { $_ => $reservation{ $_ } }
                                grep { exists( $expected{ $_ } ) }
                                    keys %reservation;
            is_deeply( \%got, \%expected, "Reservation Created is as Expected" );

            $result[2] = 0
                unless $flow->mech->app_status_message eq $success_str;

        }

    }

    return @result;

}


sub test_create_reservation {
    my ( $self, $channel ) = @_;

    my $channel_name = $channel->name;
    my $flow = $self->{flow};

    note "Channel: $channel_name";

    my $product_channel = Test::XTracker::Data->find_or_create_products({
        how_many                    => 1,
        channel_id                  => $channel->id,
        dont_ensure_live_or_visible => 1,
    })->[0]{product_channel};
    isa_ok( $product_channel, 'XTracker::Schema::Result::Public::ProductChannel' );

    # Make product not live
    my $variant = $product_channel->product->variants->slice(0,0)->single;

    # make sure there is stock
    Test::XTracker::Data->ensure_variants_stock( $variant->product_id );

    my $customer_email = 'perl+'.time().'-'.($customer_count++).'@net-a-porter.com';
    my $customer = Test::XTracker::Data->create_dbic_customer({
        channel_id => $channel->id,
        email => $customer_email,
    });
    isa_ok( $customer, 'XTracker::Schema::Result::Public::Customer' );

    my %departments = (
        'Customer Care'         => 0,
        'Customer Care Manager' => 1,
        'Personal Shopping'     => 1,
        'Fashion Advisor'       => 1,
    );

    my $success_str
        = 'Reservation successfully created for customer '
        . $customer->is_customer_number
        . ', '
        . $customer->first_name
        . ' '
        . $customer->last_name;

    while ( my ( $department, $can_reserve_nonlive ) = each %departments ) {

        note "Department: $department";

        Test::XTracker::Data->delete_reservations( { customer => $customer } );

        # Login as a specific department.
        $flow->login_with_permissions({
            perms => { $AUTHORISATION_LEVEL__MANAGER => [
                'Stock Control/Reservation',
            ]},
            dept => $department
        });

        # Run tests for live/non-live
        foreach my $live ( 0..1 ) {

            my $live_str = $live == 0 ? 'Non-Live' : 'Live';

            note "Live: $live_str";

            $product_channel->update( { live => $live } );
            my @result = $self->test_create_reservation_do( $product_channel, $variant, $channel, $customer, $success_str, $live );

            # ( BUTTON_FOUND, CAN_RESERVE, RESERVED )
            if ( $live == 0 && $can_reserve_nonlive == 0 ) {

                is_deeply( \@result, [ 0, 0, 0 ], "Make Reservation: $channel_name / $department / $live_str" );
                cmp_ok( $customer->discard_changes->reservations->count(), '==', 0, "NO Reservations were Created" );

            } else {

                is_deeply( \@result, [ 1, 1, 1 ], "Make Reservation: $channel_name / $department / $live_str" );

            }

        }

    }

}

sub _operator_history_ok {
    my ($self,  $reservation_id, $count, $message ) = @_;

    $message = "$message ($reservation_id)";

    # ----- Image -----

    note "$message: Checking if image exists and has correct data";

    # Find the image and return the object.
    my $node = $self->{flow}->mech->find_xpath('//div[@class="tabInsideWrapper"]//img[@class="classOperatorHistory" and @id="' . $reservation_id . '"]')->pop;

    if ( $count > 0 ) {
        # If we're expecting some history.

        isa_ok( $node, 'HTML::Element', "$message: Image for reservation $reservation_id" );

        if ( $node ) {

            cmp_ok( $node->attr('id'), '==', $node->id, "$message: Image for reservation $reservation_id has correct id" );
            like( $node->attr('title'), qr/$count change/, "$message: Image for reservation $reservation_id has correct tooltip of $count changes" );

        }

    } else {

        is( $node, undef, "$message: Image for reservation $reservation_id does not exist" );

    }

    # ----- AJAX -----

    note "$message: Checking AJAX request returns correct data";

    my $expected_response = $count > 0 ? 'OK' : 'FAIL';
    $self->{flow}->switch_tab("AJAX");
    my $mech = $self->{flow}->mech;
    my $json = JSON->new;

    # Make AJAX GET request.
    $mech->get_ok( "/AJAX/ReservationOperatorLog?reservation_id=$reservation_id", "$message: AJAX GET request" );

    # Decode response as JSON.
    my $data = eval { $json->decode( $mech->content ) } || diag $@ . "\n" . $mech->content;

    isa_ok( $data, 'HASH', "$message: AJAX data" );
    is( $data->{result}, $expected_response, "$message: AJAX request came back as $expected_response" );

    cmp_ok( @{$data->{data}}, '==', $count, "$message: AJAX request returned $count updates" );

    $self->{flow}->switch_tab("Default");
}

sub test_update_operator : Tests {
    my $self = shift;

    my $flow = $self->{flow};
    my $node;

    # Grab a product.
    my($channel, $pids) = Test::XTracker::Data->grab_products( { how_many => 1, channel => $self->{enabled_channels}->first } );
    isa_ok( $channel, 'XTracker::Schema::Result::Public::Channel', 'Product channel' );
    isa_ok( $pids, 'ARRAY', 'Product PIDS' );

    my $product = $pids->[0]{product};

    # Get the first variant.
    my $variant = $pids->[0]{variant};
    isa_ok( $variant, 'XTracker::Schema::Result::Public::Variant', 'First variant' );

    # Cancel any reservations for the SKU
    $variant->reservations->update( { status_id => $RESERVATION_STATUS__CANCELLED } );

    # Create a new customer.
    my $customer_id = Test::XTracker::Data->create_test_customer( channel_id => $channel->id );
    my $customer = $self->{schema}->resultset('Public::Customer')->find( { id => $customer_id } );
    isa_ok( $customer, 'XTracker::Schema::Result::Public::Customer', 'New customer' );

    # Get operator 'it.god'.
    my $operator = $self->{schema}->resultset('Public::Operator')->find( { username => 'it.god' } );
    isa_ok( $operator, 'XTracker::Schema::Result::Public::Operator', 'Operator it.god' );

    # Create a new reservation.
    my $reservation = $customer->create_related('reservations', {
        channel_id  => $channel->id,
        variant_id  => $pids->[0]->{variant_id},
        ordering_id => 1,
        operator_id => $operator->id,
        status_id   => $RESERVATION_STATUS__PENDING,
        reservation_source_id => $self->{reservation_source}->id,
    });
    isa_ok( $reservation, 'XTracker::Schema::Result::Public::Reservation', 'New reservation' );

    # Login as a specific department.
    $flow->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__OPERATOR => [
            'Stock Control/Reservation',
        ]},
        dept => 'Customer Care',
    });

    $flow->open_tab("AJAX");
    $flow->switch_tab("Default");

    # Search for product.
    $flow->mech__reservation__product_search
        ->mech__reservation__product_search_submit(
            { product_id => $product->id, }
        );

    $self->_operator_history_ok( $reservation->id, 0, 'Initial check' );

    # Make sure updating to the same user fails.
    $flow->mech__reservation__edit_reservation(
        $reservation->id,
        {
            operator_id => $operator->id,
            newOperator => $reservation->operator_id,
        }
    );

    is( $flow->mech->app_status_message, 'Reservation successfully updated.', 'Reservation updated without changing operator.' );
    $self->_operator_history_ok( $reservation->id, 0, 'Updated to same user' );

    # Edit the reservation for the first time.
    $flow->mech__reservation__edit_reservation(
        $reservation->id,
        {
            operator_id => $operator->id,
            newOperator => $APPLICATION_OPERATOR_ID,
        }
    );

    is( $flow->mech->app_status_message, 'Reservation successfully updated.', 'Reservation updated once.' );
    $self->_operator_history_ok( $reservation->id, 1, 'Updated as OPERATOR' );

    # Edit the reservation for the second time.
    $flow->mech__reservation__edit_reservation(
        $reservation->id,
        {
            operator_id => $operator->id,
            newOperator => $operator->id,
        }
    );

    is( $flow->mech->app_status_message, 'Reservation successfully updated.', 'Reservation updated twice.' );
    $self->_operator_history_ok( $reservation->id, 1, "Change back as OPERATOR should still be 1 as with 'Operator' level access means the operator changed shouldn't have happened" );

    # Increase authorisation level to MANAGER.
    Test::XTracker::Data->grant_permissions( $operator->id, 'Stock Control', 'Reservation', $AUTHORISATION_LEVEL__MANAGER  );

    # Edit the reservation for the third time.
    $flow->mech__reservation__edit_reservation(
        $reservation->id,
        {
            operator_id => $operator->id,
            newOperator => $operator->id,
        }
    );

    cmp_ok( $flow->mech->app_status_message, 'eq', 'Reservation successfully updated.', 'Reservation updated three times.' );
    $self->_operator_history_ok( $reservation->id, 2, 'Updated as MANAGER now with correct access it should have updated' );

}

sub test_list_and_edit_reservation : Tests {
    my $self    = shift;

    my $flow    = $self->{flow};

    # set the Sales Channel & Source for the Reservation
    $flow->channel( $self->{enabled_channels}->first );
    $flow->reservation_source( $self->{reservation_source} );

    my $customer    = $flow->customer;
    my $product     = $flow->product;

    Test::XTracker::Data->delete_reservations( { customer => $customer } );
    Test::XTracker::Data->delete_reservations( { product => $product } );

    my $reservation = $flow->reservation;
    my $variant     = $reservation->variant;

    # Login as a specific department.
    $flow->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__OPERATOR => [
            'Stock Control/Reservation',
        ]},
        dept => 'Customer Care',
    });

    note "Test the Customer's list of Reservations";
    $flow->mech__reservation__customer_search
            ->mech__reservation__customer_search_submit( { customer_number => $customer->is_customer_number } )
                ->mech__reservation__customer_search_results_click_on_customer( $customer->is_customer_number );

    my $page_data   = $flow->mech->as_data->{reservation_list};

    # check source is shown in list, should
    # only be one reservation in the list
    cmp_ok( @{ $page_data }, '==', 1, "Only Found ONE Reservation" );
    is( $page_data->[0]{SKU}{value}, $variant->sku, "Reservation is for the Correct SKU: " . $variant->sku );
    is( $page_data->[0]{Source}, $self->{reservation_source}->source, "Reservation Source shown in List" );

    note "Test the Variant's list of Reservations";
    $flow->mech__reservation__customer_reservation_list_click_on_sku( $variant->sku );

    # Get rows for highlighted customers
    my $highlighted_customers = $flow->mech->as_data->{highlighted_customers};
    if ( $customer->is_an_eip ) {
        ok( defined $highlighted_customers->{'is_customer_number-'.$customer->is_customer_number},
            "A highlighted row exists for the customer" );
        ok( $highlighted_customers->{'is_customer_number-'.$customer->is_customer_number}[4]->{span}->{title} =~ /Customer Category:.*EIP.*/,
            "Customer category is listed as EIP" );
    }
    else {
        ok ( ! defined $highlighted_customers->{'is_customer_number-'.$customer->is_customer_number},
            "The customer row is not highlighted" );
    }

    $page_data  = $flow->mech->as_data->{reservation_list}{ $flow->channel->name }{reservation}{ $variant->id }{customers};
    cmp_ok( @{ $page_data }, '==', 1, "Only Found ONE Customer Reservation for the SKU: " . $variant->sku );
    cmp_ok( $page_data->[0]{'No.'}, '==', $customer->is_customer_number, "Reservation is for the Correct Customer: " . $customer->is_customer_number );
    is( $page_data->[0]{Source}, $self->{reservation_source}->source, "Reservation Source shown in List" );

    note "Edit the Reservation's Source";
    # start with a NULL source
    $reservation->discard_changes->update( {
        reservation_source_id => undef,
        reservation_type_id   => undef,
    } );
    $flow->mech->reload;
    $flow->mech__reservation__edit_reservation(
                                $reservation->id,
                                {
                                    new_reservation_source_id => $self->{alt_reservation_source}->id,
                                    new_reservation_type_id   => $self->{alt_reservation_type}->id,
                                }
                            );
    cmp_ok( $reservation->discard_changes->reservation_source_id, '==', $self->{alt_reservation_source}->id,
                                        "NULL Source updated to: " . $self->{alt_reservation_source}->source );
    cmp_ok( $reservation->reservation_type_id, '==', $self->{alt_reservation_type}->id,
                                        "NULL Type updated to: " . $self->{alt_reservation_type}->type );

    $flow->mech__reservation__edit_reservation(
                                $reservation->id,
                                {
                                    new_reservation_source_id => $self->{reservation_source}->id,
                                    new_reservation_type_id   => $self->{reservation_type}->id,
                                }
                            );
    cmp_ok( $reservation->discard_changes->reservation_source_id, '==', $self->{reservation_source}->id,
                                        "Source updated back to: " . $self->{reservation_source}->source );
    cmp_ok( $reservation->reservation_type_id, '==', $self->{reservation_type}->id,
                                        "Type updated back to: " . $self->{reservation_type}->type );


    return;
}

sub test_operator_dropdown_list_in_live_listing : Tests {
    my $self    = shift;

    my $flow    = $self->{flow};

    # TODO: this whole test file needs to be improved
    #       so that each Test sets up its own data
    #       but at the moment some tests rely on other
    #       tests and I don't have time to fix that
    #       at this time, hence setting the data for
    #       this particular method here
    my $data = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Data::ReservationSimple',
        ],
    );

    # set the Sales Channel & Source for the Reservation
    $flow->channel( $self->{enabled_channels}->first );
    $flow->reservation_source( $self->{reservation_source} );

    my $customer    = $data->customer;
    my $product     = $data->product;
    my $variant     = $product->variants->first;

    Test::XTracker::Data->delete_reservations( { customer => $customer } );
    Test::XTracker::Data->delete_reservations( { product => $product } );

    note "Test list of Live reservations";
    note "First try when the dropdown should NOT appear";
    # Login as a specific department.
    $flow->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__OPERATOR => [
            'Stock Control/Reservation',
        ]},
        dept => 'Customer Care',
    });

    $flow->mech__reservation__summary;
    $flow->mech__reservation__summary_click_live;
    my $operator_list = $flow->mech->as_data->{operator_list};
    ok ( ! $operator_list, "Operator List is not available for Customer Care Dept" );

    note "Now try when the dropdown SHOULD appear";
    $flow->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__OPERATOR => [
            'Stock Control/Reservation',
        ]},
        dept => 'Personal Shopping',
    });

    $operator_list = undef;

    $flow->mech__reservation__summary;
    $flow->mech__reservation__summary_click_live;
    $operator_list = $flow->mech->as_data->{operator_list};
    ok ( $operator_list, "Operator List is available for Personal Shopping" );

    my $alt_operator = $self->{schema}->resultset('Public::Operator')->in_department( [
        $DEPARTMENT__PERSONAL_SHOPPING,
        $DEPARTMENT__FASHION_ADVISOR
    ] )->search({ name => { '!=' => 'DISABLED: IT God' } })->first;
    Test::XTracker::Data->delete_reservations( { operator => $alt_operator } );

    # create a Reservation for the Operator
    $data->variant( $variant );
    $data->operator( $alt_operator );
    my $reservation = $data->reservation;
    $reservation->update( { status_id => $RESERVATION_STATUS__UPLOADED } );

    note "Let's select reservations for operator: ".$alt_operator->name;

    $flow->mech__reservation__listing_reservations__change_operator( $alt_operator->id );
    my $page_data  = $flow->mech->as_data->{reservations}{ $flow->channel->name };

    ok( defined $page_data->[0]->[0]->{SKU}->{value}, "We have a SKU for the reservation" );

    ok( $page_data->[0]->[0]->{Delete}->{input_name} eq 'delete-'.$reservation->id,
        "We have the correct reservation for the alternative operator" );
}

sub test_reservation_options : Tests {
    my $self = shift;

    my $flow = $self->{flow};
    my $data = Test::XT::Flow->new_with_traits(
        traits => [ 'Test::XT::Data::ReservationSimple', ],
    );

    # Remove all existing reservations
    Test::XTracker::Data->delete_reservations( { product => $data->product } );
    Test::XTracker::Data->delete_reservations( { customer => $data->customer } );

    # Create a new reservation.
    my $reservation = $data->reservation;
    isa_ok( $reservation, 'XTracker::Schema::Result::Public::Reservation', 'New reservation' );

    # Login as a specific department.
    $flow->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__OPERATOR => [
            'Stock Control/Reservation',
        ]},
        dept => 'Customer Care',
    });

    # Navigate to reservation page
    $flow->mech__reservation__product_search;
    $flow->mech__reservation__product_search_submit( {product_id => $data->product->id});

    # XPath to access operation icons
    my $operation_title_xpath = '//a[@class="reservation_operation"]/img/@title';

    # Check reservation operations with a note
    my $tree = HTML::TreeBuilder::XPath->new_from_content($flow->mech->content);
    my @ops = $tree->findnodes_as_strings( $operation_title_xpath );
    is_deeply(\@ops, ['Upload', 'Edit (has note)', 'Delete'],
              'Reservation operation icons are correct with note present');

    # Remove the reservation note
    $flow->mech__reservation__edit_reservation(
         $reservation->id,
         { notes => ' ', }
    );
    is( $flow->mech->app_status_message, 'Reservation successfully updated.',
        'Reservation updated' );

    # Check reservation operations without a note
    my $tree2 = HTML::TreeBuilder::XPath->new_from_content($flow->mech->content);
    my @ops2 = $tree2->findnodes_as_strings( $operation_title_xpath );
    is_deeply(\@ops2, ['Upload', 'Edit', 'Delete'],
              'Reservation operation icons are correct with empty note');
}

=head2 test_reservation_uploaded_report

    Tests Reservation->Reports->Purchased page. It checks follwoing things:
    * When not in Personal shopper/Fashion Advisor  Alternative operator dropdown does not appear.
    * When PA/FA, you are able to switch and see some other operators reports.

=cut

sub test_reservation_uploaded_report : Tests {
    my $self = shift;

    my $flow = $self->{flow};
    my $data = Test::XT::Flow->new_with_traits(
        traits => [ 'Test::XT::Data::ReservationSimple', ],
    );

    # Remove all existing reservations
    Test::XTracker::Data->delete_reservations( { product => $data->product } );
    Test::XTracker::Data->delete_reservations( { customer => $data->customer } );

    # Create a new reservation.
    my $reservation = $data->reservation;

    # If expired and uploaded dates are not set, reservation does not seem to appear in Reports->Uploaded section
    my $future_day = DateTime->now( time_zone => 'local' ) + DateTime::Duration->new( days => 5 );
    $reservation->update( {
        status_id => $RESERVATION_STATUS__UPLOADED,
        date_expired => "$future_day",
        date_uploaded => \"now()"
    });
    isa_ok( $reservation, 'XTracker::Schema::Result::Public::Reservation', 'New reservation' );

    # Login as a specific department.
    $flow->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__OPERATOR => [
            'Stock Control/Reservation',
        ]},
        dept => 'Customer Care',
    });

    $flow->mech__reservation__uploaded_reports;

    my $operator = $flow->mech->as_data->{operator_list};
    ok ( ! $operator, "Operator List is not available for Customer Care Dept" );

    $flow->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__OPERATOR => [
            'Stock Control/Reservation',
        ]},
        dept => 'Personal Shopping',
    });

    $flow->mech__reservation__uploaded_reports;

    $operator = $flow->mech->as_data->{operator_list};
    ok ($operator, "Operator List is available for Peronal Shopping Dept" );

    my $alt_operator = $self->{schema}->resultset('Public::Operator')->in_department( [
            $DEPARTMENT__PERSONAL_SHOPPING,
            $DEPARTMENT__FASHION_ADVISOR
        ] )->search({ name => { '!=' => 'DISABLED: IT God' } })->first;

    note "Select reservations for operator: ". $alt_operator->name ."\n";


    #update reservation for this operator;
    $reservation->update({ operator_id => $alt_operator->id });

    $flow->mech__reservation__uploaded_report__change_operator( $alt_operator->id );
    my $alt_reservation = $alt_operator->reservations->search( {
         'status_id' => $RESERVATION_STATUS__UPLOADED
     } )->first;


    my $page_data = $flow->mech->as_data->{report};
    ok( defined $page_data->[0]->{SKU}->{value}, "We have a SKU for the reservation" );

}

sub test_reservation_search_form_validation : Tests {
    my $self = shift;
    my $flow = $self->{flow};

    # Login as a specific department.
    $flow->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__OPERATOR => [
            'Stock Control/Reservation',
        ]},
        dept => 'Customer Care',
    });

    my @tests = (
        {
            # Invalid product id and SKU
            form => {
                sku => 'not-a-valid-sku-1234',
                product_id => 'this is not an integer',
            },
            expected_error => 'Product ID "this is not an integer" is invalidSKU "not-a-valid-sku-1234" is invalid',
            test_message => "Found correct 'sku is invalid' and 'product id is invalid' warning messages",
        },
        {
            # Invalid SKU
            form => { sku => 'not-a-valid-sku-1234' },
            expected_error => 'SKU "not-a-valid-sku-1234" is invalid',
            test_message => "Found correct 'sku is invalid' warning messages",
        },
        {
            # Invalid product id
            form => { product_id => 'this is not an integer' },
            expected_error => 'Product ID "this is not an integer" is invalid',
            test_message => "Found correct 'product id is invalid' warning messages",
        }
    );

    foreach my $test_args ( @tests ) {
        $flow->mech__reservation__product_search
            ->catch_error(
                $test_args->{expected_error},
                $test_args->{test_message},
                'mech__reservation__product_search_submit' => $test_args->{form}
        );
    }
}

sub test_reservation_search_form_validation_product_returned : Tests {
    my $self = shift;
    my $flow = $self->{flow};

    my $data = Test::XT::Flow->new_with_traits(
        traits => [ 'Test::XT::Data::ReservationSimple' ],
    );
    my $product = $data->product;

    $flow->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__OPERATOR => [
            'Stock Control/Reservation',
        ]},
        dept => 'Customer Care',
    });

    # Sending an invalid sku, but returning a product from a
    # valid product id _should not_ show errors.
    lives_ok( sub {
        $flow->mech__reservation__product_search
            ->mech__reservation__product_search_submit({
                product_id => $product->id,
                sku        => 'ifdvoj-321'
        });
    }, 'invalid sku with a valid product id should not die');
}

Test::Class->runtests;

1;
