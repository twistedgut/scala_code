#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::Hacks::TxnGuardRollback;
use Test::Most;

use base 'Test::Class';

use Moose qw|has|;
use XTracker::Config::Local qw|:DEFAULT|;
use Test::XTracker::MessageQueue;
use XTracker::Constants::FromDB qw|
    :channel
    :refund_charge_type
    :renumeration_type
    :renumeration_status
    :renumeration_class
    :customer_issue_type
    :currency
    |;
use Data::Dump 'pp';
use List::Util 'sum';
use Carp;
use warnings FATAL => 'all';

has order => (is => 'rw', isa => 'XTracker::Schema::Result::Public::Orders');
has schema => (is => 'rw', isa => 'XTracker::Schema', handles=>[qw/resultset/]);
has domain => (is => 'rw', isa => 'XT::Domain::Returns');
has request => (is => 'rw', isa => 'HashRef');

our $DC = config_var('DistributionCentre', 'name');
our $instance = config_var('XTracker', 'instance');
our $OUTNET_CHAN = uc( "OUTNET-${instance}" );
our $NAP_CHAN = uc( "NAP-${instance}" );

sub startup : Tests( startup => no_plan ) {
    my $test = shift;
    use_ok 'XT::Domain::Returns';

    $test->schema(
        Test::XTracker::Data->get_schema
    );

    # set-up a Transaction to run the tests in so
    # everything gets rolled back when the tests ends
    $test->schema->txn_begin;

    #
    # Set-up Shipping Countries used in the Tests
    #

    # Domestic Country should get refunded and not charged Tax & Duty
    $test->{domestic_country}   = $test->schema->resultset('Public::Country')
                                            ->search( { country => config_var( 'DistributionCentre', 'country' ) } )
                                                ->first;
    # clear out any existing records set-up for this country
    $test->{domestic_country}->return_country_refund_charges->delete;
    $test->{domestic_country}->sub_region->return_sub_region_refund_charges->delete;

    # set our own for the test for the Domestic Country
    $test->{domestic_country}->create_related( 'return_country_refund_charges', {
                                                        refund_charge_type_id => $REFUND_CHARGE_TYPE__TAX,
                                                        can_refund_for_return => 1,
                                                        no_charge_for_exchange => 1,
                                                    } );
    $test->{domestic_country}->create_related( 'return_country_refund_charges', {
                                                        refund_charge_type_id => $REFUND_CHARGE_TYPE__DUTY,
                                                        can_refund_for_return => 1,
                                                        no_charge_for_exchange => 1,
                                                    } );

    # get another country and make sure it does get charged and not refunded Tax & Duty
    $test->{charges_country}    = $test->schema->resultset('Public::Country')
                                            ->search( { country => { '!=' => config_var( 'DistributionCentre', 'country' ) } } )
                                                ->first;
    # clear out any existing records set-up for this country to make sure it does charge and not get refunded
    $test->{charges_country}->return_country_refund_charges->delete;
    $test->{charges_country}->sub_region->return_sub_region_refund_charges->delete;
}

sub shut_down : Tests( shutdown => no_plan ) {
    my $self    = shift;
    $self->schema->txn_rollback;
}

sub setup : Tests( setup => no_plan ) {
    my $test = shift;
    $test->setup_domain;
}

sub test_always_refund_to_card_first : Tests {
    my $test = shift;
    $test->setup_order([
        { type => 'card_debit', value => 660 },
        { type => 'store_credit', value => 640 }
        ]);

    $test->setup_return_request;
    my $split = $test->domain->get_renumeration_split($test->request);
    ok($split->[0]->{renumeration_type_id} == $RENUMERATION_TYPE__CARD_REFUND);
}

sub test_return_with_cc_and_store_credit : Tests {
    my $test = shift;
    return 'DC1 test' unless $DC eq 'DC1';
    $test->setup_order([
        { type => 'card_debit', value => 1060 },
        { type => 'store_credit', value => 240 }
        ]);

    $test->setup_return_request;
    my $split = $test->domain->get_renumeration_split($test->request);

    $test->check_renumeration_split($split, [
        {
            renumeration_items => [
            { duty => 5, tax => 10, unit_price => 100 },
            { duty => 5, tax => 10, unit_price => 260 },
            { duty => 5, tax => 10, unit_price => 320 },
            { duty => 5, tax => 10, unit_price => 320 },
            ],
            renumeration_tenders => [ { value => 1060 } ],
            type => 'card_refund',
        },
        {
            renumeration_items => [
            { duty => 0, tax => 0, unit_price => 240 },
            ],
            renumeration_tenders => [ { value => 240 } ],
            type => 'store_credit',
        },
        ]);
}

sub test_return_with_cc_and_store_credit_and_gift_voucher : Tests {
    my $test = shift;
    return 'DC1 test' unless $DC eq 'DC1';
    $test->setup_order([
        { type => 'card_debit', value => 800 },
        { type => 'store_credit', value => 240 },
        { type => 'voucher_credit', value => 260 }
        ]);

    $test->setup_return_request;
    my $split = $test->domain->get_renumeration_split($test->request);

    $test->check_renumeration_split($split, [
        {
            renumeration_items => [
            { duty => 5, tax => 10, unit_price => 0 },
            { duty => 5, tax => 10, unit_price => 100 },
            { duty => 5, tax => 10, unit_price => 320 },
            { duty => 5, tax => 10, unit_price => 320 },
            ],
            renumeration_tenders => [ { value => 800 } ],
            type => 'card_refund',
        },
        {
            renumeration_items => [
            { duty => 0, tax => 0, unit_price => 500 },
            ],
            renumeration_tenders => [
            { value => 230 },
            { value => 270 },
            ],
            type => 'store_credit',
        },
        ]);
}

sub test_return_with_store_credit_and_gift_vouhers : Tests {
    my $test = shift;
    return 'DC1 test' unless $DC eq 'DC1';
    $test->setup_order([
        { type => 'store_credit', value => 300 },
        { type => 'voucher_credit', value => 220 },
        { type => 'voucher_credit', value => 180 },
        { type => 'voucher_credit', value => 210 },
        { type => 'voucher_credit', value => 185 },
        { type => 'voucher_credit', value => 205 }
        ]);

    $test->setup_return_request;
    my $split = $test->domain->get_renumeration_split($test->request);

    $test->check_renumeration_split($split, [
        {
            renumeration_items => [
            { duty => 5, tax => 10, unit_price => 100 },
            { duty => 5, tax => 10, unit_price => 320 },
            { duty => 5, tax => 10, unit_price => 320 },
            { duty => 5, tax => 10, unit_price => 500 },
            ],
            renumeration_tenders => [
            { value => 180 },
            { value => 185 },
            { value => 210 },
            { value => 215 },
            { value => 220 },
            { value => 290 },
            ],
            type => 'store_credit',
        },
        ]);
}

sub test_part_return_with_store_credit_and_gift_vouchers : Tests {
    my $test = shift;
    return 'DC1 test' unless $DC eq 'DC1';
    $test->setup_order([
        { type => 'store_credit', value => 240 },
        { type => 'voucher_credit', value => 400 },
        { type => 'voucher_credit', value => 270 },
        { type => 'voucher_credit', value => 185 },
        { type => 'voucher_credit', value => 205 }
    ]);

    $test->setup_part_return_request;
    my $split = $test->domain->get_renumeration_split($test->request);

    $test->check_renumeration_split($split, [
        {
            renumeration_items => [
            { duty => 5, tax => 10, unit_price => 320 },
            { duty => 5, tax => 10, unit_price => 320 },
            { duty => 5, tax => 10, unit_price => 500 },
            ],
            renumeration_tenders => [
            { value => 115 },
            { value => 185 },
            { value => 215 },
            { value => 270 },
            { value => 400 },
            ],
            type => 'store_credit',
        },
        ]);
}

sub test_part_return : Tests {
    my $test = shift;
    return 'DC1 test' unless $DC eq 'DC1';
    $test->setup_order;
    $test->setup_part_return_request;

    my $split = $test->domain->get_renumeration_split($test->request);

    $test->check_renumeration_split($split, [
        {
            renumeration_items => [
            { duty => 5, tax => 10, unit_price => 295 },
            ],
            renumeration_tenders => [
            { value => 310 },
            ],
            type => 'card_refund',
        },
        {
            renumeration_items => [
            { duty => 0, tax => 0, unit_price => 25 },
            { duty => 5, tax => 10, unit_price => 320 },
            { duty => 5, tax => 10, unit_price => 500 },
            ],
            renumeration_tenders => [
            { value => 210 },
            { value => 275 },
            { value => 390 },
            ],
            type => 'store_credit',
        },
        ]);
}

# test returns which normally don't get tax/duty refunded
sub test_return_with_no_tax_or_duty : Tests {
    my $test = shift;
    return 'DC1 test' unless $DC eq 'DC1';
    $test->setup_order_with_charges;
    $test->setup_return_request_no_tax_refunds;

    my $split = $test->domain->get_renumeration_split($test->request);

    $test->check_renumeration_split($split, [
        {
            renumeration_items => [
            { duty => 0, tax => 0, unit_price => 100  },
            { duty => 0, tax => 0, unit_price => 210  },
            ],
            renumeration_tenders => [
            { value => 310 },
            ],
            type => 'card_refund',
        },
        {
            renumeration_items => [
            { duty => 0, tax => 0, unit_price => 110 },
            { duty => 0, tax => 0, unit_price => 320 },
            { duty => 0, tax => 0, unit_price => 500 },
            ],
            renumeration_tenders => [
            { value => 210 },
            { value => 330 },
            { value => 390 },
            ],
            type => 'store_credit',
        },
        ]);
}

sub test_explicit_full_refund : Tests {
    my $test = shift;
    return 'DC1 test' unless $DC eq 'DC1';
    $test->setup_order_with_charges;
    $test->setup_return_request_no_tax_refunds;

    my ($item1, $item2) = sort { $a <=> $b } keys %{$test->request->{return_items}};

    # set to full refund
    $test->request->{return_items}{$item1}{full_refund} = 1;

    # set to reason that gives full refund
    $test->request->{return_items}{$item2}{reason_id} = $CUSTOMER_ISSUE_TYPE__7__DEFECTIVE_FSLASH_FAULTY;

    my $split = $test->domain->get_renumeration_split($test->request);

    $test->check_renumeration_split($split, [
        {
            renumeration_items => [
            { duty => 5, tax => 10, unit_price => 100 },
            { duty => 5, tax => 10, unit_price => 180 },
            ],
            renumeration_tenders => [
            { value => 310 },
            ],
            type => 'card_refund',
        },
        {
            renumeration_items => [
            { duty => 0, tax => 0, unit_price => 140 },
            { duty => 0, tax => 0, unit_price => 320 },
            { duty => 0, tax => 0, unit_price => 500 },
            ],
            renumeration_tenders => [
            { value => 210 },
            { value => 370 },
            { value => 390 },
            ],
            type => 'store_credit',
            shipping => '10.00',
        },
        ]);
}

=head2 test_explicit_full_refund_where_shipping_refund_spans_tenders_using_live_example

Tests using a Live scenario where the Shipping Costs are refunded across two renumerations when
both Store Credit and a Credit Card were used to pay for the Order. There was a BUG where
the Full Shipping Refund was been applied to each renumeration instead of being split up
between them appropriately, this test checkes that BUG has been fixed.

=cut

sub test_explicit_full_refund_where_shipping_refund_spans_tenders_using_live_example : Tests {
    my $test = shift;

    $test->setup_order_with_charges(
        [
            { type => 'card_debit', value => 404.58 },
            { type => 'store_credit', value => 25.00 },
        ],
        {
            shipping_charge => 35.18,
            number_of_items => 1,
            item_prices     => [
                { price => 340.00, tax => 0, duty => 54.40 },
            ],
        },
    );
    $test->setup_return_request_no_tax_refunds;

    my ( $item1 ) = sort { $a <=> $b } keys %{ $test->request->{return_items} };

    # set to full refund
    $test->request->{return_items}{$item1}{full_refund} = 1;

    my $split = $test->domain->get_renumeration_split( $test->request );

    $test->check_renumeration_split($split, [
        {
            renumeration_items => [
                { duty => 54.4, tax => 0, unit_price => 340 },
            ],
            renumeration_tenders => [
                { value => 404.58 },
            ],
            shipping => 10.18,
            type => 'card_refund',
        },
        {
            renumeration_items => [ ],
            renumeration_tenders => [
                { value => '25' },
            ],
            shipping => '25.00',
            type => 'store_credit',
        },
    ] );
}

=head2 test_refund_with_shipping_refund_with_shipping_charge_spans_tenders

This tests the scenario when an Order has been paid using both Credit Card and
Store Credit and gets a Refund which includes the Shipping Costs but because it's
for The Outnet there are Return Charges as well. This makes sure that the Shipping
Refund is spead across both renumerations appropriately but also ensures that Returns
Charge is only applied to the first Renumeration and is zero on the second.

=cut

sub test_refund_with_shipping_refund_with_shipping_charge_spans_tenders : Tests {
    my $test = shift;
    return 'DC1 test' unless $DC eq 'DC1';

    $test->setup_order_with_charges( [
            { type => 'card_debit', value => 350.58 },
            { type => 'store_credit', value => 79.00 },
        ],
        {
            channel         => $OUTNET_CHAN,
            shipping_charge => 35.18,
            number_of_items => 1,
            item_prices     => [
                { price => 340.00, tax => 0, duty => 54.40 },
            ],

            # THIS ISN'T PRETTY
            # TODO: There are NO DBIC Classes created for the
            #       'returns_charge' table and didn't want to
            #       add them just for a test for a BUG ticket
            #       so using 'Romania' which has a Returns
            #       Charge of 16 GBP.
            shipping_country => 'Romania',
        },
    );
    $test->setup_return_request_no_tax_refunds;

    note "Using HARD CODED Shipping Country of 'Romania' which has an entry in the 'returns_charges' table for OUTNET";

    my ( $item1 ) = sort { $a <=> $b } keys %{ $test->request->{return_items} };

    my $split = $test->domain->get_renumeration_split($test->request);

    $test->check_renumeration_split( $split, [
        {
            renumeration_items => [
                { duty => 0, tax => 0, unit_price => 340 },
            ],
            renumeration_tenders => [
                { value => 340 },
            ],
            type => 'card_refund',
        },
    ] );
}

# test exchange logic
sub test_full_exchange : Tests {
    my $test = shift;
    return 'DC1 test' unless $DC eq 'DC1';
    $test->setup_order;
    $test->setup_exchange_request;

    my $split = $test->domain->get_renumeration_split($test->request);

    # No charges, so no renumerations created
    $test->check_renumeration_split($split, []);
}

# exchange with charges
sub test_full_exchange_with_charges : Tests {
    my $test = shift;
    return 'DC1 test' unless $DC eq 'DC1';
    $test->setup_order_with_charges;
    $test->setup_exchange_request_with_charges;

    my $split = $test->domain->get_renumeration_split($test->request);

    $test->check_renumeration_split($split, [
        {
            renumeration_items => [
            { duty => 5, tax => 10, unit_price => 0 },
            { duty => 5, tax => 10, unit_price => 0 },
            { duty => 5, tax => 10, unit_price => 0 },
            { duty => 5, tax => 10, unit_price => 0 },
            ],
            renumeration_tenders => [ ],
            type => 'card_debit',
        },
        ] );
}

# exchange with charges except for
sub test_full_exchange_with_some_charges : Tests {
    my $test = shift;
    return 'DC1 test' unless $DC eq 'DC1';
    $test->setup_order_with_charges;
    $test->setup_exchange_request_with_charges;

    my ($item2) = sort { $a <=> $b } keys %{$test->request->{return_items}};

    # set to reason that gives full refund
    $test->request->{return_items}{$item2}{reason_id} = $CUSTOMER_ISSUE_TYPE__7__DEFECTIVE_FSLASH_FAULTY;

    my $split = $test->domain->get_renumeration_split($test->request);

    $test->check_renumeration_split($split, [
        {
            renumeration_items => [
            { duty => 5, tax => 10, unit_price => 0 },
            { duty => 5, tax => 10, unit_price => 0 },
            { duty => 5, tax => 10, unit_price => 0 },
            ],
            renumeration_tenders => [ ],
            type => 'card_debit',
        },
        ] );
}

sub test_part_exchange : Tests {
    my $test = shift;
    return 'DC1 test' unless $DC eq 'DC1';
    $test->setup_order;
    $test->setup_exchange_request;

    my ($ik) = sort { $a <=> $b } keys %{$test->request->{return_items}};
    delete $test->request->{return_items}{$ik};

    my $split = $test->domain->get_renumeration_split($test->request);

    $test->check_renumeration_split($split, [ ] );
}

sub test_part_exchange_part_return : Tests {
    my $test = shift;
    return 'DC1 test' unless $DC eq 'DC1';
    $test->setup_order;
    $test->setup_exchange_request;

    # This picks the last return_item (sorted by shipment_item_id)
    my ($item) = reverse sort { $a <=> $b } keys %{$test->request->{return_items}};
    $test->request->{return_items}{$item}{type} = 'Return';

    my $split = $test->domain->get_renumeration_split($test->request);

    $test->check_renumeration_split($split, [
        {
            renumeration_items => [
            { duty => 5, tax => 10, unit_price => 295 },
            ],
            renumeration_tenders => [
            { value => 310 },
            ],
            type => 'card_refund',
        },
        {
            renumeration_items => [
            { duty => 0, tax => 0, unit_price => 205 },
            ],
            renumeration_tenders => [
            { value => 205 },
            ],
            type => 'store_credit',
        },
        ] );
}

sub test_part_exchange_part_return_with_charges : Tests {
    my $test = shift;
    return 'DC1 test' unless $DC eq 'DC1';
    $test->setup_order_with_charges;
    $test->setup_exchange_request_with_charges;

    # This picks the last return_item (sorted by shipment_item_id)
    my ($item) = reverse sort { $a <=> $b } keys %{$test->request->{return_items}};
    $test->request->{return_items}{$item}{type} = 'Return';

    my $split = $test->domain->get_renumeration_split($test->request);

    $test->check_renumeration_split($split, [
        {
            renumeration_items => [
            { duty => 0, tax => 0, unit_price => '310.000' }, # Don't know why it does string matching here...
            ],
            renumeration_tenders => [
            { value => 310 },
            ],
            type => 'card_refund',
        },
        {
            renumeration_items => [
            { duty => -5, tax => -10, unit_price => 0 },
            { duty => -5, tax => -10, unit_price => 0 },
            { duty => -5, tax => -10, unit_price => 0 },
            { duty => 0, tax => 0, unit_price => 190 },
            ],
            renumeration_tenders => [
            { value => 145 },
            ],
            type => 'store_credit',
        },
        ] );
}

# shipping charge tests
sub test_charge_and_refund_on_outnet_for_return : Tests {
    my $test = shift;
    return 'DC1 test' unless $DC eq 'DC1';
    $test->setup_order( undef, { channel => $OUTNET_CHAN } );
    $test->setup_return_request;

    my $split = $test->domain->get_renumeration_split($test->request);
    $test->check_renumeration_split($split, [
        {
            renumeration_items => [
            { duty => 5, tax => 10, unit_price => 100 },
            { duty => 5, tax => 10, unit_price => 180 },
            ],
            renumeration_tenders => [
            { value => 310 },
            ],
            type => 'card_refund',
        },
        {
            renumeration_items => [
            { duty => 0, tax => 0, unit_price => 140 },
            { duty => 5, tax => 10, unit_price => 320 },
            { duty => 5, tax => 10, unit_price => 500 },
            ],
            renumeration_tenders => [
            { value => 210 },
            { value => 390 },
            { value => 390 },
            ],
            type => 'store_credit',
        },
        ]);
    $test->check_shipping_refund_charge(0,0);
}

sub test_faulty_so_dont_charge_shipping : Tests {
    my $test = shift;
    return 'DC1 test' unless $DC eq 'DC1';
    $test->setup_order( undef, { channel => $OUTNET_CHAN } );
    $test->setup_return_request;

    my ($si) = sort { $a <=> $b } keys %{$test->request->{return_items}};
    $test->request->{return_items}{$si}{reason_id}
    = $CUSTOMER_ISSUE_TYPE__7__DEFECTIVE_FSLASH_FAULTY;

    my $split = $test->domain->get_renumeration_split($test->request);

    $test->check_renumeration_split($split, [
        {
            renumeration_items => [
            { duty => 5, tax => 10, unit_price => 100 },
            { duty => 5, tax => 10, unit_price => 180 },
            ],
            renumeration_tenders => [
            { value => 310 },
            ],
            type => 'card_refund',
        },
        {
            renumeration_items => [
            { duty => 0, tax => 0, unit_price => 140 },
            { duty => 5, tax => 10, unit_price => 320 },
            { duty => 5, tax => 10, unit_price => 500 },
            ],
            renumeration_tenders => [
            { value => 210 },
            { value => 390 },
            { value => 390 },
            ],
            type => 'store_credit',
        },
        ]);
    $test->check_shipping_refund_charge(0,0);
}

sub test_no_charges_or_refund_on_nap_for_exchange : Tests {
    my $test = shift;
    return 'DC1 test' unless $DC eq 'DC1';
    $test->setup_order(undef);
    $test->setup_exchange_request;

    my ($si) = sort { $a <=> $b } keys %{$test->request->{return_items}};
    $test->request->{return_items}{$si}{reason_id}
    = $CUSTOMER_ISSUE_TYPE__7__DEFECTIVE_FSLASH_FAULTY;

    my $split = $test->domain->get_renumeration_split($test->request);
    $test->check_renumeration_split($split, []);
    $test->check_shipping_refund_charge(0,0);
}

# ** OutNet **

sub test_charge_and_refund_on_outnet_for_exchange : Tests {
    my $test = shift;
    return 'DC1 test' unless $DC eq 'DC1';
    $test->setup_order( undef, { channel => 'OUTNET-INTL' } );
    $test->setup_exchange_request;

    my $split = $test->domain->get_renumeration_split($test->request);
    $test->check_renumeration_split($split, []);
    $test->check_shipping_refund_charge(0,0);
}

# ** NAP **
sub test_no_charges_and_refund_on_nap_for_return : Tests {
    my $test = shift;
    return 'DC1 test' unless $DC eq 'DC1';
    $test->setup_order(undef);
    $test->setup_return_request;

    my ($si) = sort { $a <=> $b } keys %{$test->request->{return_items}};
    $test->request->{return_items}{$si}{reason_id}
    = $CUSTOMER_ISSUE_TYPE__7__DEFECTIVE_FSLASH_FAULTY;

    my $split = $test->domain->get_renumeration_split($test->request);
    $test->check_renumeration_split($split, [
        {
            renumeration_items => [
            { duty => 5, tax => 10, unit_price => 100 },
            { duty => 5, tax => 10, unit_price => 180 },
            ],
            renumeration_tenders => [
            { value => 310 },
            ],
            type => 'card_refund',
        },
        {
            renumeration_items => [
            { duty => 0, tax => 0, unit_price => 140 },
            { duty => 5, tax => 10, unit_price => 320 },
            { duty => 5, tax => 10, unit_price => 500 },
            ],
            renumeration_tenders => [
            { value => 210 },
            { value => 390 },
            { value => 390 },
            ],
            type => 'store_credit',
        },
        ]);
    $test->check_shipping_refund_charge(0,0);
}

sub test_existing_refund_values_taken_off_new_refund : Tests {
    my $test = shift;
    return 'DC1 test' unless $DC eq 'DC1';
    $test->setup_order( undef, { channel => $OUTNET_CHAN } );
    $test->setup_return_request;

    my ($si) = sort { $a <=> $b } keys %{$test->request->{return_items}};
    $test->request->{return_items}{$si}{reason_id}
        = $CUSTOMER_ISSUE_TYPE__7__DEFECTIVE_FSLASH_FAULTY;

    # create renumeration items for a gratuity to be taken
    # off the total refund value for the item
    my $renum   = $test->schema->resultset('Public::Renumeration')->create( {
                                                        invoice_nr  => '',
                                                        shipment_id => $test->order->shipments->first->id,
                                                        renumeration_type_id => $RENUMERATION_TYPE__CARD_REFUND,
                                                        renumeration_class_id => $RENUMERATION_CLASS__GRATUITY,
                                                        renumeration_status_id => $RENUMERATION_STATUS__COMPLETED,
                                                        shipping => 7,
                                                        currency_id => $CURRENCY__GBP,
                                                    } );
    $renum->create_related( 'renumeration_items', {
                                                shipment_item_id    => $si,
                                                unit_price          => 55,
                                                tax                 => 7,
                                                duty                => 3,
                                        } );

    my $split = $test->domain->get_renumeration_split($test->request);
    $test->check_renumeration_split($split, [
        {
            renumeration_items => [
            { duty => 2, tax => 3, unit_price => 45 },
            { duty => 5, tax => 10, unit_price => 245 },
            ],
            renumeration_tenders => [
            { value => 310 },
            ],
            type => 'card_refund',
        },
        {
            renumeration_items => [
            { duty => 0, tax => 0, unit_price => 75 },
            { duty => 5, tax => 10, unit_price => 320 },
            { duty => 5, tax => 10, unit_price => 500 },
            ],
            renumeration_tenders => [
            { value => 210 },
            { value => 325 },
            { value => 390 },
            ],
            type => 'store_credit',
        },
        ]);
    $test->check_shipping_refund_charge(0,0);
}

sub check_shipping_refund_charge {
    my ($test, $expected_refund, $expected_charge) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ($r, $c) = $test->domain->_shipping_refund_charge(
        $test->request
    );

    cmp_ok($expected_refund,'==', $r, 'refunded');
    cmp_ok($expected_charge,'==', $c, 'charged');
}

# create an order thats in a 'charge free' location
# ie tax and duty refunded on return and
# not charged for on an exchange
sub setup_order {
    my ( $test, $tenders, $args ) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $tenders ||= [
        { type => 'card_debit', value => 310 },
        { type => 'store_credit', value => 400 },
        { type => 'voucher_credit', value => 210 },
        { type => 'voucher_credit', value => 380 },
    ];

    my $chan = $args->{channel} // $NAP_CHAN;

    my ($channel,$pids) = Test::XTracker::Data->grab_products({
            how_many => $args->{number_of_items} || 4,
            channel => $chan,
        });

    # get a Shipping Charge Id
    my $ship_charge = $test->schema->resultset('Public::ShippingCharge')
                                    ->search( {
                                            channel_id  => $channel->id,
                                            # if it's for The Outnet then give it a
                                            # Normal Outnet Shipping Charge so that
                                            # Return Shipping Charges/Refunds can be tested
                                            ( ( $chan eq $OUTNET_CHAN && $DC ne 'DC1') ? ( is_return_shipment_free => 0 ) : () ),
                                        } )->first;

    # default Item Prices if none passed in
    my $item_prices = $args->{item_prices} // [
        { price => 100.00, tax => 10, duty => 5},
        { price => 320.00, tax => 10, duty => 5},
        { price => 320.00, tax => 10, duty => 5},
        { price => 500.00, tax => 10, duty => 5},
    ];

    my ($order) = Test::XTracker::Data->do_create_db_order({
            tenders => $tenders,
            channel_id => $channel->id,
            shipping_account_id => $channel->shipping_accounts->first->id,
            shipping_charge_id => $ship_charge->id,
            ( exists( $args->{shipping_charge} ) ? ( shipping_charge => $args->{shipping_charge} ) : () ),
            items =>{
                # assign each SKU a Price
                map { $pids->[ $_ ]{sku} => $item_prices->[ $_ ] } 0..$#{ $pids },
            }
        });

    my $ship = $order->get_standard_class_shipment;

    # If there is a shipping charge update one of the tenders to include it.
    if ( $ship->shipping_charge ) {
        # allocate the Shipping Charge to the lowest Ranked Tender
        my $tender  = $order->tenders->search( {}, { order_by => 'rank, id' } )->first;
        $tender->update( { value =>  \" value + @{[$ship->shipping_charge]}" } )
                            if ( !exists( $args->{shipping_charge} ) );     # no need to add shipping to tenders, if shipping
                                                                            # charge passed in then would expect it to be have
                                                                            # been included in the tenders.
    }

    ok ($order, 'created order');

    $test->order($order);

    $ship->shipment_address->country( $test->{domestic_country}->country );
    $ship->shipment_address->update;
    $test->order->discard_changes;

    $test->order_total;
}

sub order_total {
    my ($test) = @_;
    my $total = 0;

    $total += $test->order->shipments->first->$_  for map {"total_$_"} qw/price tax duty/;

    $total += $test->order->shipments->first->shipping_charge;
}

# charges = no refund of t&d on return
# and charge on t&d on exchange
# applying to:  dc1 - outside eu
# or dc2 - outside us
sub setup_order_with_charges {
    my ( $test, $tenders, $args ) = @_;

    $test->setup_order( $tenders, $args );
    my $ship = $test->order->get_standard_class_shipment;

    $ship->shipment_address->country( $args->{shipping_country} // $test->{charges_country}->country );
    $ship->shipment_address->update;
    $test->order->discard_changes;
}

sub setup_domain {
    my ($test) = @_;
    my $schema = Test::XTracker::Data->get_schema;

    ok(
        my $msg_factory = Test::XTracker::MessageQueue->new({schema => $schema}),
        , "Created msg factory"
    );

    ok(
        my $domain =  XT::Domain::Returns->new(
            schema => $schema,
            msg_factory => $msg_factory,
            strip_split_keys => 0,
        ),
        "Created Returns domain"
    );

    $test->domain($domain);
}

# request which expects refund on tax and duty
sub setup_return_request {
    my ($test) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $shipment = $test->order->get_standard_class_shipment;
    my $req =  {
        shipment_id => $shipment->id,
        return_items => {},
        debug => 1
    };

    for my $item ($shipment->shipment_items->all ) {
        $req->{return_items}{$item->id} = {
            type => 'Return',
            reason_id => $test->random_excuse,
            variant => $item->variant_id,
            _original_price => $item->unit_price,
        };
    }

    $test->request($req);
    return $req;
}

sub setup_part_return_request {
    my ($test) = @_;

    my $req = $test->setup_return_request;
    my ($ik) = sort { $a <=> $b } keys %{$req->{return_items}};
    delete $req->{return_items}{$ik};

    $test->request($req);
}

# no refund on tax and duty
sub setup_return_request_no_tax_refunds {
    my ($test) = @_;

    my $req = $test->setup_return_request;

    for my $item ( map { $req->{return_items}{$_} }
        keys %{$req->{return_items}} ) {
        $item->{_test_refund_tax} = 0;
        $item->{_test_refund_duty} = 0;
    }

    $test->request($req);
}

# exchange expects no charge on tax and duty
# on exchanged item
sub setup_exchange_request {
    my ($test) = @_;

    my $shipment = $test->order->get_standard_class_shipment;
    my $req =  {
        shipment_id => $shipment->id,
        return_items => {}
    };

    for my $item ($shipment->shipment_items->all ) {
        $req->{return_items}{$item->id} =  {
            type => 'Exchange',
            reason_id => $test->random_excuse,
            variant => $item->variant_id,
            _original_price => $item->unit_price,
            _test_charge_tax => 0,
            _test_charge_duty => 0,
        };
    }

    $test->request($req);
    return $req;
}

sub setup_exchange_request_with_charges {
    my ($test) = @_;
    my $req = $test->setup_exchange_request;

    for my $item ( map { $req->{return_items}{$_} }
        keys %{$req->{return_items}} ) {
        $item->{_test_charge_tax} = 1;
        $item->{_test_charge_duty} = 1;
    }

    $test->request($req);
}

sub check_renumeration_split {
    my ($test, $split, $want) = @_;

    # if has card tender should refund to there first.
    if ( $test->order->search_related('tenders',
            { type_id => $RENUMERATION_TYPE__CARD_DEBIT })->count
            and  scalar (@$split)
            and
        $split->[0]->{renumeration_type_id} != $RENUMERATION_TYPE__CARD_REFUND) {
        note "should always refund to card first!";
    }

    my %tender_map = (
        $RENUMERATION_TYPE__CARD_REFUND => 'card_refund',
        $RENUMERATION_TYPE__CARD_DEBIT => 'card_debit',
        $RENUMERATION_TYPE__STORE_CREDIT => 'store_credit',
        $RENUMERATION_TYPE__VOUCHER_CREDIT => 'voucher_credit',
    );

    # Strip out shipment and tender IDs
    my $to_compare = [
        sort { $a->{type} cmp $b->{type} }
            map {
                my $r = $_;
                {
                    type => $tender_map{ $r->{renumeration_type_id} },

                    renumeration_tenders => [
                            map {
                                { value => $_->{value} }
                            }
                            sort {$a->{value} <=> $b->{value}} @{$r->{renumeration_tenders}}
                        ],

                    renumeration_items => [
                            map {
                                { unit_price => $_->{unit_price}, tax => $_->{tax}, duty => $_->{duty} }
                            }
                            sort {$a->{unit_price} <=> $b->{unit_price}} @{$r->{renumeration_items}}
                        ],

                    # Only have shipping and misc_refund keys if they are non-zero
                    defined $r->{shipping} ? (shipping => sprintf('%.2f', $r->{shipping}) ) : (),
                    defined $r->{misc_refund} ? (misc_refund => sprintf('%.2f', $r->{misc_refund}) ) : (),
                }
            } @$split
    ];

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    eq_or_diff( $to_compare, $want );

    my $item_refund_total = $test->item_refund_total($split);

    ok($test->total_refund_from_request >= $item_refund_total,
        'split total must not exceed calculated refund');

    # note 'renumeration split:';
    #note pp $split;
    #note '-' x 80;
}

# calculate total refund expected from the request
sub total_refund_from_request {
    my ($test) = @_;
    my $total = 0;

    my @variant =
        map { $test->request->{return_items}{$_}{variant} }
            grep { $test->request->{return_items}{$_}{type} eq 'Return' }
                keys %{$test->request->{return_items}};

    for my $shipment_item ($test->order->shipments
        ->related_resultset('shipment_items')->search({
                variant_id => {IN => \@variant }
            }, { order_by => 'id' } )) {
        my $item = $test->request->{return_items}{$shipment_item->id};
        $total += $shipment_item->unit_price;

        $total += $shipment_item->tax if $item->{_test_refund_tax};
        $total += $shipment_item->duty if $item->{_test_refund_duty};
    }
    return $total;
}

sub total_charge_from_request {
    my ($test) = @_;
    my $total = 0;

    my @variant =
        map { $test->request->{return_items}{$_}{variant} }
            grep { $test->request->{return_items}{$_}{type} eq 'Exchange' }
                keys %{$test->request->{return_items}};

    for my $shipment_item ($test->order->shipments
        ->related_resultset('shipment_items')->search({
                variant_id => {IN => \@variant }
            }, { order_by => 'id' } )) {
        my $item = $test->request->{return_items}{$shipment_item->id};

        $total += $shipment_item->tax if $item->{_test_charge_tax};
        $total += $shipment_item->duty if $item->{_test_charge_duty};
    }
    return $total;
}

# calculate total refunded to each tender
sub split_tender_total {
    my ($test, $split) = @_;
    my $total = 0;

    for my $renum (@$split) {
        for my $i (@{$renum->{renumeration_items}}) {
            $total += $i->{unit_price} + $i->{tax} + $i->{duty};
        }
    }
    return $total;
}

# calculate total refunded to each item
sub item_refund_total {
    my ($test, $split) = @_;
    my $total = 0;

    for my $renum (@$split) {
        for my $item (@{$renum->{renumeration_items}}) {
            $total += $item->{_refunded} if $item->{_refunded};
        }
    }
    return $total;
}

# add up card debits
sub split_debit_total {
    my ($test, $split) = @_;
    my $total = 0;

    for my $rt (@$split) {
        next unless ($rt->{renumeration_type_id}
            == $RENUMERATION_TYPE__CARD_DEBIT
                and
            $rt->{renumeration_status_id}
            == $RENUMERATION_STATUS__AWAITING_AUTHORISATION);

        $total += sum( map { $_->{tax}, $_->{duty} } @{$rt->{renumeration_items}});
    }
    return $total;
}

=head2 random_excuse

Doesn't return Defective/Faulty which has special cases for returning shipping

=cut

sub random_excuse {
    my @excuse = (
        $CUSTOMER_ISSUE_TYPE__7__DELIVERY_ISSUE,
        $CUSTOMER_ISSUE_TYPE__7__FABRIC,
        $CUSTOMER_ISSUE_TYPE__7__DELIVERY_ISSUE,
        $CUSTOMER_ISSUE_TYPE__7__COLOUR,
        $CUSTOMER_ISSUE_TYPE__7__PRICE,
        $CUSTOMER_ISSUE_TYPE__7__NOT_AS_PICTURED_FSLASH_DESCRIBED,
        $CUSTOMER_ISSUE_TYPE__7__QUALITY,
    );
    return $excuse[int(rand(6))];
}

Test::Class->runtests;
