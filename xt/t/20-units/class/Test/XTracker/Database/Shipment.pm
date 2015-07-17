package Test::XTracker::Database::Shipment;
use NAP::policy "tt",     'test';

use parent "NAP::Test::Class";

=head1 NAME

Test::XTracker::Database::Shipment

=cut

use Test::XTracker::Data;
use Test::XTracker::RunCondition    export => [ qw( $distribution_centre ) ];
use Test::More::Prefix              qw( test_prefix );
use Test::XT::Data;
use Test::XTracker::Data::Shipping;

use XTracker::Config::Local         qw( config_var );
use XTracker::Database::Shipment qw(
    get_address_shipping_charges
    get_shipment_id_for_awb
    check_shipment_restrictions
);
use XTracker::Constants::FromDB qw(
    :country
    :shipment_item_status
    :shipment_status
    :ship_restriction
    :sub_region
);
use XTracker::Database::Address;
use XT::Service::Designer;


# this is done once, when the test starts
sub test_startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup;

    # Turn on mocking of the designer service.
    $self->_mock_designer_service;

    # need to use this schema because
    # rollbacks don't work otherwise
    # and I can't figure out why!
    $self->{schema}     = Test::XTracker::Data->get_schema;

    $self->{dc_currency}= $self->rs('Public::Currency')->find( {
        currency => config_var('Currency','local_currency_code'),
    } );
    $self->{dc_country} = $self->rs('Public::Country')->find( {
        country => config_var("DistributionCentre","country"),
    } );
    $self->{ship_restrictions} = {
        map { $_->id => $_ } $self->rs('Public::ShipRestriction')->all
    };
}

sub test_shutdown : Test( shutdown => no_plan ) {
    my $self = shift;

    # Make sure we restore the original designer service.
    $self->_mock_designer_service_off;

}

# this is done before every test
sub test_setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->{data}   = Test::XT::Data->new_with_traits( {
        traits  => [
            'Test::XT::Data::Order',
        ],
    } );

    $self->schema->txn_begin;
}

# this is done after every test
sub test_teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->schema->txn_rollback;
}


=head2 test_get_address_shipping_charges_across_channel_shipping_charge

=cut

sub test_get_address_shipping_charges_across_channel_shipping_charge : Tests() {
    my $self = shift;

    my $channel_shipping_charge_variations = [
        {
            prefix => "NAP, Premier Nom",
            setup => {
                channel                     => Test::XTracker::Data->channel_for_nap(),
                shipping_charge_description => "Premier Daytime",
                address_in                  => "current_dc_premier",
            },
        },
        {
            prefix => "MRP, Premier Nom",
            setup => {
                channel                     => Test::XTracker::Data->channel_for_mrp(),
                shipping_charge_description => "Premier Daytime",
                address_in                  => "current_dc_premier",
            },
        },
        {
            prefix => "MRP, Domestic Nom",
            setup => {
                channel                     => Test::XTracker::Data->channel_for_mrp(),
                shipping_charge_description => "UK Express - Nominated Day",
                address_in                  => "current_dc_other",
            },
        },
    ];

    for my $case (@$channel_shipping_charge_variations) {
        test_prefix($case->{prefix});
        $self->test_get_address_shipping_charges($case)
    }
}

=head2 test_get_address_shipping_charges

=cut

sub test_get_address_shipping_charges {
    my ($self, $channel_case) = @_;

    my $channel = $channel_case->{setup}->{channel};
    my $nominated_day_row = $self->shipping_charge_rs->search({
        description => $channel_case->{setup}->{shipping_charge_description},
        channel_id  => $channel->id,
    })->first;
    if(!$nominated_day_row) {
        note "*** Skipping test for shipping charge ($channel_case->{setup}->{shipping_charge_description}), since it doesn't exist on this DC";
        return;
    }
    my $nominated_day_sku = $nominated_day_row->sku;

    my $address = Test::XTracker::Data->create_order_address_in(
        $channel_case->{setup}->{address_in},
    );
    my $shipment_address = get_address_info($self->schema, $address->id);

    my $test_cases = [
        {
            description => "Don't exclude, expect all skus",
            setup => {
                exclude_nominated_day => 0,
                current_sku           => undef,
                customer_facing_only  => 0,
            },
            expected => {
                nominated_day_present       => 1,
                present_sku                 => $nominated_day_sku,
                non_customer_facing_present => 1,
            },
        },
        {
            description => "Exclude, expect no Nominated Day skus",
            setup => {
                exclude_nominated_day => 1,
                current_sku           => undef,
            },
            expected => {
                nominated_day_present => 0,
            },
        },
        {
            description => "customer facing only, no non-customer facing present",
            setup => {
                exclude_nominated_day => 0,
                current_sku           => undef,
                customer_facing_only  => 1,
            },
            expected => {
                nominated_day_present       => 1,
                present_sku                 => $nominated_day_sku,
                non_customer_facing_present => 0,
            },
        },

        {
            description => "Don't exclude, keep a sku, expect all skus",
            setup => {
                exclude_nominated_day => 0,
                current_sku           => $nominated_day_sku,
            },
            expected => {
                nominated_day_present => 1,
                present_sku           => $nominated_day_sku,
            },
        },
        {
            description => "Exclude, but keep a sku, expect all skus",
            setup => {
                exclude_nominated_day => 1,
                current_sku           => $nominated_day_sku,
            },
            expected => {
                nominated_day_count   => 1,
                nominated_day_present => 1,
                present_sku           => $nominated_day_sku,
            },
        },

    ];
    for my $case (@$test_cases) {
        note("*** $case->{description}");
        my $exclude_nominated_day = 0;

        my %shipping_charges = get_address_shipping_charges(
            $self->dbh,
            $channel->id,
            {
                country  => $shipment_address->{country},
                postcode => $shipment_address->{postcode},
                state    => $shipment_address->{county},
            },
            {
                exclude_nominated_day   => $case->{setup}->{exclude_nominated_day},
                always_keep_sku         => $case->{setup}->{current_sku},
                customer_facing_only    => $case->{setup}->{customer_facing_only},
            },
        );
        my %sku_shipping_charges = map { $_->{sku} => $_ } values %shipping_charges;

        if(my $present_sku = $case->{expected}->{present_sku}) {
            ok($sku_shipping_charges{$present_sku}, "SKU ($present_sku) is present");
        }

        my @nominated_day_charges = grep { $_->{is_nominated_day} } values %sku_shipping_charges;
        if ($case->{expected}->{nominated_day_present}) {
            ok(@nominated_day_charges + 0, "Got some Nominated Day skus for the premier zone");
        }
        else {
            ok(! @nominated_day_charges + 0 , "Got no Nominated Day skus for the premier zone");
        }

        if (defined $case->{expected}->{non_customer_facing_present}) {
            my @internal_charges = grep { ! $_->{is_customer_facing} } values %sku_shipping_charges;
            if ($case->{expected}->{non_customer_facing_present}) {
                ok(@internal_charges + 0, "Got some Customer facing skus");
            }
            else {
                ok(! @internal_charges + 0 , "Got no Customer facing skus");
            }
        }

        my $nominated_day_count = $case->{expected}->{nominated_day_count};
        if(defined($nominated_day_count)) {
            is(
                @nominated_day_charges + 0,
                $nominated_day_count,
                "Correct number of Nominated Day SKUs present",
            );
        }

    }
}

sub test_check_shipment_restrictions_general : Tests() {
    my $self = shift;

    # Get a new order.
    my $channel = Test::XTracker::Data->any_channel();
    my $order_details   = $self->data->new_order(
        channel     => $channel,
        products    => 1,
    );

    my $shipment   = $order_details->{shipment_object};
    my $address    = $order_details->{address_object};
    my $products   = $order_details->{product_objects};
    my $product    = $products->[0]{product};

    # this will get the 'Chinese Origin' restriction
    my ( $country_pass, $country_fail ) = Test::XTracker::Data::Shipping
        ->get_restriction_countries_and_update_product( $product );

    # Configure the tests.
    my %tests = (
        'Current address PASS (no email expected)' => {
            expected_result => 1,
            expected_flags  => { restrict => 0, notify => 0, silent_restrict => 0, all_silent => 0 },
            email_recipients => [],
            prepare => sub {
                $self->_set_value( { record => $_[0], field => 'country' }, $country_pass->country );
            },
            parameters => {
                # address_ref - testing without, as this is the default
            },
        },
        'Current address FAIL (with emails)' => {
            expected_result => 0,
            expected_flags  => { restrict => 1, notify => 0, silent_restrict => 0, all_silent => 0 },
            email_recipients => [
                config_var( 'Email_' . $channel->business->config_section, 'customercare_email' ),
                config_var( 'Email_' . $channel->business->config_section, 'fulfilment_email'   ),
                config_var( 'Email_' . $channel->business->config_section, 'shipping_email'     ),
            ],
            prepare => sub {
                $self->_set_value( { record => $_[0], field => 'country' }, $country_fail->country );
            },
            parameters => {
                address_ref => undef, # testing by passing explicitly
                send_email  => 1,
            },
        },
        'Different address PASS (no emails expected)' => {
            expected_result => 1,
            expected_flags  => { restrict => 0, notify => 0, silent_restrict => 0, all_silent => 0 },
            email_recipients => [],
            prepare => sub {
                $self->_set_value( { record => $_[0], field => 'country' }, $country_fail->country );
            },
            parameters => {
                address_ref => {
                    county       => '',
                    postcode     => '',
                    country      => $country_pass->country,
                    country_code => $country_pass->code,
                    sub_region   => $country_pass->sub_region->sub_region,
                },
            },
        },
        'Different address FAIL (without emails)' => {
            expected_result => 0,
            expected_flags  => { restrict => 1, notify => 0, silent_restrict => 0, all_silent => 0 },
            email_recipients => [],
            prepare => sub {
                $self->_set_value( { record => $_[0], field => 'country' }, $country_pass->country );
            },
            parameters => {
                address_ref => {
                    county       => '',
                    postcode     => '',
                    country      => $country_fail->country,
                    country_code => $country_fail->code,
                    sub_region   => $country_fail->sub_region->sub_region,
                },
                send_email  => 0,
            },
        },
        "FAIL: Send an Email when a Notification Restriction, but 'send_email' has NOT been explicitly asked for"   => {
            expected_result => 0,
            expected_flags  => { restrict => 0, notify => 1, silent_restrict => 0, all_silent => 0 },
            email_recipients => [
                config_var( 'Email_' . $channel->business->config_section, 'customercare_email' ),
                config_var( 'Email_' . $channel->business->config_section, 'fulfilment_email'   ),
                config_var( 'Email_' . $channel->business->config_section, 'shipping_email'     ),
            ],
            prepare => sub {
                Test::XTracker::Data->remove_config_group('ShippingRestrictionActions');
                Test::XTracker::Data->create_config_group('ShippingRestrictionActions', {
                    settings    => [
                        { setting => 'Chinese origin', value => 'notify' },
                    ],
                } );
                $self->_set_value( { record => $_[0], field => 'country' }, $country_fail->country );
            },
            parameters => {
                # just use the address on the Shipment
            },
        },
        "FAIL: Send an Email when a Notification Restriction, but 'send_email' HAS been explicitly asked for"   => {
            expected_result => 0,
            expected_flags  => { restrict => 0, notify => 1, silent_restrict => 0, all_silent => 0 },
            email_recipients => [
                config_var( 'Email_' . $channel->business->config_section, 'customercare_email' ),
                config_var( 'Email_' . $channel->business->config_section, 'fulfilment_email'   ),
                config_var( 'Email_' . $channel->business->config_section, 'shipping_email'     ),
            ],
            prepare => sub {
                Test::XTracker::Data->remove_config_group('ShippingRestrictionActions');
                Test::XTracker::Data->create_config_group('ShippingRestrictionActions', {
                    settings    => [
                        { setting => 'Chinese origin', value => 'notify' },
                    ],
                } );
                $self->_set_value( { record => $_[0], field => 'country' }, $country_fail->country );
            },
            parameters => {
                address_ref => {
                    county       => '',
                    postcode     => '',
                    country      => $country_fail->country,
                    country_code => $country_fail->code,
                    sub_region   => $country_fail->sub_region->sub_region,
                },
                send_email  => 1,
            },
        },
        "FAIL: Pass in 'never_send_email' when there is a Notification Restriction and email should NOT be sent"   => {
            expected_result => 0,
            expected_flags  => { restrict => 0, notify => 1, silent_restrict => 0, all_silent => 0 },
            email_recipients => [
            ],
            prepare => sub {
                Test::XTracker::Data->remove_config_group('ShippingRestrictionActions');
                Test::XTracker::Data->create_config_group('ShippingRestrictionActions', {
                    settings    => [
                        { setting => 'Chinese origin', value => 'notify' },
                    ],
                } );
                $self->_set_value( { record => $_[0], field => 'country' }, $country_fail->country );
            },
            parameters => {
                never_send_email => 1,
            },
        },
        "FAIL: Pass in 'never_send_email' and 'send_email' params and email should still NOT be sent ('never_send_email' takes presedence)" => {
            expected_result => 0,
            expected_flags  => { restrict => 1, notify => 0, silent_restrict => 0, all_silent => 0 },
            email_recipients => [
            ],
            prepare => sub {
                $self->_set_value( { record => $_[0], field => 'country' }, $country_fail->country );
            },
            parameters => {
                never_send_email => 1,
                send_email      => 1,
            },
        },
    );

    # Redefine send_email and remember the original.
    my @emails;
    my $old_send_email = \&XTracker::Database::Shipment::send_email;
    no warnings 'redefine';
    *XTracker::Database::Shipment::send_email = sub { push @emails, \@_ };
    use warnings 'redefine';

    # Do the tests.
    while ( my ( $name, $test ) = each %tests ) {

        note $name;

        # set these to default to 'restrict'
        Test::XTracker::Data->remove_config_group('ShippingRestrictionActions');
        Test::XTracker::Data->create_config_group('ShippingRestrictionActions', {
            settings    => [
                { setting => 'Chinese origin', value => 'restrict' },
            ],
        } );

        # Get the email recipients, if we have some. This also determines
        # how many emails we expect to have sent.
        my @email_recipients = @{ $test->{email_recipients} };

        # Execute the preperation.
        $test->{prepare}->( $address );

        # Call the method to be tested.
        my $result = check_shipment_restrictions(
            $self->schema, {
                shipment_id => $shipment->id,
                %{ $test->{parameters} }
            }
        );

        # Did it fail/pass as expected?
        my $restricted_products = delete $result->{restricted_products};
        cmp_ok(
            ! keys %{ $restricted_products },
            '==',
            $test->{expected_result},
            'check_shipment_restrictions '
                . ( $test->{expected_result} ? 'passed' : 'failed' )
                . ' as expected.'
        );
        is_deeply( $result, $test->{expected_flags}, "flags set as expected" );

        # Check we've sent the right number of emails and they where sent to
        # the correct addresses.

        cmp_ok( @emails, '==', @email_recipients, 'Sent the right number of emails' );

        foreach my $index ( 0 .. $#emails ) {
            my $email = $emails[$index];

            cmp_ok( $email->[2], 'eq', $email_recipients[$index], 'Correct recipient' );
            cmp_ok( $email->[3], 'eq', 'Shipment Containing Restricted Products', 'Correct subject' );
            cmp_ok( $email->[4], 'eq', "Shipment Nr: " . $shipment->id . "\n\nRestricted Products:\n  " . $product->id . " : Chinese origin product\n" );

        }

        # Clear the emails.
        @emails = ();

    }

    # Return send_email to it's original.
    no warnings 'redefine';
    *XTracker::Database::Shipment::send_email = $old_send_email;
    use warnings 'redefine';
}

=head2 test_check_shipment_restrictions

Test Shipping Restrictions such as HAZMAT, CITIES etc.

=cut

sub test_check_shipment_restrictions : Tests() {
    my $self    = shift;

    my $channel = Test::XTracker::Data->any_channel();
    my $order_details   = $self->data->new_order(
        channel     => $channel,
        products    => 1,
    );

    my $shipment    = $order_details->{shipment_object};
    my $pids        = $order_details->{product_objects};
    my $address_rec = $order_details->{address_object};

    my $dc_country  = $self->{dc_country};
    my $product_rec = $pids->[0]{product};
    my $ship_attr   = $product_rec->shipping_attribute;
    my $ship_restrict_rs = $product_rec->search_related('link_product__ship_restrictions');

    # common to all DCs
    my $general = {
        'RESTRICTION 1: Country of Origin' => {
            config_settings                 => {
                'Chinese origin'            => 'restrict',
            },
            reason                          => 'Chinese origin product',
            restrict                        => 1,
            silent_restrict                 => 0,
            all_silent                      => 0,
            notify                          => 0,
            product                         => {
                record                      => $ship_attr,
                field                       => 'country_id',
                values_on                   => $COUNTRY__CHINA,
                value_off                   => $dc_country->id,
            },
            address                         => {
                record                      => $address_rec,
                field                       => 'country',
                values_on                   => [ 'Mexico' ],
                value_off                   => $dc_country->country,
            },
        },
        'RESTRICTION 5: Designer Service' => {
            config_settings                 => {
                'Designer Country'          => 'restrict',
            },
            reason                          => 'Designer destination country',
            restrict                        => 1,
            silent_restrict                 => 0,
            all_silent                      => 0,
            notify                          => 0,
            product                         => {
                record                      => $ship_attr,
                field                       => 'country_id',
                values_on                   => $dc_country->id,
                value_off                   => $dc_country->id,
            },
            address                         => {
                record                      => $address_rec,
                field                       => 'country',
                values_on                   => $dc_country->country,
                value_off                   => $dc_country->country,
            },
            designer_service                => {
                values_on                   => sub { [ $address_rec->discard_changes->country_table->code ] },
                value_off                   => sub { [ ] },
            },
        },
        'RESTRICTION 5: Designer Service Dies - All Silent' => {
            config_settings                 => {
                'Designer Service Error'    => 'silent_restrict',
            },
            reason                          => 'Designer service error',
            restrict                        => 1,
            silent_restrict                 => 1,
            all_silent                      => 1,
            notify                          => 0,
            product                         => {
                record                      => $ship_attr,
                field                       => 'country_id',
                values_on                   => $dc_country->id,
                value_off                   => $dc_country->id,
            },
            address                         => {
                record                      => $address_rec,
                field                       => 'country',
                values_on                   => $dc_country->country,
                value_off                   => $dc_country->country,
            },
            designer_service                => {
                values_on                   => sub { 'Service Dies' },
                value_off                   => sub { [ ] },
            },
        },
        'RESTRICTION 5: Designer Service Dies - NOT All Silent' => {
            config_settings                 => {
                'Chinese origin'            => 'restrict',
                'Designer Service Error'    => 'silent_restrict',
            },
            reason                          => 'Designer service error',
            restrict                        => 1,
            silent_restrict                 => 1,
            all_silent                      => 0,
            notify                          => 0,
            product                         => {
                record                      => $ship_attr,
                field                       => 'country_id',
                values_on                   => $COUNTRY__CHINA,
                value_off                   => $dc_country->id,
            },
            address                         => {
                record                      => $address_rec,
                field                       => 'country',
                values_on                   => [ 'Mexico' ],
                value_off                   => $dc_country->country,
            },
            designer_service                => {
                values_on                   => sub { 'Service Dies' },
                value_off                   => sub { [ ] },
            },
        },
    };
    my %tests   = (
        DC1 => {
            'RESTRICTION 2: CITES' => {
                config_settings             => {
                    CITES                   => 'restrict',
                },
                reason                      => 'CITES product',
                restrict                    => 1,
                silent_restrict             => 0,
                all_silent                  => 0,
                notify                      => 0,
                product                     => {
                    field                   => 'cites_restricted',
                    record                  => $ship_attr,
                    values_on               => 1,
                    value_off               => 0,
                },
                address                     => {
                    field                   => 'country',
                    record                  => $address_rec,
                    values_on               => $self->_non_eu_member_states,
                    value_off               => $dc_country->country,
                },
            },
            'RESTRICTION 6: HAZMAT LQ (Limited Quantity) - by Country' => {
                config_settings             => {
                    HAZMAT_LQ               => 'restrict',
                },
                reason                      => 'HAZMAT LQ product',
                restrict                    => 1,
                silent_restrict             => 0,
                all_silent                  => 0,
                notify                      => 0,
                product                     => {
                    field                   => 'ship_restriction_id',
                    resultset               => $ship_restrict_rs,
                    values_on               => $SHIP_RESTRICTION__HZMT_LQ,
                    value_off               => undef,
                },
                address                     => {
                    field                   => 'country',
                    record                  => $address_rec,
                    values_on               => $self->_ship_restriction_not_allowed_countries( $SHIP_RESTRICTION__HZMT_LQ ),
                    value_off               => $self->_ship_restriction_allowed_countries( $SHIP_RESTRICTION__HZMT_LQ )->[0],
                },
            },
            'RESTRICTION 6: HAZMAT LQ (Limited Quantity) - by Postcode' => {
                config_settings             => {
                    HAZMAT_LQ               => 'restrict',
                },
                reason                      => 'HAZMAT LQ product',
                restrict                    => 1,
                silent_restrict             => 0,
                all_silent                  => 0,
                notify                      => 0,
                product                     => {
                    field                   => 'ship_restriction_id',
                    resultset               => $ship_restrict_rs,
                    values_on               => $SHIP_RESTRICTION__HZMT_LQ,
                    value_off               => undef,
                },
                address                     => {
                    # the default Address's Country is that of the DC, so the U.K. for DC1
                    field                   => 'postcode',
                    record                  => $address_rec,
                    values_on               => $self->_ship_restriction_not_allowed_postcodes(
                                                    $SHIP_RESTRICTION__HZMT_LQ,
                                                    'United Kingdom',
                                                    ' 4FW',     # just add a suffix to every postcode
                                                ),
                    value_off               => 'NW1',   # anywhere not in Scotland/Northern Ireland
                },
            },
            %{ $general },
        },
        DC2 => {
            # for many years Shipping to an EU Member State from U.S. was a Restriction
            # but it turned out that was wrong and it shouldn't be, this test makes
            # sure that condition hasn't been re-instated, see CANDO-1309
            'RESTRICTION 1: Chinese Country of Origin, Destination of an EU State SHOULD NOT BE A RESTRICTION OR NOTIFICATION' => {
                config_settings             => {
                    'Chinese origin'        => 'restrict',
                },
                reason                      => 'Chinese origin product',
                restrict                    => 1,
                silent_restrict             => 0,
                all_silent                  => 0,
                notify                      => 0,
                product                     => {
                    record                  => $ship_attr,
                    field                   => 'country_id',
                    values_on               => $COUNTRY__CHINA,
                    value_off               => $dc_country->id,
                },
                address                     => {
                    record                  => $address_rec,
                    field                   => 'country',
                    values_on               => [ 'Mexico' ],
                    # this will check that the bit of the test loop that checks
                    # when a Restricted Product is used for an OK Address, so it
                    # should still pass when the destination is an EU State
                    value_off               => $self->_eu_member_states->[0],     # pick any EU State
                },
            },
            'RESTRICTION 2: CITES Outside U.S.' => {
                config_settings             => {
                    CITES                   => 'notify',
                },
                reason                      => 'CITES product',
                restrict                    => 0,
                silent_restrict             => 0,
                all_silent                  => 0,
                notify                      => 1,
                product                     => {
                    field                   => 'cites_restricted',
                    record                  => $ship_attr,
                    values_on               => 1,
                    value_off               => 0,
                },
                address                     => {
                    field                   => 'country',
                    record                  => $address_rec,
                    values_on               => $self->_every_other_country_but('United States'),
                    value_off               => 'United States',
                },
            },
            'RESTRICTION 2: CITES for California' => {
                config_settings             => {
                    CITES                   => 'notify',
                },
                reason                      => 'CITES product',
                restrict                    => 0,
                silent_restrict             => 0,
                all_silent                  => 0,
                notify                      => 1,
                product                     => {
                    field                   => 'cites_restricted',
                    record                  => $ship_attr,
                    values_on               => 1,
                    value_off               => 0,
                },
                address                     => {
                    field                   => 'county',
                    record                  => $address_rec,
                    values_on               => 'CA',
                    value_off               => { county => 'NY', country => 'United States' },
                },
            },
            'RESTRICTION 2: CITES for California - in lowercase' => {
                config_settings             => {
                    CITES                   => 'notify',
                },
                reason                      => 'CITES product',
                restrict                    => 0,
                silent_restrict             => 0,
                all_silent                  => 0,
                notify                      => 1,
                product                     => {
                    field                   => 'cites_restricted',
                    record                  => $ship_attr,
                    values_on               => 1,
                    value_off               => 0,
                },
                address                     => {
                    field                   => 'county',
                    record                  => $address_rec,
                    values_on               => 'ca',
                    value_off               => { county => 'NY', country => 'United States' },
                },
            },
            'RESTRICTION 3: Fish & Wildlife Outside U.S.' => {
                config_settings             => {
                    'Fish & Wildlife'       => 'notify',
                },
                reason                      => 'Fish & Wildlife product',
                restrict                    => 0,
                silent_restrict             => 0,
                all_silent                  => 0,
                notify                      => 1,
                product                     => {
                    field                   => 'fish_wildlife',
                    record                  => $ship_attr,
                    values_on               => 1,
                    value_off               => 0,
                },
                address                     => {
                    field                   => 'country',
                    record                  => $address_rec,
                    values_on               => $self->_every_other_country_but('United States'),
                    value_off               => 'United States',
                },
            },
            'RESTRICTION 3: Fish & Wildlife for California' => {
                config_settings             => {
                    'Fish & Wildlife'       => 'notify',
                },
                reason                      => 'Fish & Wildlife product',
                restrict                    => 0,
                silent_restrict             => 0,
                all_silent                  => 0,
                notify                      => 1,
                product                     => {
                    field                   => 'fish_wildlife',
                    record                  => $ship_attr,
                    values_on               => 1,
                    value_off               => 0,
                },
                address                     => {
                    field                   => 'county',
                    record                  => $address_rec,
                    values_on               => 'CA',
                    value_off               => { county => 'NY', country => 'United States' },
                },
            },
            'RESTRICTION 3: Fish & Wildlife for California - in lowercase' => {
                config_settings             => {
                    'Fish & Wildlife'       => 'notify',
                },
                reason                      => 'Fish & Wildlife product',
                restrict                    => 0,
                silent_restrict             => 0,
                all_silent                  => 0,
                notify                      => 1,
                product                     => {
                    field                   => 'fish_wildlife',
                    record                  => $ship_attr,
                    values_on               => 1,
                    value_off               => 0,
                },
                address                     => {
                    field                   => 'county',
                    record                  => $address_rec,
                    values_on               => 'ca',
                    value_off               => { county => 'NY', country => 'United States' },
                },
            },
            'RESTRICTION 4: HAZMAT' => {
                config_settings             => {
                    HAZMAT                  => 'restrict',
                },
                reason                      => 'HAZMAT product',
                restrict                    => 1,
                silent_restrict             => 0,
                all_silent                  => 0,
                notify                      => 0,
                product                     => {
                    field                   => 'is_hazmat',
                    record                  => $ship_attr,
                    values_on               => 1,
                    value_off               => 0,
                },
                address                     => {
                    field                   => 'country',
                    record                  => $address_rec,
                    values_on               => $self->_every_other_country_but('United States'),
                    value_off               => 'United States',
                },
            },
            %{ $general },
        },
        DC3 => {
            'RESTRICTION 2: CITES Outside Hong Kong' => {
                config_settings             => {
                    CITES                   => 'restrict',
                },
                reason                      => 'CITES product',
                restrict                    => 1,
                silent_restrict             => 0,
                all_silent                  => 0,
                notify                      => 0,
                product                     => {
                    field                   => 'cites_restricted',
                    record                  => $ship_attr,
                    values_on               => 1,
                    value_off               => 0,
                },
                address                     => {
                    field                   => 'country',
                    record                  => $address_rec,
                    values_on               => $self->_every_other_country_but('Hong Kong'),
                    value_off               => 'Hong Kong',
                },
            },
            %{ $general },
        },
    );

    foreach my $restriction ( sort keys %{ $tests{ $distribution_centre } } ) {
        note "TESTING Restriction: ${restriction}";
        my $test    = $tests{ $distribution_centre }{ $restriction };

        # Make sure we only have all the required restrictions.
        Test::XTracker::Data->remove_config_group('ShippingRestrictionActions');
        Test::XTracker::Data->create_config_group('ShippingRestrictionActions', {
            settings => [
                map( {
                    setting => $_,
                    # The IGNORE here is not magical in any way, it just
                    # means that the 'flag' that gets set is '__ignore__',
                    # which results in no other flags (such as restrict,
                    # notify, etc) being set.
                    value   => $test->{config_settings}->{ $_ } // '__IGNORE__',
                }, (
                    'Chinese origin',
                    'CITES',
                    'Fish & Wildlife',
                    'HAZMAT',
                    'Designer Service Error',
                    'Designer Country',
                    'HAZMAT_LQ',
                ) )
            ],
        } );

        # change the Product for the restriction
        my $product         = $test->{product};
        my $prd_values_on   = $product->{values_on};
        $prd_values_on      = ( ref( $prd_values_on ) ? $prd_values_on : [ $prd_values_on ] );

        # Change the Address for the restriction
        my $address         = $test->{address};
        my $addr_values_on  = $address->{values_on};
        $addr_values_on     = ( ref( $addr_values_on ) ? $addr_values_on : [ $addr_values_on ] );

        # Designer service on/off. We use CodeRefs here, because the data
        # that this relies on is updated just before check_shipment_restrictions
        # is called, so we need to execute these after that occurs.
        my $designer_service_on  = $test->{designer_service}->{values_on} // sub { [] };
        my $designer_service_off = $test->{designer_service}->{value_off} // sub { [] };

        $self->_de_restrict_products( $product_rec );
        $self->_de_restrict_address( $address_rec );

        # this sets defaults for the Address
        # should more than one field need setting
        $self->_set_value( $test->{address}, $address->{value_off} );

        foreach my $prd_on ( @{ $prd_values_on } ) {
            my $prefix  = "Product Setting: " . $test->{product}{field} . ' = ' . $prd_on;
            foreach my $addr_on ( @{ $addr_values_on } ) {
                note $prefix
                      . ", Address Setting: " . $test->{address}{field} . ' = ' . $addr_on;

                $self->_set_value( $test->{product}, $prd_on );
                $self->_set_value( $test->{address}, $addr_on );
                $self->_mock_designer_service( $designer_service_on->() );
                my $got = check_shipment_restrictions( $self->schema, { shipment_id => $shipment->id } );
                isa_ok( $got->{restricted_products}, 'HASH', "got a HASH back from 'check_shipment_restrictions'" );
                isa_ok( $got->{restricted_products}{ $product_rec->id }{reasons}, 'ARRAY', "and 'reasons' for Product contains an ARRAY" );
                isa_ok( $got->{restricted_products}{ $product_rec->id }{actions}, 'HASH', "and 'actions' for Product contains a HASH" );
                my $found_label = scalar grep { m/\Q$test->{reason}\E/i }
                                            map { $_->{reason} }
                                            @{ $got->{restricted_products}{ $product_rec->id }{reasons} };
                cmp_ok( $found_label, '==', 1, "found reason: '$test->{reason}' in restriction list" );
                cmp_ok( $got->{silent_restrict}, '==', $test->{silent_restrict}, "'silent_restrict' Flag as expected: " . $test->{silent_restrict} );
                cmp_ok( $got->{all_silent}, '==', $test->{all_silent}, "'all_silent' Flag as expected: " . $test->{all_silent} );
                cmp_ok( $got->{restrict}, '==', $test->{restrict}, "'restrict' Flag as expected: " . $test->{restrict} );
                cmp_ok( $got->{notify}, '==', $test->{notify}, "'notify' Flag as expected: " . $test->{notify} );
                my $prod_actions = $got->{restricted_products}{ $product_rec->id }{actions};
                cmp_ok( $prod_actions->{restrict}, '==', $test->{restrict}, "'restrict' flag on Product 'actions' as expected: " . $test->{restrict} );
                cmp_ok( $prod_actions->{notify}, '==', $test->{notify}, "'notify' flag on Product 'actions' as expected: " . $test->{notify} );

                # now check when product is not restricted
                $self->_set_value( $test->{product}, $product->{value_off} );
                $self->_mock_designer_service( $designer_service_off->() );
                $got    = check_shipment_restrictions( $self->schema, { shipment_id => $shipment->id } );
                ok ( !defined $got->{restricted_products}{ $product_rec->id }, "when Product is NOT restricted, then NO restrictions listed" );
                cmp_ok( $got->{silent_restrict}, '==', 0, "'silent_restrict' Flag is FALSE" );
                cmp_ok( $got->{all_silent}, '==', 0, "'all_silent' Flag is FALSE" );
                cmp_ok( $got->{restrict}, '==', 0, "'restrict' Flag is FALSE" );
                cmp_ok( $got->{notify}, '==', 0, "'notify' Flag is FALSE" );
            }

            note "check when Product has a Restriction but the Address is fine";
            $self->_set_value( $test->{product}, $prd_on );
            $self->_set_value( $test->{address}, $address->{value_off} );
            my $got = check_shipment_restrictions( $self->schema, { shipment_id => $shipment->id } );
            ok ( !defined $got->{restricted_products}{ $product_rec->id },
                    $prefix . ", when Address shouldn't be Restricted, then NO restrictions listed, Address used: " . Data::Printer::p( $address->{value_off} ) );
            cmp_ok( $got->{restrict}, '==', 0, "'restrict' Flag is FALSE" );
            cmp_ok( $got->{notify}, '==', 0, "'notify' Flag is FALSE" );
        }
    }
}

=head2 test_check_shipment_restrictions_with_multiple_products_and_reasons

Tests that when there are Multiple Products and there are Multiple Reasons for Restrictions
then each Product has a list of all of the Reasons.

=cut

sub test_check_shipment_restrictions_with_multiple_products_and_reasons : Tests() {
    my $self    = shift;

    my $channel = Test::XTracker::Data->any_channel();
    my $order_details   = $self->data->new_order(
        channel     => $channel,
        products    => 2,
    );
    my $shipment= $order_details->{shipment_object};
    my $pids    = $order_details->{product_objects};
    my $address = $order_details->{address_object};

    my $dc_country  = $self->{dc_country};
    my @products    = map { $_->{product} } @{ $pids };

    $self->_de_restrict_products( $products[0] );
    $self->_de_restrict_products( $products[1] );

    note "check that when no products are restricted then an empty hash is returned";
    my $got = check_shipment_restrictions( $self->schema, { shipment_id => $shipment->id } );
    isa_ok( $got, 'HASH', "still get a HASH returned" );
    isa_ok( $got->{restricted_products}, 'HASH', "still got a HASH returned for the list of restricted products" );
    cmp_ok( scalar( keys %{ $got->{restricted_products} } ), '==', 0, "but it is empty" );
    cmp_ok( $got->{restrict}, '==', 0, "'restrict' flag is FALSE" );
    cmp_ok( $got->{notify}, '==', 0, "'notify' flag is FALSE" );

    # get the restrictions
    my $cites_restriction   = $self->solve( 'Shipment::restrictions', {
        restriction => 'CITES',
    } );
    my $chinese_restriction = $self->solve( 'Shipment::restrictions', {
        restriction => 'CHINESE_ORIGIN',
    } );
    my $fishwildlife_restriction = $self->solve( 'Shipment::restrictions', {
        restriction => 'FISH_WILDLIFE',
    } );

    # configure the actions for the restrictions ourselves
    Test::XTracker::Data->remove_config_group('ShippingRestrictionActions');
    Test::XTracker::Data->create_config_group(
        'ShippingRestrictionActions',
        {
            settings    => [
                { setting => 'Chinese origin',  value => 'restrict' },
                { setting => 'CITES',           value => 'restrict' },
                { setting => 'Fish & Wildlife', value => 'restrict' },
            ],
        },
    );

    my $general = {
        'with multiple restrictions on multiple products' => {
            restrictions    => [
                {
                    products=> \@products,
                    rule    => $cites_restriction,
                },
                {
                    products=> [ $products[0] ],
                    rule    => $chinese_restriction,
                },
            ],
            expect_reasons  => {
                $products[0]->id    => bag(
                    { reason => 'Chinese origin product', silent => 0 },
                    { reason => 'CITES product', silent => 0 },
                ),
                $products[1]->id    => bag(
                    { reason => 'CITES product', silent => 0 },
                ),
            },
            expect_actions => {
                $products[0]->id    => {
                    restrict        => 1,
                    notify          => 0,
                    silent_restrict => 0
                },
                $products[1]->id    => {
                    restrict        => 1,
                    notify          => 0,
                    silent_restrict => 0
                },
            },
            expect_flags    => {
                restrict        => 1,
                notify          => 0,
                silent_restrict => 0,
                all_silent      => 0,
            },
        },
        'with restrictions on one product and none on another' => {
            restrictions    => [
                {
                    products=> [ $products[0] ],
                    rule    => $cites_restriction,
                },
                {
                    products=> [ $products[0] ],
                    rule    => $chinese_restriction,
                },
            ],
            expect_reasons  => {
                $products[0]->id    => bag(
                    { reason => 'Chinese origin product', silent => 0 },
                    { reason => 'CITES product', silent => 0 },
                ),
            },
            expect_actions => {
                $products[0]->id    => { restrict => 1, notify => 0, silent_restrict => 0 },
            },
            expect_flags    => {
                restrict        => 1,
                notify          => 0,
                silent_restrict => 0,
                all_silent      => 0,

            },
        },
    };
    my %multiple_tests  = (
        DC1 => {
            %{ $general },
        },
        DC2 => {
            %{ $general },
        },
        DC3 => {
# TODO: Adjust whether a Restriction is a Notification or Not in this test by usgin
#       the System Config tables for the Group: 'ShippingRestrictionActions' and make
#       it DC Agnostic, leaving this stuff here so as to show what scenarios to test for

#            'with a notification only product and a non-restricted product, notify flag should be true' => {
#                restrictions    => [
#                    {
#                        products=> [ $products[0] ],
#                        rule    => $fishwildlife_restriction,
#                    },
#                ],
#                expect_reasons  => {
#                    $products[0]->id    => [
#                        'Fish & Wildlife product',
#                    ],
#                },
#                expect_actions => {
#                    $products[0]->id    => { restrict => 0, notify => 1 },
#                },
#                expect_flags    => {
#                    restrict    => 0,
#                    notify      => 1,
#                },
#            },
#            'with all notification products, notify flag should be true' => {
#                restrictions    => [
#                    {
#                        products=> \@products,
#                        rule    => $fishwildlife_restriction,
#                    },
#                ],
#                expect_reasons  => {
#                    $products[0]->id    => [
#                        'Fish & Wildlife product',
#                    ],
#                    $products[1]->id    => [
#                        'Fish & Wildlife product',
#                    ],
#                },
#                expect_actions => {
#                    $products[0]->id    => { restrict => 0, notify => 1 },
#                    $products[1]->id    => { restrict => 0, notify => 1 },
#                },
#                expect_flags    => {
#                    restrict    => 0,
#                    notify      => 1,
#                },
#            },
#            'with a notification product and a restricted product, restrict flag should be true, notify flag should be false' => {
#                restrictions    => [
#                    {
#                        products=> [ $products[0] ],
#                        rule    => $fishwildlife_restriction,
#                    },
#                    {
#                        products=> [ $products[1] ],
#                        rule    => $cites_restriction,
#                    },
#                ],
#                expect_reasons  => {
#                    $products[0]->id    => [
#                        'Fish & Wildlife product',
#                    ],
#                    $products[1]->id    => [
#                        'CITES product',
#                    ],
#                },
#                expect_actions => {
#                    $products[0]->id    => { restrict => 0, notify => 1 },
#                    $products[1]->id    => { restrict => 1, notify => 0 },
#                },
#                expect_flags    => {
#                    restrict    => 1,
#                    notify      => 0,
#                },
#            },
#            'with a notification product and another product that is restricted and notified, restrict flag should be true, notify flag should be false' => {
#                restrictions    => [
#                    {
#                        products=> \@products,
#                        rule    => $fishwildlife_restriction,
#                    },
#                    {
#                        products=> [ $products[0] ],
#                        rule    => $cites_restriction,
#                    },
#                ],
#                expect_reasons  => {
#                    $products[0]->id    => [
#                        sort(
#                            'Fish & Wildlife product',
#                            'CITES product',
#                        ),
#                    ],
#                    $products[1]->id    => [
#                        'Fish & Wildlife product',
#                    ],
#                },
#                expect_actions => {
#                    $products[0]->id    => { restrict => 1, notify => 0 },
#                    $products[1]->id    => { restrict => 0, notify => 1 },
#                },
#                expect_flags    => {
#                    restrict    => 1,
#                    notify      => 0,
#                },
#            },
            %{ $general },
        },
    );
    my $tests   = $multiple_tests{ $distribution_centre };

    foreach my $label ( keys %{ $tests } ) {
        note "TESTING: ${label}";
        my $test    = $tests->{ $label };

        $self->_de_restrict_products( @products );

        # set-up the restrictions
        foreach my $restriction ( @{ $test->{restrictions} } ) {
            $self->_restrict_products( $restriction->{rule}{shipping_attribute}, $restriction->{products} );
            $address->update( $restriction->{rule}{address} );
        }

        my $got = check_shipment_restrictions( $self->schema, { shipment_id => $shipment->id } );

        my $prod_list = delete $got->{restricted_products};
        my $reasons   = { map { $_ => $prod_list->{ $_ }{reasons} } keys %$prod_list };
        my $actions   = { map { $_ => $prod_list->{ $_ }{actions} } keys %$prod_list };

        cmp_deeply( $reasons, $test->{expect_reasons}, "Product Reasons as expected" );
        cmp_deeply( $actions, $test->{expect_actions}, "Product Actions as expected" );
        cmp_deeply( $got, $test->{expect_flags}, "'notify' & 'restrict' Flags are as expected" );
    }
}

=head2 test_get_address_shipping_charges_with_restrictions

=cut

sub test_get_address_shipping_charges_with_restrictions : Tests() {
    my $self    = shift;

    my $channel = Test::XTracker::Data->any_channel();
    my $order_details   = $self->data->new_order(
        channel     => $channel,
        products    => 2,
    );
    my $shipment    = $order_details->{shipment_object};
    my @items       = $shipment->shipment_items->all;
    my @products    = map { $_->variant->product } @items;

    my $ship_restrictions = $self->{ship_restrictions};

    my $address = Test::XTracker::Data->create_order_address_in(
        'current_dc_premier',
    );

    my %charge_classes      = map { $_->class => $_ }
                                $self->rs('Public::ShippingChargeClass')->all;
    $self->{charge_rs}      = $channel->shipping_charges;
    $self->{country_charge_rs} = $channel->country_shipping_charges;

    # create some test Shipping Charges
    my %test_charges;
    my @all_charges;
    # map the SKUs used in %test_charges
    # to the Shipping Charge, for later tests
    my %valid_skus;
    foreach my $class ( 'Same Day', 'Ground', 'Air' ) {
        my $sku = uc( "9000${class}" );
        $sku    =~ s/\W+//g;

        # create 2 Shipping Charges
        my $charge  = $self->_create_charge( $sku . '-001', $charge_classes{ $class }, $address );
        push @{ $test_charges{ $class } }, $charge;
        push @all_charges, $charge;
        $valid_skus{ $charge->sku } = 1;

        $charge     = $self->_create_charge( $sku . '-002', $charge_classes{ $class }, $address );
        push @{ $test_charges{ $class } }, $charge;
        push @all_charges, $charge;
        $valid_skus{ $charge->sku } = 1;
    }

    my %tests   = (
        'With No Restrictions, No Shipment Passed In' => {
            expect  => {
                DC1 => { charges => \@all_charges },
                DC2 => { charges => \@all_charges },
                DC3 => { charges => \@all_charges },
            },
        },
        'With No Restrictions, with Shipment Passed In' => {
            setup   => {
                func_args   => {
                    exclude_for_shipping_attributes => $shipment,
                },
            },
            expect  => {
                DC1 => { charges => \@all_charges },
                DC2 => { charges => \@all_charges },
                DC3 => { charges => \@all_charges },
            },
        },
        'With HAZMAT Restriction, should get all Charges' => {
            setup   => {
                restriction => 'HAZMAT',
                products    => [ $products[0] ],
                func_args   => {
                    exclude_for_shipping_attributes => $shipment,
                },
            },
            expect  => {
                DC1 => { charges => \@all_charges },
                DC2 => { charges => \@all_charges },
                DC3 => { charges => \@all_charges },
            },
        },
        'With HAZMAT Restriction, should get all Charges, and Keep SKU' => {
            setup   => {
                restriction => 'HAZMAT',
                products    => [ $products[0] ],
                func_args   => {
                    always_keep_sku     => $test_charges{'Air'}->[0]->sku,
                    exclude_for_shipping_attributes => $shipment,
                },
            },
            expect  => {
                DC1 => { charges => \@all_charges },
                DC2 => { charges => \@all_charges },
                DC3 => { charges => \@all_charges },
            },
        },
        'With HAZMAT Restriction on a Cancelled Item, should get All Charges' => {
            setup   => {
                restriction => 'HAZMAT',
                products    => [ $products[0] ],
                shipment_items => [ $items[0] ],
                update_item => { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCELLED },
                func_args   => {
                    always_keep_sku     => $test_charges{'Air'}->[0]->sku,
                    exclude_for_shipping_attributes => $shipment,
                },
            },
            expect  => {
                DC1 => { charges => \@all_charges },
                DC2 => { charges => \@all_charges },
                DC3 => { charges => \@all_charges },
            },
        },
        'With HAZMAT Restriction on a Cancelled Pending Item, should get All Charges' => {
            setup   => {
                restriction => 'HAZMAT',
                products    => [ $products[0] ],
                shipment_items => [ $items[0] ],
                update_item => { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING },
                func_args   => {
                    always_keep_sku => $test_charges{'Air'}->[0]->sku,
                    exclude_for_shipping_attributes => $shipment,
                },
            },
            expect  => {
                DC1 => { charges => \@all_charges },
                DC2 => { charges => \@all_charges },
                DC3 => { charges => \@all_charges },
            },
        },
        'With LQ_HAZMAT Restriction, should get NO Air Charges' => {
            setup   => {
                restriction => 'LQ_HAZMAT',
                charges_allowed_for_ship_restriction => [
                    $test_charges{'Same Day'}->[0],
                    $test_charges{'Ground'}->[0],
                    @{ $test_charges{'Air'} },
                ],
                products    => [ $products[0] ],
                func_args   => {
                    exclude_for_shipping_attributes => $shipment,
                },
            },
            expect  => {
                DC1 => {
                    charges => [
                        $test_charges{'Same Day'}->[0],
                        $test_charges{'Ground'}->[0],
                        @{ $test_charges{'Air'} },
                    ],
                },
                DC2 => { charges => \@all_charges },
                DC3 => { charges => \@all_charges },
            },
        },
        'With LQ_HAZMAT Restriction, should get NO Air Charges, but Keep SKU' => {
            setup   => {
                restriction => 'LQ_HAZMAT',
                charges_allowed_for_ship_restriction => [
                    @{ $test_charges{'Same Day'} },
                    @{ $test_charges{'Ground'} },
                ],
                products    => [ $products[0] ],
                func_args   => {
                    always_keep_sku     => $test_charges{'Air'}->[0]->sku,
                    exclude_for_shipping_attributes => $shipment,
                },
            },
            expect  => {
                DC1 => {
                    charges => [
                        @{ $test_charges{'Same Day'} },
                        @{ $test_charges{'Ground'} },
                        $test_charges{'Air'}->[0],
                    ],
                },
                DC2 => { charges => \@all_charges },
                DC3 => { charges => \@all_charges },
            },
        },
        'With LQ_HAZMAT Restriction on a Cancelled Item, should get All Charges' => {
            setup   => {
                restriction => 'LQ_HAZMAT',
                charges_allowed_for_ship_restriction => [
                    @{ $test_charges{'Same Day'} },
                    @{ $test_charges{'Ground'} },
                ],
                products    => [ $products[0] ],
                shipment_items => [ $items[0] ],
                update_item => { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCELLED },
                func_args   => {
                    always_keep_sku     => $test_charges{'Air'}->[0]->sku,
                    exclude_for_shipping_attributes => $shipment,
                },
            },
            expect  => {
                DC1 => { charges => \@all_charges },
                DC2 => { charges => \@all_charges },
                DC3 => { charges => \@all_charges },
            },
        },
        'With LQ_HAZMAT Restriction on a Cancelled Pending Item, should get All Charges' => {
            setup   => {
                restriction => 'LQ_HAZMAT',
                # shouldn't matter if there are no allowed charges
                # as only the restricted items will be Cancelled
                charges_allowed_for_ship_restriction => [ ],
                products    => [ $products[0] ],
                shipment_items => [ $items[0] ],
                update_item => { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING },
                func_args   => {
                    always_keep_sku => $test_charges{'Air'}->[0]->sku,
                    exclude_for_shipping_attributes => $shipment,
                },
            },
            expect  => {
                DC1 => { charges => \@all_charges },
                DC2 => { charges => \@all_charges },
                DC3 => { charges => \@all_charges },
            },
        },
    );

    TEST:
    foreach my $label ( keys %tests ) {
        note "TESTING: ${label}";
        my $test    = $tests{ $label };

        $self->_de_restrict_charges( @all_charges );
        $self->_de_restrict_products( @products );
        $self->_de_restrict_address( $address );
        $shipment->discard_changes->shipment_items->update( {
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
        } );

        my $expect  = $test->{expect}{ $distribution_centre };
        if ( !$expect ) {
            fail( "Nothing has been set-up to be Expected for this Test for DC: '${distribution_centre}'" );
            next TEST;
        }

        # set-up data prior to tests
        if ( my $setup = $test->{setup} ) {
            if ( $setup->{restriction} ) {
                my $restriction = $self->solve( 'Shipment::restrictions', {
                    restriction => $setup->{restriction},
                } );
                if ( $restriction->{shipping_attribute} ) {
                    foreach my $product ( @{ $setup->{products} } ) {
                        $product->shipping_attribute->update( $restriction->{shipping_attribute} );
                    }
                }
                if ( $restriction->{ship_restriction} ) {
                    my @codes = map { $ship_restrictions->{ $_ }->code }
                                    @{ $restriction->{ship_restriction} };
                    foreach my $product ( @{ $setup->{products} } ) {
                        $product->add_shipping_restrictions( {
                            restriction_codes => \@codes,
                        } );
                    }
                    # link Shipping Charges to the Ship Restriction
                    $self->_assign_ship_restrictions_to_charges(
                        $setup->{charges_allowed_for_ship_restriction},
                        $restriction->{ship_restriction}
                    );
                }
                if ( $restriction->{address} ) {
                    $address->update( $restriction->{address} );
                }
            }
            if ( $setup->{shipment_items} ) {
                foreach my $item ( @{ $setup->{shipment_items} } ) {
                    $item->discard_changes->update( $setup->{update_item} );
                }
            }
        }

        # assign all charges to the address's country
        $self->_assign_charges_to_country( $address, @all_charges );

        # will need to replace the Object passed to this argument with
        # the Shipping Attributes before being passed to the function
        if ( my $object = $test->{setup}{func_args}{exclude_for_shipping_attributes} ) {
            $test->{setup}{func_args}{exclude_for_shipping_attributes}  = $object->discard_changes->get_item_shipping_attributes;
        }

        # call the function
        my %shipping_charges = get_address_shipping_charges(
            $self->dbh,
            $channel->id,
            {
                country  => $address->country,
                postcode => $address->postcode,
                state    => $address->county,
            },
            $test->{setup}{func_args},
        );

        my @expect_skus = map { $_->sku }
                            @{ $expect->{charges} };
        my %expect_class= map { $_->shipping_charge_class->class => 1 }
                            @{ $expect->{charges} };

        my @got_skus    = grep { exists( $valid_skus{ $_ } ) }
                            map { $_->{sku} }
                                values %shipping_charges;
        my %got_class   = map { $_->{class} => 1 }
                                values %shipping_charges;

        is_deeply(
            [ sort @got_skus ],
            [ sort @expect_skus ],
            "Found only the Expected Charge SKUs"
        );

        is_deeply(
            \%got_class,
            \%expect_class,
            "Found only the Expected Charge Classes"
        );
    }
}

#------------------------------------------------------------------------------------------------

sub shipping_charge_rs { shift->schema->resultset("Public::ShippingCharge") }

sub data {
    my $self    = shift;
    return $self->{data};
}

sub _create_charge {
    my ( $self, $sku, $class, $address )    = @_;

    my $charge  = $self->{charge_rs}->create( {
        sku         => $sku,
        description => "Test SKU " . $class->class,
        charge      => 101.34,
        currency_id => $self->{dc_currency}->id,
        class_id    => $class->id,
    } );

    note "Created Test Shipping Charge Id/SKU: '" . $charge->id . "/${sku}'"
         . ", of Class: '" . $class->class;

    return $charge;
}

sub _assign_charges_to_country {
    my ( $self, $address, @charges )    = @_;

    foreach my $charge ( @charges ) {
        $self->{country_charge_rs}->update_or_create( {
            shipping_charge_id  => $charge->id,
            country_id          => $address->discard_changes->country_ignore_case->id,
        } );
    }

    return;
}

sub _de_restrict_charges {
    my ( $self, @charges ) = @_;

    foreach my $charge ( @charges ) {
        $charge->discard_changes
                ->ship_restriction_allowed_shipping_charges
                    ->delete;
    }

    return;
}

sub _assign_ship_restrictions_to_charges {
    my ( $self, $charges, $restrictions ) = @_;

    foreach my $charge ( @{ $charges } ) {
        $charge->discard_changes;
        foreach my $restriction_id ( @{ $restrictions } ) {
            $charge->create_related('ship_restriction_allowed_shipping_charges', {
                ship_restriction_id => $restriction_id,
            } );
        }
    }

    return;
}

sub _de_restrict_products {
    my ( $self, @products ) = @_;

    foreach my $product ( @products ) {
        my $ship_attr   = $product->discard_changes->shipping_attribute;
        $ship_attr->update( {
            country_id      => $self->{dc_country}->id,
            cites_restricted=> 0,
            fish_wildlife   => 0,
            is_hazmat       => 0,
        } );
        $product->link_product__ship_restrictions->delete;
    }

    return;
}

sub _restrict_products {
    my $self            = shift;
    my $restriction     = shift;
    my @products        = ( ref( $_[0] ) ? @{ $_[0] } : @_ );

    foreach my $product ( @products ) {
        $self->_set_value( { record => $product->shipping_attribute }, $restriction );
    }

    return;
}

sub _de_restrict_address {
    my ( $self, $address )  = @_;

    $address->discard_changes->update( {
        county   => 'TEST',
        postcode => 'NW1',
        country  => $self->{dc_country}->country,
    } );

    return;
}

sub _set_value {
    my ( $self, $details, $value )  = @_;

    my $update_args;
    if ( ref( $value ) ) {
        $update_args    = { %{ $value } };
    }
    else {
        $update_args    = {
            $details->{field}   => $value,
        };
    }

    if ( my $record = $details->{record} ) {
        $record->discard_changes->update( $update_args );
    }

    if ( my $rs = $details->{resultset} ) {
        if ( defined $value ) {
            $rs->create( $update_args );
        }
        else {
            $rs->reset->delete;
        }
    }

    return;
}

# get a list of countries which
# are NOT in the EU Member States
sub _non_eu_member_states {
    my $self    = shift;
    my @countries   = map { $_->country }
                        $self->rs('Public::SubRegion')
                                ->search( { 'me.id' => { '!=' => $SUB_REGION__EU_MEMBER_STATES } } )
                                    ->search_related('countries')->all;
    return \@countries;
}

# get a list of countries which
# are in the EU Member States
sub _eu_member_states {
    my $self    = shift;
    my @countries   = map { $_->country }
                        $self->rs('Public::SubRegion')
                                ->search( { 'me.id' => $SUB_REGION__EU_MEMBER_STATES } )
                                    ->search_related('countries')->all;
    return \@countries;
}

# every other country
sub _every_other_country_but {
    my ( $self, $exclude )  = @_;

    $exclude = ( ref( $exclude ) eq 'ARRAY' ? $exclude : [ $exclude ] );

    my @countries   = map { $_->country }
                        $self->rs('Public::Country')
                                ->search( {
                                    country => { 'NOT IN' => [ 'Unknown', @{ $exclude } ] },
                                } )->all;
    return \@countries;
}

# get a list of allowed Countries for a Ship Restriction
sub _ship_restriction_allowed_countries {
    my ( $self, $restriction_id ) = @_;

    my $restriction = $self->rs('Public::ShipRestriction')->find( $restriction_id );
    my @countries   = map { $_->country }
                            $restriction->ship_restriction_allowed_countries
                                ->search_related('country')
                                    ->all;
    return \@countries;
}

# get a list of NOT allowed Countries for a Ship Restriction
sub _ship_restriction_not_allowed_countries {
    my ( $self, $restriction_id ) = @_;

    # get all of the Allowed countries first
    my $allowed_countries = $self->_ship_restriction_allowed_countries( $restriction_id );

    return $self->_every_other_country_but( $allowed_countries );
}

# get a list of Postcodes for a Country not not allowed for a Ship Restriction
sub _ship_restriction_not_allowed_postcodes {
    my ( $self, $restriction_id, $country, $suffix ) = @_;

    # suffix to put at the end of every Postcode
    # to make it more real-world if required
    $suffix //= '';

    my $country_rec = $self->rs('Public::Country')->find( { country => $country } );
    my $restriction = $self->rs('Public::ShipRestriction')->find( $restriction_id );

    my @postcodes = map { $_->postcode . $suffix }
                        $restriction->ship_restriction_exclude_postcodes
                            ->search( { country_id => $country_rec->id } )
                                ->all;
    return \@postcodes;
}

sub schema {
    my $self    = shift;
    return $self->{schema};
}

sub dbh {
    my $self    = shift;
    return $self->schema->storage->dbh;
}

sub _mock_designer_service {
    my ($self,  $response ) = @_;

    # Grab the original so we can restore it later, but only if it's not been
    # done before, otherwise we overwrite the original with the fake one!
    $self->{original_designer_service} = \&XT::Service::Designer::get_restricted_countries_by_designer_id
        unless $self->{original_designer_service};

    no warnings 'redefine';

    *XT::Service::Designer::get_restricted_countries_by_designer_id = sub {
        # Let everyone know we're being mocked.
        note '** In mocked XT::Service::Designer::get_restricted_countries_by_designer_id **';
        # If response is not defined, just return an empty array.
        return []
            unless defined $response;
        # If we've been given an ArrayRef, then this is what we should return.
        return $response
            if ref( $response ) eq 'ARRAY';
        # Finally, if none of the above (should be a scalar), die with that
        # message.
        die $response;
    };

    note 'XT::Service::Designer::get_restricted_countries_by_designer_id has been mocked';

    use warnings 'redefine';

}

sub _mock_designer_service_off {
    my $self = shift;

    if ( my $original = $self->{original_designer_service} ) {

        no warnings 'redefine';
        *XT::Service::Designer::get_restricted_countries_by_designer_id = $original;
        use warnings 'redefine';

        note 'XT::Service::Designer::get_restricted_countries_by_designer_id has been restored';

    }

}

=head2 test_get_shipment_id_for_awb

Test the C<get_shipment_id_for_awb> function.

=cut

sub test_get_shipment_id_for_awb : Tests {
    my $self = shift;

    my $order_details = $self->data->new_order;

    my $shipment = $order_details->{shipment_object};
    ok( $shipment, 'created shipment ' . $shipment->id );

    # Include an upper- and lower-case letter so we can do a case insensitive
    # search test
    my ( $out_awb, $ret_awb ) = map { "Xy$_" } Test::XTracker::Data->generate_air_waybills;
    $shipment->update({
        outward_airway_bill => $out_awb, return_airway_bill => $ret_awb,
    });

    my $dbh = $self->dbh;
    for (
        [
            'found shipment case insensitively',
            {
                transform_search_args => sub { uc $_[0] },
                additional_args       => { not_yet_dispatched => 1 },
                should_find           => 1,
            },
            1,
        ],
        [
            q{can't find shipment if status is dispatched},
            {
                additional_args    => { not_yet_dispatched => 1 },
                shipment_status_id => $SHIPMENT_STATUS__DISPATCHED,
            },
            0,
        ],
        [
            'found dispatched shipment without not_yet_dispatched flag',
            { shipment_status_id => $SHIPMENT_STATUS__DISPATCHED },
            1,
        ],
    ) {
        my ($test_name, $test_params, $should_find) = @$_;

        $shipment->update({
            shipment_status_id => $test_params->{shipment_status_id}//$SHIPMENT_STATUS__PROCESSING
        });

        for ([outward => $out_awb], [return => $ret_awb]) {
            my ( $awb_type, $awb ) = @$_;
            my $found = get_shipment_id_for_awb( $dbh, {
                $awb_type => $test_params->{transform_search_args}
                    ? $test_params->{transform_search_args}($awb)
                    : $awb,
                %{$test_params->{additional_args}//{}}
            });
            ok( ($should_find ? $found : !$found), "$test_name using $awb_type awb search" );
        }
    }
}
