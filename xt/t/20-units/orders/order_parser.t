#!/usr/bin/env perl

use NAP::policy     qw( test );

use parent "NAP::Test::Class";

use Test::XTracker::Data::PreOrder;
use Test::XTracker::Data::Order;
use Test::XTracker::Data::Order::Parser::NAPGroupJSON;
use Test::XTracker::Data::FraudRule;
use Test::XTracker::Mock::PSP;

use Test::XTracker::RunCondition    export => qw( $distribution_centre );

use XTracker::Constants               qw( :psp_default );
use XTracker::Constants::FromDB       qw(
                                        :business
                                        :pre_order_item_status
                                        :renumeration_class
                                        :renumeration_status
                                        :renumeration_type
                                        :reservation_status
                                        :shipment_item_returnable_state
                                        :orders_payment_method_class
                                        :shipment_status
                                        :shipment_hold_reason
                                        :shipment_item_on_sale_flag
                                      );
use XTracker::Constants::Reservations qw( :reservation_pre_order_importer );
use XTracker::Config::Local           qw( config_var );

use XTracker::Database::Address       qw( hash_address );

use Test::MockModule;


=head2 startup

=cut

sub startup :Test(startup => 8) {
    my ($self) = @_;

    $self->SUPER::startup();

    $self->{schema} = Test::XTracker::Data->get_schema();

    my $enabled_channels = $self->{schema}->resultset('Public::Channel')->enabled_channels;
    $self->{enabled_channels} = [$enabled_channels->all];
    $self->{nap_channels}     = [$enabled_channels->fulfilment_only(0)];
    $self->{json_channels}    = [$self->{schema}->resultset('Public::Business')->find($BUSINESS__MRP)->channels->enabled_channels->all];

    $self->{xml_parser}      = Test::XTracker::Data::Order::Parser::PublicWebsiteXML->new();
    $self->{napjson_parser}  = Test::XTracker::Data::Order::Parser::NAPGroupJSON->new();
    $self->{mock_send_mail}  = Test::MockModule->new('XTracker::EmailFunctions');
    $self->{xml_addr_atts_parser}
      = Test::XTracker::Data::Order::Parser::PublicWebsiteXML->new(
            {dc_order_template_file => 'orders_template_addr_atts.xml.tt'}
        );

    foreach my $channel ( $enabled_channels->all ) {
        my (undef, $products) = Test::XTracker::Data->grab_products({
            how_many            => 1,
            channel             => $channel->business->config_section,
        });

        foreach my $product (@{$products}) {
            isa_ok($product->{product}, 'XTracker::Schema::Result::Public::Product');
        }

        $self->{test_products}{$channel->id} = $products;
    }

    $self->{default_language} = $self->{schema}->resultset('Public::Language')->get_default_language_preference();
    $self->{all_languages}    = [$self->{schema}->resultset('Public::Language')->all];

    $self->{test_customer}{language_preference} = 'de';
}

=head2 setup

=cut

sub setup :Tests(setup) {
    my ($self) = @_;

    $self->SUPER::setup();

    Test::XTracker::Mock::PSP->set_payment_method('default');

    $self->{schema}->txn_begin;

    # New customer for each test
    foreach my $channel (@{$self->{enabled_channels}}) {
        $self->{test_customer}{channel}{$channel->id} = Test::XTracker::Data->create_dbic_customer({
            channel_id => $channel->id
        });
    }

    # Reset the test data for the next unit test
    $self->{test_order} = {
        shipping_price => 10.00,
        shipping_tax   => 1.50,
        tender_amount  => 90.00,
        pre_auth_code  => Test::XTracker::Data->get_next_preauth($self->{schema}->storage->dbh),
        tender_type    => 'Card',
        item => {
            ol_id       => 123,
            unit_price  => 80,
            desc        => 'blah blah',
            tax         => 8,
            duty        => 2,
        }
    };
}

=head2 test_simple_xml_order_for_enabled_channels
=cut

sub test_simple_xml_order_for_enabled_channels : Tests() {
    my ($self) = @_;

    foreach my $channel (@{$self->{nap_channels}}) {

        my $product = $self->{test_products}{$channel->id}[0];

        my ($order) = $self->{xml_parser}->create_and_parse_order({
            customer => {
                id                  => $self->{test_customer}{channel}{$channel->id}->is_customer_number,
                language_preference => $self->{test_customer}{language_preference},
            },
            order => {
                pre_auth_code  => $self->{test_order}{pre_auth_code},
                tender_type    => $self->{test_order}{tender_type},
                channel_prefix => $channel->business->config_section,
                shipping_price => $self->{test_order}{shipping_price},
                shipping_tax   => $self->{test_order}{shipping_tax},
                tender_amount  => $self->{test_order}{tender_amount},
                items => [
                    {
                        sku         => $product->{variant}->sku,
                        ol_id       => $self->{test_order}{item}{ol_id},
                        description => $self->{test_order}{item}{desc},
                        unit_price  => $self->{test_order}{item}{unit_price},
                        tax         => $self->{test_order}{item}{tax},
                        duty        => $self->{test_order}{item}{duty},
                    }
                ],
            }
        });

        $self->_digest_order_and_run_standard_order_tests($order, {
            customer_language => {
                is_default          => 0,
                language_preference => $self->{test_customer}{language_preference}
            },
            order_language => $self->{test_customer}{language_preference}
        });
    }
}

=head2 test_two_orders_with_different_customer_languages
=cut

sub test_orders_for_customer_language_preference : Tests() {
    my ($self) = @_;

    foreach my $channel (@{$self->{nap_channels}}) {

        my $product = $self->{test_products}{$channel->id}[0];

        my $orderhash = {
            customer => {
                id => $self->{test_customer}{channel}{$channel->id}->is_customer_number,
            },
            order => {
                pre_auth_code  => $self->{test_order}{pre_auth_code},
                tender_type    => $self->{test_order}{tender_type},
                channel_prefix => $channel->business->config_section,
                shipping_price => $self->{test_order}{shipping_price},
                shipping_tax   => $self->{test_order}{shipping_tax},
                tender_amount  => $self->{test_order}{tender_amount},
                items => [
                    {
                        sku         => $product->{variant}->sku,,
                        ol_id       => $self->{test_order}{item}{ol_id},
                        description => $self->{test_order}{item}{desc},
                        unit_price  => $self->{test_order}{item}{unit_price},
                        tax         => $self->{test_order}{item}{tax},
                        duty        => $self->{test_order}{item}{duty},
                    }
                ],
            }
        };

        note "No language set";
        my ($order) = $self->{xml_parser}->create_and_parse_order($orderhash);

        $self->_digest_order_and_run_standard_order_tests($order, {
            customer_language => {
                is_default          => 1,
                language_preference => 'en'
            },
            order_language => undef
        });

        note "Using language set in XML order";
        $orderhash->{customer}{language_preference} = 'de',
        ($order) = $self->{xml_parser}->create_and_parse_order($orderhash);

        $self->_digest_order_and_run_standard_order_tests($order, {
            customer_language => {
                is_default          => 0,
                language_preference => $orderhash->{customer}{language_preference}
            },
            order_language => $orderhash->{customer}{language_preference}
        });

        note "Customer speaks french but order is in Chinese";
        $self->{test_customer}{channel}{$channel->id}->set_language_preference('fr');
        $orderhash->{customer}{language_preference} = 'zh',

        ($order) = $self->{xml_parser}->create_and_parse_order($orderhash);

        $self->_digest_order_and_run_standard_order_tests($order, {
            customer_language => {
                is_default          => 0,
                language_preference => $self->{test_customer}{channel}{$channel->id}->get_language_preference()->{language}->code
            },
            order_language => $orderhash->{customer}{language_preference}
        });
    }
}

=head2 test_simple_xml_order_for_all_channels

=cut

sub test_two_simple_xml_orders_for_same_customer : Tests() {
    my ($self) = @_;

    my $first_language  = $self->{all_languages}[1]->code;
    my $second_language = $self->{all_languages}[2]->code;

    foreach my $channel (@{$self->{nap_channels}}) {

        my $product = $self->{test_products}{$channel->id}[0];

        # First Order
        my ($order) = $self->{xml_parser}->create_and_parse_order({
            customer => {
                id                  => $self->{test_customer}{channel}{$channel->id}->is_customer_number,
                language_preference => $first_language,
            },
            order => {
                pre_auth_code  => $self->{test_order}{pre_auth_code},
                tender_type    => $self->{test_order}{tender_type},
                channel_prefix => $channel->business->config_section,
                shipping_price => $self->{test_order}{shipping_price},
                shipping_tax   => $self->{test_order}{shipping_tax},
                tender_amount  => $self->{test_order}{tender_amount},
                items => [
                    {
                        sku         => $product->{variant}->sku,,
                        ol_id       => $self->{test_order}{item}{ol_id},
                        description => $self->{test_order}{item}{desc},
                        unit_price  => $self->{test_order}{item}{unit_price},
                        tax         => $self->{test_order}{item}{tax},
                        duty        => $self->{test_order}{item}{duty},
                    }
                ],
            }
        });

        $self->_digest_order_and_run_standard_order_tests($order, {
            customer_language => {
                is_default          => 0,
                language_preference => $first_language
            },
            order_language => $first_language
        });

        # Second Order
        ($order) = $self->{xml_parser}->create_and_parse_order({
            customer => {
                id                  => $self->{test_customer}{channel}{$channel->id}->is_customer_number,
                language_preference => $second_language,
            },
            order => {
                pre_auth_code  => $self->{test_order}{pre_auth_code},
                tender_type    => $self->{test_order}{tender_type},
                channel_prefix => $channel->business->config_section,
                shipping_price => $self->{test_order}{shipping_price},
                shipping_tax   => $self->{test_order}{shipping_tax},
                tender_amount  => $self->{test_order}{tender_amount},
                items => [
                    {
                        sku         => $product->{variant}->sku,,
                        ol_id       => $self->{test_order}{item}{ol_id},
                        description => $self->{test_order}{item}{desc},
                        unit_price  => $self->{test_order}{item}{unit_price},
                        tax         => $self->{test_order}{item}{tax},
                        duty        => $self->{test_order}{item}{duty},
                    }
                ],
            }
        });

        $self->_digest_order_and_run_standard_order_tests($order, {
            customer_language => {
                is_default          => 0,
                language_preference => $first_language # language is not set because it has already been set
            },
            order_language => $second_language # we are tracking the language in the order and not what the customer has set
        });
    }
}

=head2 test_simple_xml_order_with_no_lang_for_all_channels
=cut

sub test_simple_xml_order_with_no_lang_for_all_channels : Tests() {
    my ($self) = @_;

    foreach my $channel (@{$self->{nap_channels}}) {

        my $product = $self->{test_products}{$channel->id}[0];

        my ($order) = $self->{xml_parser}->create_and_parse_order({
            customer => {
                id                  => $self->{test_customer}{channel}{$channel->id}->is_customer_number,
            },
            order => {
                pre_auth_code  => $self->{test_order}{pre_auth_code},
                tender_type    => $self->{test_order}{tender_type},
                channel_prefix => $channel->business->config_section,
                shipping_price => $self->{test_order}{shipping_price},
                shipping_tax   => $self->{test_order}{shipping_tax},
                tender_amount  => $self->{test_order}{tender_amount},
                items => [
                    {
                        sku         => $product->{variant}->sku,,
                        ol_id       => $self->{test_order}{item}{ol_id},
                        description => $self->{test_order}{item}{desc},
                        unit_price  => $self->{test_order}{item}{unit_price},
                        tax         => $self->{test_order}{item}{tax},
                        duty        => $self->{test_order}{item}{duty},
                    }
                ],
            }
        });



        $self->_digest_order_and_run_standard_order_tests($order, {
            customer_language => {
                is_default          => 1,
                language_preference => config_var('Customer', 'default_language_preference'),
            },
            order_language => undef
        });
    }
}

=head2 test_addr_atts_xml_order_for_all_channels

=cut

sub test_addr_atts_xml_order_for_all_channels :Tests() {
    my ($self) = @_;

    foreach my $channel (@{$self->{nap_channels}}) {

        my $product = $self->{test_products}{$channel->id}[0];

        my ($order) = $self->{xml_addr_atts_parser}->create_and_parse_order({
              customer => {
                  id => $self->{test_customer}{channel}{$channel->id}->id,
              },
              order => {
                  pre_auth_code  => $self->{test_order}{pre_auth_code},
                  tender_type    => $self->{test_order}{tender_type},
                  channel_prefix => $channel->business->config_section,
                  shipping_price => $self->{test_order}{shipping_price},
                  shipping_tax   => $self->{test_order}{shipping_tax},
                  tender_amount  => $self->{test_order}{tender_amount},
                  items => [
                      {
                          sku         => $product->{variant}->sku,,
                          ol_id       => $self->{test_order}{item}{ol_id},
                          description => $self->{test_order}{item}{desc},
                          unit_price  => $self->{test_order}{item}{unit_price},
                          tax         => $self->{test_order}{item}{tax},
                          duty        => $self->{test_order}{item}{duty},
                      }
                     ],
              }
        });

        my $o_dbic
          = $self->_digest_order_and_run_standard_order_tests($order, {
             customer_language => {
                 is_default          => 1,
                 language_preference => config_var('Customer', 'default_language_preference'),
             },
             order_language => undef
        });

        # Test customer has Account URN
        ok( defined $o_dbic->customer->account_urn,
            'Customer has account URN: ' . $o_dbic->customer->account_urn);

        # Test customer addresses have linked URNs
        ok( defined $o_dbic->invoice_address->urn,
            'Invoice address has URN: ' . $o_dbic->invoice_address->urn);

        ok( defined $o_dbic->shipments->first->shipment_address->urn,
            'Shipment address has URN: '
             . $o_dbic->shipments->first->shipment_address->urn);
    }
}


=head2 test_simple_json_order_for_json_channels
=cut

sub test_simple_json_order_for_json_channels : Tests() {
    my ($self) = @_;

    foreach my $channel (@{$self->{json_channels}}) {

        my $product = $self->{test_products}{$channel->id}[0];

        my $order_data = {
            customer => {
                id                  => $self->{test_customer}{channel}{$channel->id}->is_customer_number,
                language_preference => $self->{test_customer}{language_preference},
            },
            order => {
                pre_auth_code  => $self->{test_order}{pre_auth_code},
                tender_type    => $self->{test_order}{tender_type},
                channel_prefix => $channel->business->config_section,
                shipping_price => $self->{test_order}{shipping_price},
                shipping_tax   => $self->{test_order}{shipping_tax},
                tender_amount  => $self->{test_order}{tender_amount},
                items => [
                    {
                        sku         => $product->{variant}->sku,,
                        ol_id       => $self->{test_order}{item}{ol_id},
                        description => $self->{test_order}{item}{desc},
                        unit_price  => $self->{test_order}{item}{unit_price},
                        tax         => $self->{test_order}{item}{tax},
                        duty        => $self->{test_order}{item}{duty},
                    }
                ],
            }
        };

        my ($order) = $self->{napjson_parser}->create_and_parse_order( $order_data );

        $self->_digest_order_and_run_standard_order_tests($order, {
            customer_language => {
                is_default          => 0,
                language_preference => $self->{test_customer}{language_preference}
            },
            order_language => $self->{test_customer}{language_preference}
        });

        # Test that source_app_name and source_app_version appear if they should
        isa_ok($order, 'XT::Data::Order');
        ok( ! $order->source_app_name, "source_app_name not defined" );
        ok( ! $order->source_app_version, "source_app_version not defined" );

        $order = undef;
        $order_data->{order}->{source_app_name} = "JSON Source";
        $order_data->{order}->{source_app_version} = undef;
        ($order) = $self->{napjson_parser}->create_and_parse_order( $order_data );

        isa_ok($order, 'XT::Data::Order');
        ok( defined $order->source_app_name, "source_app_name defined" );
        ok( $order->source_app_name eq 'JSON Source', 'source_app_name contains correct value' );
        ok( ! $order->source_app_version, "source_app_version not defined" );

        $order = undef;
        $order_data->{order}->{source_app_name} = undef;
        $order_data->{order}->{source_app_version} = "0.01";
        ($order) = $self->{napjson_parser}->create_and_parse_order( $order_data );

        isa_ok($order, 'XT::Data::Order');
        ok( defined $order->source_app_version, "source_app_version defined" );
        ok( $order->source_app_version eq '0.01', 'source_app_version contains correct value' );
        ok( ! $order->source_app_name, "source_app_name not defined" );

        $order = undef;
        $order_data->{order}->{source_app_name} = "JSON Source 2";
        $order_data->{order}->{source_app_version} = "0.02";
        ($order) = $self->{napjson_parser}->create_and_parse_order( $order_data );

        isa_ok($order, 'XT::Data::Order');
        ok( defined $order->source_app_version, "source_app_version defined" );
        ok( $order->source_app_version eq '0.02', 'source_app_version contains correct value' );
        ok( defined $order->source_app_name, "source_app_name defined" );
        ok( $order->source_app_name eq 'JSON Source 2', 'source_app_name contains correct value' );
    }
}

=head2 test_simple_xml_order_with_valid_pre_order_for_enabled_channels
=cut

sub test_simple_xml_order_with_valid_pre_order_for_enabled_channels : Tests() {
    my ($self) = @_;

    foreach my $channel (@{$self->{nap_channels}}) {

        my $pre_order = Test::XTracker::Data::PreOrder->create_complete_pre_order_for_channel($channel);

        $self->{mock_send_mail}->mock('send_email', sub {
            note 'Mocking send_email';

            my ($from, $replyto, $to, $subject, $msg, $type, $attachments, $email_args) = @_;

            is($subject, sprintf($RESERVATION_PRE_ORDER_IMPORTER__EMAIL_SUBJECT, $pre_order->pre_order_number, $pre_order->customer->channel->web_name), 'Correct email subject used');

        });

        my $order_items = $self->_export_pre_order_and_calc_tender_amount( $pre_order->discard_changes );

        my ($order) = $self->{xml_parser}->create_and_parse_order({
            customer => {
                id                  => $self->{test_customer}{channel}{$channel->id}->is_customer_number,
                language_preference => $self->{test_customer}{language_preference},
            },
            order => {
                pre_auth_code   => $pre_order->get_payment->preauth_ref,
                tender_type     => $self->{test_order}{tender_type},
                preorder_number => $pre_order->pre_order_number,
                channel_prefix  => $channel->business->config_section,
                # don't use just '0' as this will be overridden in template
                shipping_price  => '0.00',
                shipping_tax    => '0.00',
                tender_amount   => $self->{test_order}{tender_amount},
                items           => $order_items,
            }
        });

        $self->_digest_order_and_run_pre_order_tests($order, $pre_order);
    }
}


=head2 test_simple_json_order_with_valid_pre_order_for_enabled_channels
=cut

sub test_simple_json_order_with_valid_pre_order_for_enabled_channels : Tests() {
    my ($self) = @_;

    foreach my $channel (@{$self->{json_channels}}) {

        my $pre_order = Test::XTracker::Data::PreOrder->create_complete_pre_order_for_channel($channel);

        $self->{mock_send_mail}->mock('send_email', sub {
            note 'Mocking send_email';

            my ($from, $replyto, $to, $subject, $msg, $type, $attachments, $email_args) = @_;

            is($subject, sprintf($RESERVATION_PRE_ORDER_IMPORTER__EMAIL_SUBJECT, $pre_order->pre_order_number, $pre_order->customer->channel->web_name), 'Correct email subject used');

        });

        my $order_items = $self->_export_pre_order_and_calc_tender_amount( $pre_order->discard_changes );

        my $order = pop(@{Test::XTracker::Data::Order->create_order_json_and_parse($channel->business_id, {
            customer => {
                id                  => $self->{test_customer}{channel}{$channel->id}->is_customer_number,
                language_preference => $self->{test_customer}{language_preference},
            },
            order => {
                pre_auth_code   => $pre_order->get_payment->preauth_ref,
                tender_type     => $self->{test_order}{tender_type},
                preorder_number => $pre_order->pre_order_number,
                channel_prefix  => $channel->business->config_section,
                # don't use just '0' as this will be overridden in template
                shipping_price  => '0.00',
                shipping_tax    => '0.00',
                tender_amount   => $self->{test_order}{tender_amount},
                items           => $order_items,
            }
        })});

        $self->_digest_order_and_run_pre_order_tests($order, $pre_order);
    }
}

=head2 test_copy_state_county_from_pre_order_to_order_addresses

This tests that the Order Importer will copy the State/County from the
original Pre-Order Billing & Shipping Addresses to their Order equivalents
when the Order comes from the Exporter with those values missing.

=cut

sub test_copy_state_county_from_pre_order_to_order_addresses : Tests() {
    my $self = shift;

    my %tests = (
        "Billing Address missing State/County but Shipping Address isn't" => {
            setup => {
                pre_order => {
                    billing_address  => { county => 'Bill County' },
                    shipping_address => { county => 'Ship County' },
                },
                order_xml => {
                    billing_address  => { county => '' },
                    shipping_address => { county => 'Ship County' },
                },
            },
            expect => {
                billing_address  => { county => 'Bill County' },
                shipping_address => { county => 'Ship County' },
            },
        },
        "Shipping Address missing State/County but Billing Address isn't" => {
            setup => {
                pre_order => {
                    billing_address  => { county => 'Bill County' },
                    shipping_address => { county => 'Ship County' },
                },
                order_xml => {
                    billing_address  => { county => 'Bill County' },
                    shipping_address => { county => '' },
                },
            },
            expect => {
                billing_address  => { county => 'Bill County' },
                shipping_address => { county => 'Ship County' },
            },
        },
        "Both Billing & Shipping Address are missing State/County" => {
            setup => {
                pre_order => {
                    billing_address  => { county => 'Bill County' },
                    shipping_address => { county => 'Ship County' },
                },
                order_xml => {
                    billing_address  => { county => '' },
                    shipping_address => { county => '' },
                },
            },
            expect => {
                billing_address  => { county => 'Bill County' },
                shipping_address => { county => 'Ship County' },
            },
        },
        "Neither Billing & Shipping Address are missing State/County but have different Values to original Pre-Order" => {
            setup => {
                pre_order => {
                    billing_address  => { county => 'Bill County' },
                    shipping_address => { county => 'Ship County' },
                },
                order_xml => {
                    billing_address  => { county => 'XXX Bill County' },
                    shipping_address => { county => 'XXX Ship County' },
                },
            },
            expect => {
                billing_address  => { county => 'XXX Bill County' },
                shipping_address => { county => 'XXX Ship County' },
            },
        },
        "Billing & Shipping Address are missing State/County but original Pre-Order didn't have the Values either" => {
            setup => {
                pre_order => {
                    billing_address  => { county => '' },
                    shipping_address => { county => '' },
                },
                order_xml => {
                    billing_address  => { county => '' },
                    shipping_address => { county => '' },
                },
            },
            expect => {
                billing_address  => { county => '' },
                shipping_address => { county => '' },
            },
        },
        "Pre-Order Shipping County when it's a 2 Character US State, gets Uppercased when the Order gets Imported" => {
            setup => {
                pre_order => {
                    billing_address  => { county => 'Bill County' },
                    shipping_address => { county => 'ca', country => 'United States' },
                },
                order_xml => {
                    billing_address  => { county => '' },
                    shipping_address => { county => '' },
                },
            },
            expect => {
                billing_address  => { county => 'Bill County' },
                shipping_address => { county => 'CA' },
            },
        },
    );

    # list of address fields that should be HASHed
    my @addr_fields_to_hash = qw(
        first_name
        last_name           towncity
        address_line_1      postcode
        address_line_2      country
        address_line_3      county
    );

    foreach my $label ( keys %tests ) {
        note "TESTING: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        my $billing_address  = Test::XTracker::Data->create_order_address_in( 'current_dc', $setup->{pre_order}{billing_address} );
        my $shipping_address = Test::XTracker::Data->create_order_address_in( 'current_dc', $setup->{pre_order}{shipping_address} );

        # for the XML file make the State the same as the County
        $setup->{order_xml}{billing_address}{state}  = $setup->{order_xml}{billing_address}{county};
        $setup->{order_xml}{shipping_address}{state} = $setup->{order_xml}{shipping_address}{county};

        foreach my $channel ( @{ $self->{nap_channels} } ) {
            my $pre_order = Test::XTracker::Data::PreOrder->create_complete_pre_order( {
                channel          => $channel,
                invoice_address  => $billing_address,
                shipment_address => $shipping_address,
            } );

            my $order_items = $self->_export_pre_order_and_calc_tender_amount( $pre_order->discard_changes );

            my ( $order ) = $self->{xml_parser}->create_and_parse_order( {
                customer => {
                    id                  => $self->{test_customer}{channel}{ $channel->id }->is_customer_number,
                    language_preference => $self->{test_customer}{language_preference},
                    dont_default_county_or_state => 1,
                },
                billing_addr => {
                    address_line_1 => $billing_address->address_line_1,
                    address_line_2 => $billing_address->address_line_2,
                    address_line_3 => $billing_address->address_line_3,
                    town_city      => $billing_address->towncity,
                    postcode       => $billing_address->postcode,
                    country        => $billing_address->country_ignore_case->code,
                    %{ $setup->{order_xml}{billing_address} },
                },
                shipping_addr => {
                    address_line_1 => $shipping_address->address_line_1,
                    address_line_2 => $shipping_address->address_line_2,
                    address_line_3 => $shipping_address->address_line_3,
                    town_city      => $shipping_address->towncity,
                    postcode       => $shipping_address->postcode,
                    country        => $shipping_address->country_ignore_case->code,
                    %{ $setup->{order_xml}{shipping_address} },
                },
                order => {
                    pre_auth_code   => $pre_order->get_payment->preauth_ref,
                    tender_type     => $self->{test_order}{tender_type},
                    preorder_number => $pre_order->pre_order_number,
                    channel_prefix  => $channel->business->config_section,
                    # don't use just '0' as this will be overridden in template
                    shipping_price  => '0.00',
                    shipping_tax    => '0.00',
                    tender_amount   => $self->{test_order}{tender_amount},
                    items           => $order_items,
                }
            } );


            note "Pre-Process the Order - then check Addresses";
            $order->_preprocess();

            my $got = $order->billing_address->as_dbi_like_hash;
            cmp_deeply( $got, superhashof( $expect->{billing_address} ),
                                    "Pre-Process - Billing Address as Expected" );
            $got = $order->delivery_address->as_dbi_like_hash;
            cmp_deeply( $got, superhashof( $expect->{shipping_address} ),
                                    "Pre-Process - Shipping Address as Expected" );


            note "Digest the Order - then check Addresses";
            my $order_rec = $self->_digest_order_and_run_pre_order_tests( $order, $pre_order );

            my $got_billing_address = $order_rec->invoice_address;
            $got = { $got_billing_address->get_columns };
            cmp_deeply( $got, superhashof( $expect->{billing_address} ),
                                    "Post Order Creation - Billing Address Record as Expected" );
            my $got_hash = hash_address( $self->dbh, {
                map { $_ => $got_billing_address->$_ } @addr_fields_to_hash
            } );
            is( $got_hash, $got_billing_address->address_hash, "and Address HASH is correct" );

            my $got_shipping_address = $order_rec->get_standard_class_shipment->shipment_address;
            $got = { $got_shipping_address->get_columns() };
            cmp_deeply( $got, superhashof( $expect->{shipping_address} ),
                                    "Post Order Creation - Shipping Address Record as Expected" );
            $got_hash = hash_address( $self->dbh, {
                map { $_ => $got_shipping_address->$_ } @addr_fields_to_hash
            } );
            is( $got_hash, $got_shipping_address->address_hash, "and Address HASH is correct" );
        }
    }
}

=head2 test_duplicate_xml_order_for_enabled_channels
=cut

sub test_duplicate_xml_order_for_enabled_channels : Tests() {
    my ($self) = @_;

    foreach my $channel (@{$self->{nap_channels}}) {

        my $last_order_id = $self->{schema}->resultset('Public::Orders')->get_column('id')->max() || 0;

        my $count_rs = $self->{schema}->resultset('Public::Orders')->search({id => {'>' => $last_order_id}});

        my $product = $self->{test_products}{$channel->id}[0];

        my ($order) = $self->{xml_parser}->create_and_parse_order({
            customer => {
                id                  => $self->{test_customer}{channel}{$channel->id}->is_customer_number,
                language_preference => $self->{test_customer}{language_preference},
            },
            order => {
                pre_auth_code  => $self->{test_order}{pre_auth_code},
                tender_type    => $self->{test_order}{tender_type},
                channel_prefix => $channel->business->config_section,
                shipping_price => $self->{test_order}{shipping_price},
                shipping_tax   => $self->{test_order}{shipping_tax},
                tender_amount  => $self->{test_order}{tender_amount},
                items => [
                    {
                        sku         => $product->{variant}->sku,,
                        ol_id       => $self->{test_order}{item}{ol_id},
                        description => $self->{test_order}{item}{desc},
                        unit_price  => $self->{test_order}{item}{unit_price},
                        tax         => $self->{test_order}{item}{tax},
                        duty        => $self->{test_order}{item}{duty},
                    }
                ],
            }
        });

        # First digest
        $self->_digest_order_and_run_standard_order_tests($order, {
            customer_language => {
                is_default          => 0,
                language_preference => $self->{test_customer}{language_preference}
            },
            order_language => $self->{test_customer}{language_preference}
        });

        # Second digest
        my $digest_args = { duplicate => 0 };
        my $order_dbix = $order->digest( $digest_args );
        isa_ok($order_dbix, 'XTracker::Schema::Result::Public::Orders', 'Order returned from digest');
        cmp_ok($digest_args->{duplicate}, '==', 1, "Duplicate Flag TRUE from call to 'digest'");
    }
}

=head2 test_promotional_xml_order_for_enabled_channels
=cut

sub test_promotional_xml_order_for_enabled_channels : Tests() {
    my ($self) = @_;

    foreach my $channel (@{$self->{nap_channels}}) {

        my $last_order_id = $self->{schema}->resultset('Public::Orders')->get_column('id')->max() || 0;

        my $product = $self->{test_products}{$channel->id}[0];

        my ($order) = $self->{xml_parser}->create_and_parse_order({
            customer => {
                id                  => $self->{test_customer}{channel}{$channel->id}->is_customer_number,
                language_preference => $self->{test_customer}{language_preference},
            },
            order => {
                pre_auth_code  => $self->{test_order}{pre_auth_code},
                tender_type    => $self->{test_order}{tender_type},
                channel_prefix => $channel->business->config_section,
                shipping_price => $self->{test_order}{shipping_price},
                shipping_tax   => $self->{test_order}{shipping_tax},
                tender_amount  => $self->{test_order}{tender_amount},
                items          => [
                    {
                        sku         => $product->{variant}->sku,,
                        ol_id       => $self->{test_order}{item}{ol_id},
                        description => $self->{test_order}{item}{desc},
                        unit_price  => $self->{test_order}{item}{unit_price},
                        tax         => $self->{test_order}{item}{tax},
                        duty        => $self->{test_order}{item}{duty},
                    }
                ],
                promotion_basket => [
                    {
                        id       => 1,
                        type     => 'FS_PUBLIC_SALE',
                        desc     => 'The Outnet Clearance NOV11',
                        currency => 'GBP',
                        value    => 0.00,
                    },
                ],
                promotion_line => [
                    {
                        id            => 1,
                        type          => 'FS_PUBLIC_SALE',
                        desc          => 'The Outnet Clearance NOV11',
                        currency      => 'GBP',
                        value         => '23.19',
                        order_line_id => $self->{test_order}{item}{ol_id},
                    },
                ],
            }
        });

        my $order_dbix = $self->_digest_order_and_run_standard_order_tests($order, {
            customer_language => {
                is_default          => 0,
                language_preference => $self->{test_customer}{language_preference}
            },
            order_language => $self->{test_customer}{language_preference}
        });

        foreach my $item ($order_dbix->get_standard_class_shipment->shipment_items) {
            ok($item->link_shipment_item__promotion,'shipment item has a promotion');
        }
    }
}

=head2 test_orders_with_source_app_name_and_source_app_version
=cut

sub test_orders_with_source_app_name_and_source_app_version : Tests() {
    my ($self) = @_;

    foreach my $channel (@{$self->{nap_channels}}) {

        my $product = $self->{test_products}{$channel->id}[0];

        my $orderhash = {
            customer => {
                id => $self->{test_customer}{channel}{$channel->id}->is_customer_number,
            },
            order => {
                pre_auth_code  => $self->{test_order}{pre_auth_code},
                tender_type    => $self->{test_order}{tender_type},
                channel_prefix => $channel->business->config_section,
                shipping_price => $self->{test_order}{shipping_price},
                shipping_tax   => $self->{test_order}{shipping_tax},
                tender_amount  => $self->{test_order}{tender_amount},
                items => [
                    {
                        sku         => $product->{variant}->sku,,
                        ol_id       => $self->{test_order}{item}{ol_id},
                        description => $self->{test_order}{item}{desc},
                        unit_price  => $self->{test_order}{item}{unit_price},
                        tax         => $self->{test_order}{item}{tax},
                        duty        => $self->{test_order}{item}{duty},
                    }
                ],
            }
        };

        note "No source_app_name or source_app_version";
        my ($order) = $self->{xml_parser}->create_and_parse_order($orderhash);

        isa_ok($order, 'XT::Data::Order');
        ok( ! $order->source_app_name, "source_app_name not defined" );
        ok( ! $order->source_app_version, "source_app_version not defined" );

        note "Using source_app_name set in XML order";
        $order = undef;
        $orderhash->{order}->{source_app_version} = undef;
        $orderhash->{order}->{source_app_name}= 'XTracker_Test_Suite',
        ($order) = $self->{xml_parser}->create_and_parse_order($orderhash);

        isa_ok($order, 'XT::Data::Order');
        ok( $order->source_app_name, "source_app_name is defined" );
        ok( $order->source_app_name eq 'XTracker_Test_Suite', "source_app_name has correct value" );
        ok( ! $order->source_app_version, "source_app_version not defined" );

        note "Using source_app_version set in XML order";
        $order = undef;
        $orderhash->{order}->{source_app_name} = undef;
        $orderhash->{order}->{source_app_version}= '0.01',
        ($order) = $self->{xml_parser}->create_and_parse_order($orderhash);

        isa_ok($order, 'XT::Data::Order');
        ok( ! $order->source_app_name, "source_app_name not defined" );
        ok( $order->source_app_version eq '0.01', "source_app_version has correct value" );
        ok( $order->source_app_version, "source_app_version defined" );

        note "Using source_app_name and source_app_version set in XML order";
        $order = undef;
        $orderhash->{order}->{source_app_name}= 'XTracker_Test_Suite',
        $orderhash->{order}->{source_app_version}= '0.02',
        ($order) = $self->{xml_parser}->create_and_parse_order($orderhash);

        isa_ok($order, 'XT::Data::Order');
        ok( $order->source_app_name, "source_app_name defined" );
        ok( $order->source_app_name eq 'XTracker_Test_Suite', "source_app_name has correct value" );
        ok( $order->source_app_version, "source_app_version defined" );
        ok( $order->source_app_version eq '0.02', "source_app_version has correct value" );

    }
}

=head2 test_xml_and_json_order_line_item_returnable_state

=cut

sub test_xml_and_json_order_line_item_returnable_state : Tests() {
    my $self    = shift;

    my %tests   = (
        "NO 'RETURNABLE' tag set, default to 'YES'" => {
           expect => $SHIPMENT_ITEM_RETURNABLE_STATE__YES,
        },
        "'RETURNABLE' tag set to 'NO'" => {
           tag => 'NO',
           expect => $SHIPMENT_ITEM_RETURNABLE_STATE__NO,
        },
        "'RETURNABLE' tag set to 'YES'" => {
           tag => 'YES',
           expect => $SHIPMENT_ITEM_RETURNABLE_STATE__YES,
        },
        "'RETURNABLE' tag set to 'CC_ONLY'" => {
           tag => 'CC_ONLY',
           expect => $SHIPMENT_ITEM_RETURNABLE_STATE__CC_ONLY,
        },
        "'RETURNABLE' tag set to 'cC_OnlY', to test case insensitive" => {
           tag => 'cC_OnlY',
           expect => $SHIPMENT_ITEM_RETURNABLE_STATE__CC_ONLY,
        },
        "'RETURNABLE' tag set to 'GARBAGE', to use an Unkown State and should default to 'Yes'" => {
           tag => 'GARBAGE',
           expect => $SHIPMENT_ITEM_RETURNABLE_STATE__YES,
        },
    );

    my @test_nap_channels   = (
        map { { channel => $_, parser => 'xml_parser' } }
            @{ $self->{nap_channels} }
    );
    my @test_json_channels  = (
        map { { channel => $_, parser => 'napjson_parser' } }
            @{ $self->{json_channels} }
    );

    foreach my $test_channel ( @test_nap_channels, @test_json_channels ) {
        my $channel = $test_channel->{channel};
        my $parser  = $test_channel->{parser};
        my $product = $self->{test_products}{$channel->id}[0];

        foreach my $label ( keys %tests ) {
            note "Testing: Channel - " . $channel->name . ", with " . $label;
            note "using Parser: ${parser}";
            my $test = $tests{ $label };

            my $orderhash = {
                customer => {
                    id => $self->{test_customer}{channel}{$channel->id}->is_customer_number,
                },
                order => {
                    pre_auth_code  => $self->{test_order}{pre_auth_code},
                    tender_type    => $self->{test_order}{tender_type},
                    channel_prefix => $channel->business->config_section,
                    shipping_price => $self->{test_order}{shipping_price},
                    shipping_tax   => $self->{test_order}{shipping_tax},
                    tender_amount  => $self->{test_order}{tender_amount},
                    items => [
                        {
                            sku         => $product->{variant}->sku,,
                            ol_id       => $self->{test_order}{item}{ol_id},
                            description => $self->{test_order}{item}{desc},
                            unit_price  => $self->{test_order}{item}{unit_price},
                            tax         => $self->{test_order}{item}{tax},
                            duty        => $self->{test_order}{item}{duty},
                            returnable  => $test->{tag},
                        }
                    ],
                    ( !$test->{tag} ? ( with_no_returnable_state => 1 ) : () ),
                }
            };

            my ($order) = $self->{ $parser }->create_and_parse_order( $orderhash );

            my $order_obj = $self->_digest_order_and_run_common_tests( $order );
            my $shipment  = $order_obj->get_standard_class_shipment;
            my $ship_item = $shipment->shipment_items->first;

            cmp_ok( $ship_item->returnable_state_id, '==', $test->{expect},
                                    "Shipment Item's 'returnable_state_id' is as expected" );
        }
    }
}

=head2 test_state_versus_county

Check that if there is NO County then the State should be used for
both Delivery & Invoice Addresses.

=cut

sub test_state_versus_county : Tests() {
    my ($self) = @_;

    foreach my $channel (@{$self->{nap_channels}}) {

        my $product = $self->{test_products}{$channel->id}[0];

        my %dc_tests   = (
            DC1 => {
                "County and State" => {
                    county => 'County',
                    state  => 'State',
                    expect => 'County',
                },
                "No County and State" => {
                    county => '',
                    state  => 'State',
                    expect => 'State',
                },
                "No County and No State" => {
                    county => '',
                    state  => '',
                    expect => '',
                },
                "County and No State" => {
                    county => 'County',
                    state  => '',
                    expect => 'County',
                },
            },
            DC2 => {
                "County and State" => {
                    county => 'County',
                    state  => 'State',
                    expect => 'State',
                },
                "No County and State" => {
                    county => '',
                    state  => 'State',
                    expect => 'State',
                },
                "No County and No State" => {
                    county => '',
                    state  => '',
                    expect => '',
                },
                "County and No State" => {
                    county => 'County',
                    state  => '',
                    expect => '',
                },
            },
            DC3 => {
                "County and State" => {
                    county => 'County',
                    state  => 'State',
                    expect => 'County',
                },
                "No County and State" => {
                    county => '',
                    state  => 'State',
                    expect => 'State',
                },
                "No County and No State" => {
                    county => '',
                    state  => '',
                    expect => '',
                },
                "County and No State" => {
                    county => 'County',
                    state  => '',
                    expect => 'County',
                },
            },
        );

        my $tests   = $dc_tests{$distribution_centre};

        foreach my $label ( keys %{ $tests } ) {
            my $test = $tests->{ $label };
            note "Test: ${label}";

            my ($order) = $self->{xml_parser}->create_and_parse_order({
                customer => {
                    dont_default_county_or_state => 1,
                    county  => $test->{county},
                    state   => $test->{state},
                },
                order => {
                    pre_auth_code  => $self->{test_order}{pre_auth_code},
                    tender_type    => $self->{test_order}{tender_type},
                    channel_prefix => $channel->business->config_section,
                    shipping_price => $self->{test_order}{shipping_price},
                    shipping_tax   => $self->{test_order}{shipping_tax},
                    tender_amount  => $self->{test_order}{tender_amount},
                    items => [
                        {
                            sku         => $product->{variant}->sku,,
                            ol_id       => $self->{test_order}{item}{ol_id},
                            description => $self->{test_order}{item}{desc},
                            unit_price  => $self->{test_order}{item}{unit_price},
                            tax         => $self->{test_order}{item}{tax},
                            duty        => $self->{test_order}{item}{duty},
                        }
                    ],
                }
            });

            my $order_rec = $self->_digest_order_and_run_standard_order_tests($order, {
                customer_language => {
                    is_default          => 1,
                    language_preference => 'en',
                },
            });

            my $invoice_address  = $order_rec->order_address;
            my $shipment_address = $order_rec->get_standard_class_shipment->shipment_address;

            my $invoice_county  = $invoice_address->county // '';
            my $shipment_county = $shipment_address->county // '';
            is( $invoice_county, $test->{expect}, "Invoice County as Expected: '" . $test->{expect} . "'" );
            is( $shipment_county, $test->{expect}, "Shipment County as Expected: '" . $test->{expect} . "'" );
        }
    }
}

=head2 test_payment_method_created_correctly

Tests that the 'orders.payment' record gets created correctly with
the correct Payment Method.

The Payment Methods are at the moment:
    * Card
    * PayPal

Will use the 'Mock::PSP' to indicate which is the correct Method.

=cut

sub test_payment_method_created_correctly : Tests {
    my $self    = shift;

    # get any NAP Channel
    my $channel = $self->{nap_channels}[0];

    my $product = $self->{test_products}{ $channel->id }[0];

    my $orderhash = {
        customer => {
            id => $self->{test_customer}{channel}{ $channel->id }->is_customer_number,
        },
        order => {
            pre_auth_code  => $self->{test_order}{pre_auth_code},
            tender_type    => $self->{test_order}{tender_type},
            channel_prefix => $channel->business->config_section,
            shipping_price => $self->{test_order}{shipping_price},
            shipping_tax   => $self->{test_order}{shipping_tax},
            tender_amount  => $self->{test_order}{tender_amount},
            items => [
                {
                    sku         => $product->{variant}->sku,,
                    ol_id       => $self->{test_order}{item}{ol_id},
                    description => $self->{test_order}{item}{desc},
                    unit_price  => $self->{test_order}{item}{unit_price},
                    tax         => $self->{test_order}{item}{tax},
                    duty        => $self->{test_order}{item}{duty},
                }
            ],
        }
    };

    my $payment_method_rs = $self->rs('Orders::PaymentMethod');

    # get the Default Payment Method of 'Credit Card'
    my $default_payment_method = $payment_method_rs->find( {
        payment_method => $PSP_DEFAULT_PAYMENT_METHOD,
    } );

    # create a couple of Payment Method and then use their 'string_from_psp'
    # to make sure they are found and returned by the 'XT::Data::Order::Tender'
    # class
    my %test_payment_methods = (
        "Test Method 1" => $payment_method_rs->create( {
            payment_method          => 'Test Method 1',
            payment_method_class_id => $ORDERS_PAYMENT_METHOD_CLASS__CARD,
            string_from_psp         => 'TEST_METHOD_1',
            display_name            => 'Test Method 1',
        } ),
        "Test Method 2" => $payment_method_rs->create( {
            payment_method          => 'Test Method 2',
            payment_method_class_id => $ORDERS_PAYMENT_METHOD_CLASS__THIRD_PARTY_PSP,
            string_from_psp         => 'TEST_METHOD_2',
            display_name            => 'Test Method 2',
        } ),
    );

    my %tests = (
        "Card Payment Method" => {
            setup => {
                payment_method => $test_payment_methods{'Test Method 1'}->string_from_psp,
            },
            expect => {
                method_rec => $test_payment_methods{'Test Method 1'},
            },
        },
        "PayPal Payment Method" => {
            setup => {
                payment_method => $test_payment_methods{'Test Method 2'}->string_from_psp,
            },
            expect => {
                method_rec => $test_payment_methods{'Test Method 2'},
            },
        },
        "Unknown Payment Method" => {
            setup => {
                payment_method => 'GARBAGE',
            },
            expect => {
                to_die => 1,
            },
        },
        "Empty Payment Method Should Return Default" => {
            setup   => {
                payment_method => '',
            },
            expect => {
                method_rec => $default_payment_method,
            },
        },
        "'undef' Payment Method Should Return Default" => {
            setup   => {
                payment_method => undef,
            },
            expect => {
                method_rec => $default_payment_method,
            },
        },
    );

    TEST:
    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };
        my $expect  = $test->{expect};

        Test::XTracker::Mock::PSP->set_payment_method( $test->{setup}{payment_method}, 'WITH FORCE' );

        my ( $order ) = $self->{xml_parser}->create_and_parse_order( $orderhash );

        my $tender = $order->get_card_tender;
        isa_ok( $tender, 'XT::Data::Order::Tender', "found a Tender" );

        if ( $expect->{to_die} ) {
            throws_ok {
                    my $tmp = $tender->payment_method;
                }
                qr/Unknown Payment Method/i,
                "getting a Payment Method dies with expected Error Message";

            next TEST;
        }
        else {
            my $payment_method = $tender->payment_method;
            isa_ok( $payment_method, 'XTracker::Schema::Result::Orders::PaymentMethod',
                                "Tender has a Payment Method" );
            cmp_ok( $payment_method->id, '==', $expect->{method_rec}->id,
                                "and the Payment Method is as Expected" );
        }

        # now create an actual Order record
        my $order_rec   = $self->_digest_order_and_run_common_tests( $order );
        my $payment_rec = $order_rec->payments->first;
        cmp_ok( $payment_rec->payment_method_id, '==', $expect->{method_rec}->id,
                                "Payment Method on 'orders.payment' is as Expected" );
    }
}

=head2 test_shipment_goes_on_hold_for_third_party_psp

Check that if an Order is paid with using a Third Party PSP (PayPal)
that the Shipment is put on Hold if the Thirdy Party has yet to
Accept the Payment or if it has Rejected it.

=cut

sub test_shipment_goes_on_hold_for_third_party_psp :Tests {
    my $self    = shift;

    # get any NAP Channel
    my $channel = $self->{nap_channels}[0];

    my $product = $self->{test_products}{ $channel->id }[0];

    my $orderhash = {
        customer => {
            id => $self->{test_customer}{channel}{ $channel->id }->is_customer_number,
        },
        order => {
            pre_auth_code  => $self->{test_order}{pre_auth_code},
            tender_type    => $self->{test_order}{tender_type},
            channel_prefix => $channel->business->config_section,
            shipping_price => $self->{test_order}{shipping_price},
            shipping_tax   => $self->{test_order}{shipping_tax},
            tender_amount  => $self->{test_order}{tender_amount},
            items => [
                {
                    sku         => $product->{variant}->sku,,
                    ol_id       => $self->{test_order}{item}{ol_id},
                    description => $self->{test_order}{item}{desc},
                    unit_price  => $self->{test_order}{item}{unit_price},
                    tax         => $self->{test_order}{item}{tax},
                    duty        => $self->{test_order}{item}{duty},
                }
            ],
        }
    };

    my $payment_method_rs = $self->rs('Orders::PaymentMethod');

    # get the Default Payment Method of 'Credit Card'
    my $default_payment_method = $payment_method_rs->find( {
        payment_method => $PSP_DEFAULT_PAYMENT_METHOD,
    } );

    my $third_party_method = $payment_method_rs->update_or_create( {
        payment_method          => 'Test Method',
        payment_method_class_id => $ORDERS_PAYMENT_METHOD_CLASS__THIRD_PARTY_PSP,
        string_from_psp         => 'TEST_METHOD',
        display_name            => 'Test Method',
    } );
    $third_party_method->third_party_payment_method_status_maps->delete;

    # get the Internal Statuses to assign to the
    # Third Party External Statuses, these will
    # be: Pending, Accepted & Rejected
    my %internal_statuses = (
        map { $_->status => $_ }
            $self->rs('Orders::InternalThirdPartyStatus')->all
    );

    # now map Third Party Statuses to Internal Statuses
    my @status_map;
    foreach my $internal_status ( values %internal_statuses ) {
        my $third_party_status = uc( $internal_status->status ) . '_EXTERNAL';
        $third_party_status    =~ s/ /_/g;

        push @status_map, $third_party_method->create_related( 'third_party_payment_method_status_maps', {
            third_party_status  => $third_party_status,
            internal_status_id  => $internal_status->id,
        } );
    }

    my %tests = (
        "Credit Card Payment, Shipment should NOT be put on Hold" => {
            setup   => {
                payment_method  => $default_payment_method->string_from_psp,
            },
            expect  => {
                shipment_status     => $SHIPMENT_STATUS__PROCESSING,
            },
        },
        "Third Party Payment with Third Party Status of 'Pending', Shipment should go on Hold" => {
            setup   => {
                payment_method      => $third_party_method->string_from_psp,
                third_party_status  => 'PENDING_EXTERNAL',
            },
            expect  => {
                shipment_status     => $SHIPMENT_STATUS__HOLD,
                hold_reason         => $SHIPMENT_HOLD_REASON__CREDIT_HOLD__DASH__SUBJECT_TO_EXTERNAL_PAYMENT_REVIEW,
            },
        },
        "Third Party Payment with Third Party Status of 'Accepted', Shipment should NOT go on Hold" => {
            setup   => {
                payment_method      => $third_party_method->string_from_psp,
                third_party_status  => 'ACCEPTED_EXTERNAL',
            },
            expect  => {
                shipment_status     => $SHIPMENT_STATUS__PROCESSING,
            },
        },
        "Third Party Payment with Third Party Status of 'Rejected', Shipment should go on Hold" => {
            setup   => {
                payment_method      => $third_party_method->string_from_psp,
                third_party_status  => 'REJECTED_EXTERNAL',
            },
            expect  => {
                shipment_status     => $SHIPMENT_STATUS__HOLD,
                hold_reason         => $SHIPMENT_HOLD_REASON__EXTERNAL_PAYMENT_FAILED,
            },
        },
    );

    # make sure CONRAD is on for the Sales Channel
    Test::XTracker::Data::FraudRule->switch_all_channels_on;
    # create a Fraud Rule which will always Accept the Order
    Test::XTracker::Data::FraudRule->create_live_rule_to_always_accept;

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };
        my $expect  = $test->{expect};

        Test::XTracker::Mock::PSP->set_payment_method( $test->{setup}{payment_method} );
        Test::XTracker::Mock::PSP->set_third_party_status( $test->{setup}{third_party_status} );

        my ( $order ) = $self->{xml_parser}->create_and_parse_order( $orderhash );
        my $order_rec = $self->_digest_order_and_run_common_tests( $order );
        my $shipment  = $order_rec->get_standard_class_shipment;

        cmp_ok( $shipment->shipment_status_id, '==', $expect->{shipment_status},
                        "Shipment Status is as Expected" );

        if ( $expect->{hold_reason} ) {
            my $shipment_hold = $shipment->shipment_holds->first;
            isa_ok( $shipment_hold, 'XTracker::Schema::Result::Public::ShipmentHold',
                            "Shipment is on Hold" );
            cmp_ok( $shipment_hold->shipment_hold_reason_id, '==', $expect->{hold_reason},
                            "and it's for the Expected Reason" );
        }
        else {
            cmp_ok( $shipment->shipment_holds->count, '==', 0,
                            "The Shipment has NO Hold Reasons" );
        }
    }
}


=head2 _digest_order_and_run_common_tests
=cut

sub _digest_order_and_run_common_tests {
    my ($self, $order) = @_;

    my $last_order_id = $self->{schema}->resultset('Public::Orders')->get_column('id')->max() || 0;
    my $expected_number_of_orders = 1;

    isa_ok($order, 'XT::Data::Order');

    my $digest_args = { duplicate => 0 };
    my $order_dbix = $order->digest( $digest_args );

    isa_ok($order_dbix, 'XTracker::Schema::Result::Public::Orders', 'Order returned from digest');

    cmp_ok( $digest_args->{duplicate}, '==', 0, "Duplicate Flag FALSE from call to 'digest'" );

    cmp_ok(
        $self->{schema}->resultset('Public::Orders')->search({id => {'>' => $last_order_id}})->count(),
        '==',
        $expected_number_of_orders,
        'New order was inserted into the database'
    );

    # Test Payment
    my $payment = $order_dbix->payments->first;

    isa_ok($payment,          'XTracker::Schema::Result::Orders::Payment');
    ok($payment->psp_ref,     'PSP ref exists');
    ok($payment->preauth_ref, 'Preauth ref exists');

    # Test Shipment Items
    cmp_ok($order->all_line_items, '==', $order_dbix->get_standard_class_shipment->shipment_items);

    foreach my $item ($order_dbix->get_standard_class_shipment->shipment_items) {
        cmp_ok($item->unit_price, '==', $self->{test_order}{item}{unit_price}, "Item price has not changed");
        cmp_ok($item->tax,        '==', $self->{test_order}{item}{tax}, "Tax has not changed");
        cmp_ok($item->duty,       '==', $self->{test_order}{item}{duty}, "Duty price has not changed");
    }

    return $order_dbix;
}

=head2 _digest_order_and_run_standard_order_tests
=cut

sub _digest_order_and_run_standard_order_tests {
    my ($self, $order, $expected) = @_;

    my $order_dbix = $self->_digest_order_and_run_common_tests($order);

    my $shipment = $order_dbix->get_standard_class_shipment;

    ok(!$shipment->is_held(), 'Shipment is not on hold');

    # Test Payment
    my $order_dbix_payment = $order_dbix->payments->first;
    is($order_dbix_payment->preauth_ref, $self->{test_order}{pre_auth_code}, 'PreAuth refs match');
    ok(!$order_dbix_payment->settle_ref, 'Settle does not exists');
    ok(!$order_dbix_payment->fulfilled, 'Payment is not fulfilled');

    # make sure NO Sales-Invoice has been created,
    # this should happen at Packing for normal Orders
    my $invoice = $shipment->get_sales_invoice;
    ok( !defined $invoice, "No Sales Invoice has been Created for the Shipment" );

    foreach my $item ($shipment->shipment_items) {
        ok(!$item->special_order_flag, 'Special order flag not set');
    }

    # Test for Language Preference
    my $lang = $order_dbix->customer->get_language_preference;
    cmp_ok($lang->{is_default}, '==', $expected->{customer_language}{is_default}, 'language is not default');
    is($lang->{language}->code, $expected->{customer_language}{language_preference}, 'Correct language is set');

    if ($expected->{order_language}) {
        is($order_dbix->customer_language_preference->code, $expected->{order_language}, 'order has recorded the correct language preference');
    }
    else {
        is($order_dbix->customer_language_preference, undef, 'order language preference is null');
    }

    return $order_dbix;
}

=head2 test_order_with_1p_difference
    Checks  1 penny is added to card tender(only) when tender value is 1p
    less than the order total. In all other cases tender is untouched
    as expected.
=cut

sub test_order_with_1p_difference : Tests() {
    my $self = shift;

    my $expected = {
        'Both are same' => {
            tender_sum  => 90,
            order_total => '90.000'
        },
        'tender sum is 1P difference' => {
            tender_sum  => 90,
            order_total => '90.000',
        },
        'tender sum is 1p greater' => {
            tender_sum => 90.01,
            order_total => '90.000',
        },
        'tender sum is 10p less' => {
            tender_sum  => 89.90,
            order_total => '90.000',
        },
        'tender sum is 50p more' => {
            tender_sum  => 90.50,
            order_total => '90.000',
        },
        'only store credit tender with 1p less' => {
            tender_sum   => 89.99,
            order_total  => '90.000',
        }
    };


    foreach my $channel (@{$self->{nap_channels}}) {

        my ( $got, $orderhash );
        # Test1 : When total order value equals tender sum
        $orderhash = $self->_setup_orderhash($channel);
        $got->{'Both are same'} = $self->_check_and_create_order($orderhash);

        # Test 2 : make tender sum 1p less
        $orderhash = $self->_setup_orderhash($channel,{ card_tender_value => 79.99 });
        $got->{'tender sum is 1P difference'} = $self->_check_and_create_order($orderhash);

        # Test 3: make tender sum 1p greater
        $orderhash = $self->_setup_orderhash($channel,{  card_tender_value => 80.01 });
        $got->{'tender sum is 1p greater'} =  $self->_check_and_create_order($orderhash);

        # Test 4: make tender 10p less
        $orderhash = $self->_setup_orderhash($channel,{  card_tender_value => 79.90 });
        $got->{'tender sum is 10p less'} =  $self->_check_and_create_order($orderhash);

        # Test 5: make tender 50 p more
        $orderhash = $self->_setup_orderhash($channel,{  card_tender_value => 80.50 });
        $got->{'tender sum is 50p more'} =  $self->_check_and_create_order($orderhash);

        # Test 6: tender with no credit card
        $orderhash = $self->_setup_orderhash($channel,{  store_credit => 89.99, no_card => 1 });
        $got->{'only store credit tender with 1p less'} =  $self->_check_and_create_order($orderhash);

       cmp_deeply($got, $expected, 'Value are as expected for channel'. $channel->id) ;
    }

}


sub test_order_having_shipping_address_phone_numbers : Tests() {
    my $self = shift;


    my %tests = (
        "Billing and Shipping contact details are provided" => {
            setup => {
                 shipping_details => {
                    shipping_mobile_phone   => '333',
                    shipping_work_phone     => '',
                    email                   => 'abc@net-a-porter.com',
                },
                customer => {
                    mobile_phone        => '+44 3434 232 123',
                    work_phone          => '023443434',
                    email               => 'james_bond@net-a-porter.com',
                }
            },
            expected    => {
                shipping_contact_details  => {
                    mobile_phone   => '333',
                    work_phone     => '',
                    email          => 'abc@net-a-porter.com',
                },
                customer_contact_details => {
                    mobile_phone        => '+44 3434 232 123',
                    work_phone          => '023443434',
                    email               => 'james_bond@net-a-porter.com',
                },
                order_contact_details =>{
                    mobile_phone        => '+44 3434 232 123',
                    work_phone          => '023443434',
                    email               => 'james_bond@net-a-porter.com',
                }
            }
        },
        "Only Billing contact details is provided" => {
            setup => {
                customer => {
                    mobile_phone        => '232 123',
                    work_phone          => '020 8320',
                    email               => 'james_bond@net-a-porter.com',
                }
            },
            expected    => {
                shipping_contact_details  => {
                    mobile_phone        => '232 123',
                    work_phone          => '020 8320',
                    email               => 'james_bond@net-a-porter.com',
                },
                customer_contact_details => {
                    mobile_phone        => '232 123',
                    work_phone          => '020 8320',
                    email               => 'james_bond@net-a-porter.com',
                },
                order_contact_details =>{
                    mobile_phone        => '232 123',
                    work_phone          => '020 8320',
                    email               => 'james_bond@net-a-porter.com',
                }
            }
        },
        "Shipping email is provided and Billing Contact details is provided " => {
            setup => {
                 shipping_details => {
                    email                   => 'testing@net-a-porter.com',
                },
                customer => {
                    mobile_phone        => '+44 3434 232 123',
                    work_phone          => '023443434',
                    email               => 'james_bond@net-a-porter.com',
                }
            },
            expected    => {
                shipping_contact_details  => {
                    mobile_phone   => '+44 3434 232 123',
                    work_phone     => '023443434',
                    email          => 'testing@net-a-porter.com',
                },
                customer_contact_details => {
                    mobile_phone        => '+44 3434 232 123',
                    work_phone          => '023443434',
                    email               => 'james_bond@net-a-porter.com',
                },
                order_contact_details =>{
                    mobile_phone        => '+44 3434 232 123',
                    work_phone          => '023443434',
                    email               => 'james_bond@net-a-porter.com',
                }
            }

        }
    );

    foreach my $channel (@{$self->{nap_channels}}) {
        my $order_hash;

        foreach my $label ( keys %tests) {
            note "Testing: ${label}";

            my $test    = $tests{ $label };
            my $expect  = $test->{expected};

            $order_hash = $self->_setup_orderhash( $channel, $test->{setup});

            my ($order) = $self->{xml_parser}->create_and_parse_order($order_hash);
            my $order_obj = $order->digest( { duplicate => 0 } );
            isa_ok($order_obj, 'XTracker::Schema::Result::Public::Orders', 'Order returned from digest');

            my $shipment  = $order_obj->get_standard_class_shipment;
            my $customer = $order_obj->customer;

            my $got_data = {
                shipping_contact_details => {
                    mobile_phone => $shipment->mobile_telephone,
                    work_phone  => $shipment->telephone,
                    email       => $shipment->email
                },
                customer_contact_details => {
                    mobile_phone => $customer->telephone_3,
                    work_phone  => $customer->telephone_2,
                    email       => $customer->email
                },
                order_contact_details => {
                    mobile_phone => $order_obj->mobile_telephone,
                    work_phone  => $order_obj->telephone,
                    email       => $order_obj->email
                }
            };

            cmp_deeply( $got_data, $expect ,"Contact Details are as expected");
        }
    }


}

=head2 test_orders_for_xss_characters

Tests that orders with characters in the gift message or sticker fields which
might pose an XSS risk are safely imported into XT.

Note that this does NOT test that no XSS risk remains as a result of importing
the data. The use of html and xml filters in templates is still required to
ensure that "dangerous" characters or strings can be safely displayed.

=cut

sub test_orders_for_xss_characters : Tests() {
    my ($self) = @_;

    my %tests = (
        succeed => {
            html_escaped    => {
                before  => q|&lt; &gt; "  '   + _ ) ( * &amp; ^ %  $ /&gt;  test  + _ ) ( * &amp; ^ % $ test 3  &amp; &amp; &amp; &amp;|,
                after   => q|< > "  '   + _ ) ( * & ^ %  $ />  test  + _ ) ( * & ^ % $ test 3  & & & &|,
            },
            html_double_escaped => {
                before  => q|&lt; &gt; "  '   + _ ) ( * &amp; ^ %  $ /&gt;  test  + _ ) ( * &amp; ^ % $ test 3  &amp; &amp; &amp; &amp;amp;|,
                after   => q|< > "  '   + _ ) ( * & ^ %  $ />  test  + _ ) ( * & ^ % $ test 3  & & & &amp;|,
            },
            CDATA => {
                before  => q|<![CDATA[<]]>script<![CDATA[>]]>alert('xss')<![CDATA[<]]>/script<![CDATA[>]]>|,
                after   => q|<script>alert('xss')</script>|,
            },
            tag_attack  => {
                before  => q|seemingly innocent</GIFT_MESSAGE><ITEM_PRICE>0.00</ITEM_PRICE><GIFT_MESSAGE>seemingly innocent|,
                after   => q|seemingly innocentseemingly innocent|,
            },
            count_node  => {
                before  => q|count(/child::node())|,
                after   => q|count(/child::node())|,
            },
        },
        fail    => {
            external_entity => {
                before  => q|<!DOCTYPE foo [<!ELEMENT foo ANY ><!ENTITY xxe SYSTEM "file:///etc/passwd" >]><foo>&xxe;</foo>]>|,
                after   => q|<!DOCTYPE foo [<!ELEMENT foo ANY ><!ENTITY xxe SYSTEM "file:///etc/passwd" >]><foo>&xxe;</foo>]>|,
            },
        },
    );

    foreach my $channel (@{$self->{nap_channels}}) {

        my $product = $self->{test_products}{$channel->id}[0];

        my $orderhash = {
            customer => {
                id => $self->{test_customer}{channel}{$channel->id}->is_customer_number,
                language_preference => $self->{test_customer}{language_preference},
            },
            order => {
                pre_auth_code  => $self->{test_order}{pre_auth_code},
                tender_type    => $self->{test_order}{tender_type},
                channel_prefix => $channel->business->config_section,
                shipping_price => $self->{test_order}{shipping_price},
                shipping_tax   => $self->{test_order}{shipping_tax},
                tender_amount  => $self->{test_order}{tender_amount},
                items => [
                    {
                        sku         => $product->{variant}->sku,,
                        ol_id       => $self->{test_order}{item}{ol_id},
                        description => $self->{test_order}{item}{desc},
                        unit_price  => $self->{test_order}{item}{unit_price},
                        tax         => $self->{test_order}{item}{tax},
                        duty        => $self->{test_order}{item}{duty},
                    }
                ],
            }
        };

        foreach my $test ( keys %{$tests{succeed}} ) {
            note "Testing success with $test gift message";
            $orderhash->{order}->{gift} = 'Y';
            $orderhash->{order}->{gift_message} = $tests{succeed}->{$test}->{before};

            my ($order) = $self->{xml_parser}->create_and_parse_order($orderhash);

            my $order_dbix = $self->_digest_order_and_run_standard_order_tests($order, {
                customer_language => {
                    is_default          => 0,
                    language_preference => $self->{test_customer}{language_preference},
                },
                order_language => $self->{test_customer}{language_preference},
                gift_message => $tests{succeed}->{$test}->{after},
            } );

            my $shipment = $order_dbix->get_standard_class_shipment;
            isa_ok( $shipment, 'XTracker::Schema::Result::Public::Shipment' );
            cmp_ok( $shipment->gift_message,
                    'eq',
                    $tests{succeed}->{$test}->{after},
                    'Gift Message is as expected '.$tests{succeed}->{$test}->{after}
            );
        }

        foreach my $test ( keys %{$tests{fail}} ) {
            note "Testing fail with $test gift message";
            # Each of these should result in an order XML file that cannot be
            # parsed thus causing an exception
            $orderhash->{order}->{gift_message} = $tests{fail}->{$test}->{before};

            throws_ok( sub {
                    my ($order) = $self->{xml_parser}->create_and_parse_order($orderhash);
                },
                qr|parser error :|,
                'Dies with parser error',
            );
        }

    }
}

=head2 test_xml_and_json_order_line_item_sale_flag

=cut

sub test_xml_and_json_order_line_item_sale_flag : Tests() {
    my $self    = shift;

    my %tests   = (
        "NO 'SALE' tag set, default to 'NO'" => {
        },
        "'SALE' tag set to 'NO'" => {
           tag => 'NO',
           expect => $SHIPMENT_ITEM_ON_SALE_FLAG__NO,
        },
        "'SALE' tag set to 'YES'" => {
           tag => 'YES',
           expect => $SHIPMENT_ITEM_ON_SALE_FLAG__YES,
        },
        "'SALE' tag set to 'GARBAGE', to use an Unkown State and should default to 'No'" => {
           tag => 'GARBAGE',
           expect => $SHIPMENT_ITEM_ON_SALE_FLAG__NO,
        },
    );

    my @test_nap_channels   = (
        map { { channel => $_, parser => 'xml_parser' } }
            @{ $self->{nap_channels} }
    );
    my @test_json_channels  = (
        map { { channel => $_, parser => 'napjson_parser' } }
            @{ $self->{json_channels} }
    );

    foreach my $test_channel ( @test_nap_channels, @test_json_channels ) {
        my $channel = $test_channel->{channel};
        my $parser  = $test_channel->{parser};
        my $product = $self->{test_products}{$channel->id}[0];

        foreach my $label ( keys %tests ) {
            note "Testing: Channel - " . $channel->name . ", with " . $label;
            note "using Parser: ${parser}";
            my $test = $tests{ $label };

            my $orderhash = {
                customer => {
                    id => $self->{test_customer}{channel}{$channel->id}->is_customer_number,
                },
                order => {
                    pre_auth_code  => $self->{test_order}{pre_auth_code},
                    tender_type    => $self->{test_order}{tender_type},
                    channel_prefix => $channel->business->config_section,
                    shipping_price => $self->{test_order}{shipping_price},
                    shipping_tax   => $self->{test_order}{shipping_tax},
                    tender_amount  => $self->{test_order}{tender_amount},
                    items => [
                        {
                            sku         => $product->{variant}->sku,,
                            ol_id       => $self->{test_order}{item}{ol_id},
                            description => $self->{test_order}{item}{desc},
                            unit_price  => $self->{test_order}{item}{unit_price},
                            tax         => $self->{test_order}{item}{tax},
                            duty        => $self->{test_order}{item}{duty},
                            ( exists $test->{tag} ? ( sale => $test->{tag} ) : () ),
                        }
                    ],
                }
            };

            my ($order) = $self->{ $parser }->create_and_parse_order( $orderhash );

            my $order_obj = $self->_digest_order_and_run_common_tests( $order );
            my $shipment  = $order_obj->get_standard_class_shipment;
            my $ship_item = $shipment->shipment_items->first;

            if ( ! exists $test->{expect} ) {
                ok( ! $ship_item->sale_flag_id, "Shipment Item's 'sale_flag_id' is undef" );
            }
            else {
                cmp_ok( $ship_item->sale_flag_id,
                        '==',
                        $test->{expect},
                        "Shipment Item's 'sale_flag_id' is as expected"
                      );
            }
        }
    }
}

=head2 test__Order_tender_type

Tests tender_type passed in is correctly parsed.

=cut

sub test__Order_tender_type : Tests() {
    my $self = shift;

    # get any NAP Channel
    my $channel = $self->{nap_channels}[0];

    my $product = $self->{test_products}{ $channel->id }[0];

    my $orderhash = {
        customer => {
            id => $self->{test_customer}{channel}{ $channel->id }->is_customer_number,
        },
        order => {
            pre_auth_code  => $self->{test_order}{pre_auth_code},
            tender_type    => $self->{test_order}{tender_type},
            channel_prefix => $channel->business->config_section,
            shipping_price => $self->{test_order}{shipping_price},
            shipping_tax   => $self->{test_order}{shipping_tax},
            tender_amount  => $self->{test_order}{tender_amount},
            items => [
                {
                    sku         => $product->{variant}->sku,,
                    ol_id       => $self->{test_order}{item}{ol_id},
                    description => $self->{test_order}{item}{desc},
                    unit_price  => $self->{test_order}{item}{unit_price},
                    tax         => $self->{test_order}{item}{tax},
                    duty        => $self->{test_order}{item}{duty},
                }
            ],
        }
    };


     my %tests   = (
        "'Klarna' tender type" => {
           type => 'klarna',
           expect => 'Card Debit',
        },
        "'KLArna' tender type" => {
           type => 'KLArna',
           expect => 'Card Debit',
        },
        "'Card' tender type" => {
           type => 'Card',
           expect => 'Card Debit',
        },
        "'Store Credit' tender type" => {
            type => 'Store Credit',
            expect => 'Store Credit',
        },

    );

    foreach my $label ( keys %tests ) {
        note "********* Testing : ${label} *********** ";
        my $test = $tests{ $label};
        $orderhash->{order}->{tender_type} = $test->{type};
        my ( $order ) = $self->{xml_parser}->create_and_parse_order( $orderhash );

        my @tenders = $order->all_tenders;
        cmp_ok($order->number_of_tenders ,'==', 1, "Only one Tender line is present ");
        cmp_ok( $tenders[0]->type, 'eq', $test->{expect}, "Tender Type is Correct" );
    }

}

=head2 _export_pre_order_and_calc_tender_amount

Helper to set a Pre-Order to be Exported and return
a list of Items to be used in an Order and also
calculate the Tender Amount and store it in
'$self->{test_order}{tender_amount}'.

=cut

sub _export_pre_order_and_calc_tender_amount {
    my ( $self, $pre_order ) = @_;

    my @order_items;
    my $tender_amount = 0;

    my @items = $pre_order->pre_order_items->all;

    foreach my $item ( @items ) {

        $item->update_status($PRE_ORDER_ITEM_STATUS__EXPORTED);
        $item->reservation->update( { status_id =>  $RESERVATION_STATUS__UPLOADED } );

        push @order_items, {
            sku         => $item->variant->sku,
            ol_id       => $item->id,
            description => $item->variant->product->product_attribute->name,
            unit_price  => $self->{test_order}{item}{unit_price},
            tax         => $self->{test_order}{item}{tax},
            duty        => $self->{test_order}{item}{duty},
        };

        $tender_amount += (
            $self->{test_order}{item}{unit_price} +
            $self->{test_order}{item}{tax}        +
            $self->{test_order}{item}{duty}
        );
    }

    $self->{test_order}{tender_amount} = $tender_amount;

    return \@order_items;
}

=head2 _digest_order_and_run_pre_order_tests
=cut

sub _digest_order_and_run_pre_order_tests {
    my ($self, $order, $pre_order) = @_;

    note ref($order->preorder);

    my $order_dbix = $self->_digest_order_and_run_common_tests($order);

    isa_ok($order->preorder, 'XTracker::Schema::Result::Public::PreOrder', 'PreOrder is correct');

    is($order->preorder_number, $pre_order->pre_order_number, 'Correct preorder number');

    # Test Payment
    my $order_dbix_payment = $order_dbix->payments->first;
    my $pre_order_payment  = $pre_order->get_payment;

    is($order_dbix_payment->psp_ref, $pre_order_payment->psp_ref, 'PSP refs match');
    is($order_dbix_payment->settle_ref, $pre_order_payment->settle_ref, 'Settle refs match');
    ok($order_dbix_payment->fulfilled, 'Payment is fulfilled');
    is($order_dbix_payment->preauth_ref, $pre_order_payment->preauth_ref, 'PreAuth refs match');
    is( $order_dbix_payment->payment_method->payment_method, 'Credit Card',
                    "Payment Method on 'orders.payment' is for Card" );

    # Test link between orders and preorders
    ok($order_dbix->has_preorder, 'Order DBIx object has preorder');
    cmp_ok($order_dbix->link_orders__pre_orders->first->pre_order_id, '==', $pre_order->id, 'Order has correct link to the pre order');

    # Test shipment and shipment items & check Sales Invoice
    my $shipment = $order_dbix->get_standard_class_shipment;

    my $invoice = $shipment->get_sales_invoice;
    isa_ok( $invoice, 'XTracker::Schema::Result::Public::Renumeration', "Found a Sales Invoice for the Shipment" );
    cmp_ok( $invoice->grand_total, '==', $self->{test_order}{tender_amount}, "Invoice Value as Expected" );
    cmp_ok( $invoice->renumeration_type_id, '==', $RENUMERATION_TYPE__CARD_DEBIT, "Type is 'Card Debit'" );
    cmp_ok( $invoice->renumeration_class_id, '==', $RENUMERATION_CLASS__ORDER, "Class is 'Order'" );
    cmp_ok( $invoice->renumeration_status_id, '==', $RENUMERATION_STATUS__COMPLETED, "Status is 'Completed'" );
    like( $invoice->invoice_nr, qr/\d+\-\d+/, "and has an 'Invoice Nr'" );
    cmp_ok( $invoice->renumeration_status_logs->count, '==', 1, "and found 1 Invoice Status Log" );

    ok($shipment->is_held(), 'Shipment is on hold')
                or diag "ERROR - Shipment is NOT on Hold: '" . $shipment->shipment_status->status . "'";

    foreach my $item ($shipment->shipment_items) {
        ok($item->special_order_flag, 'Special order flag set');

        # Test link between shipment item and reservation
        my $pre_order_item = $pre_order->pre_order_items->search({variant_id => $item->variant_id})->first;
        cmp_ok($item->link_shipment_item__reservations->count, '==', 1, 'Shipment item has one link to reservation');
        cmp_ok($item->link_shipment_item__reservations->first->reservation_id, '==', $pre_order_item->reservation->id,
                                                                'Shipment item is correctly linked with reservation');

        # Test link between shipment item and invoice item
        my $inv_item    = $item->renumeration_items->first;
        isa_ok( $inv_item, 'XTracker::Schema::Result::Public::RenumerationItem', "Found Invoice Item for Shipment Item" );
        cmp_ok( $inv_item->renumeration_id, '==', $invoice->id, "and is for the Sales Invoice" );
        cmp_ok( $inv_item->unit_price, '==', $item->unit_price, "Invoice Item - Unit Price as Expected" );
        cmp_ok( $inv_item->tax, '==', $item->tax, "Invoice Item - Tax as Expected" );
        cmp_ok( $inv_item->duty, '==', $item->duty, "Invoice Item - Duty as Expected" );
    }

    return $order_dbix;
}

sub _check_and_create_order {
    my $self        = shift;
    my $orderhash   = shift;


    my ($order) = $self->{xml_parser}->create_and_parse_order($orderhash);
    my $order_obj = $order->digest( { duplicate => 0 } );

    isa_ok($order_obj, 'XTracker::Schema::Result::Public::Orders', 'Order returned from digest');
    my ( $total_order_value , $sum)  = $self->_get_order_info($order_obj);

    return  {
        tender_sum  => $sum,
        order_total => $total_order_value,
     };

}


=head2 _get_order_info

=cut

sub _get_order_info {
    my $self  = shift;
    my $order = shift;

    my $sum = 0;
    for ($order->tenders->all) {
        $sum += $_->value;
    }

    return ( $order->total_value, $sum );

}

=head2 _setup_orderhash

=cut

sub _setup_orderhash {
    my $self    = shift;
    my $channel = shift;
    my $args    = shift;

    my $product         = $self->{test_products}{$channel->id}[0];
    my $pre_auth_code   = Test::XTracker::Data->get_next_preauth($self->{schema}->storage->dbh);
    my $id              = ( $self->{schema}->resultset('Public::Customer')->get_column('is_customer_number')->max + 1 );

    my %shipping;
    my %customer_data;


    if(exists $args->{shipping_details} ) {
        $shipping{shipping}{mobile_phone} = $args->{shipping_details}->{shipping_mobile_phone};
        $shipping{shipping}{work_phone}   = $args->{shipping_details}->{shipping_work_phone};
        $shipping{shipping}{email}        = $args->{shipping_details}->{email} ;
    }

    if( exists $args->{customer} ) {
        $customer_data{mobile_phone} = $args->{customer}->{mobile_phone};
        $customer_data{work_phone} = $args->{customer}->{work_phone};
        $customer_data{email}       = $args->{customer}->{email};
    }


    my $orderhash = {
        customer => {
            id => $id,
            %customer_data,

        },
        %shipping,
        order => {
            gross_total    => 90,
            shipping_price => 5,
            shipping_tax   => 5,
            pre_auth_code  => $pre_auth_code,
            tenders        => [
                {
                     id     => 2,
                     type   => 'Store Credit',
                     value  => $args->{store_credit} // 10,
                     rank   => 2,
                },
                {
                    id              => 1,
                    type            => 'Card',
                    pre_auth_code   => $pre_auth_code,
                    value           => $args->{card_tender_value} // 80,
                    rank            => 1,
                },
            ],
            items => [
                {
                    sku         => $product->{variant}->sku,
                    ol_id       => 123,
                    unit_price  => 80,
                    desc        => 'blah blah',
                    tax         => 8,
                    duty        => 2,
                }
           ],
        },
    };

    if (exists $args->{no_card}) {
        delete $orderhash->{order}->{tenders}[1];
    }

    return $orderhash;

}

=head2 teardown
=cut

sub teardown :Test(teardown) {
    my ($self) = @_;

    $self->SUPER::teardown();

    $self->{schema}->txn_rollback;
    Test::XTracker::Data::Order::Parser::PublicWebsiteXML->purge_order_directories();
}

Test::Class->runtests;
