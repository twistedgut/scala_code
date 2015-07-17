#!/usr/bin/env perl


use NAP::policy "tt", 'test';

use parent "NAP::Test::Class";

use Test::XTracker::Data;
use Test::XTracker::Data::Order::Parser::PublicWebsiteXML;
use Test::XTracker::Data::Operator;
use Test::XTracker::Data::PreOrder;
use XTracker::Constants qw ( :application );
use XTracker::Database::Attributes qw(set_shipping_restriction);
use Test::XT::Flow;
use Test::XTracker::Mock::PSP;
use XTracker::Constants::FromDB   qw(
    :department
    :pre_order_item_status
    :reservation_status
    :authorisation_level
);

=head1 NAME

t/20-units/pre_order/shipping_restriction.t

=head1 DESCRIPTION

Tests the shipping restrictions relating to a pre-order.

=head1 TESTS

=cut

sub start_tests :Test(startup => no_plan) {
    my ($self) = @_;

    # Mock the get_restricted_countries_by_designer_id method that's used by
    # can_ship_to_address (within XT::Rules), so it never fails because the
    # service is not there.
    $self->{mock_designer_service} = Test::MockModule->new('XT::Service::Designer');
    $self->{mock_designer_service}->mock(
        get_restricted_countries_by_designer_id => sub {
            note '** In Mocked get_restricted_countries_by_designer_id **';
            # Return an empty country list.
            return [];
        }
    );

    $self->{schema} = Test::XTracker::Data->get_schema();
    $self->{restrictions} = {};

}

sub setup : Test(setup => no_plan) {
    my $self = shift;
    $self->SUPER::setup;

    $self->{data}   = Test::XT::Data->new_with_traits( {
        traits  => [
            'Test::XT::Data::Order',
            'Test::XT::Data::Customer',
        ],
    } );

    $self->{parser}      = Test::XTracker::Data::Order::Parser::PublicWebsiteXML->new();
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

    ## no critic(ProtectPrivateVars)
    $self->{original_send_email_alert_for_preorder} = \&XT::Data::Order::_send_email_alert_for_preorder;
    $self->{restrictions}  = {};



    $self->schema->txn_begin;
}

sub teardown : Test(teardown => no_plan) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->schema->txn_rollback;
}

sub shutdown_tests : Tests( shutdown => no_plan ) {
    my $self    = shift;

    no warnings 'redefine';

    # restore functions that were Re-Defined, so they don't ruin the rest of the Class tests
    ## no critic(ProtectPrivateVars)
    *XT::Data::Order::_send_email_alert_for_preorder = $self->{original_send_email_alert_for_preorder};
    use warnings 'redefine';

    $self->SUPER::shutdown();
}

=head2 test_create_pre_order_with_shipping_restriction

    Checks to see when a pre-order has a shipping restricted product, pre-order email sent
    has the content mentioning about restricted products.

=cut

sub test_create_pre_order_with_shipping_restriction : Tests() {
    my $self = shift;

    no warnings 'redefine';
    ## no critic(ProtectPrivateVars)
    *XT::Data::Order::_send_email_alert_for_preorder    = sub  {
        _redefined_send_email_alert_for_preorder ($self, @_);
    };

    use warnings 'redefine';

    my $channel   = Test::XTracker::Data->channel_for_nap();
    my $pre_order = Test::XTracker::Data::PreOrder->create_complete_pre_order_for_channel($channel);
    my @order_items;

    $self->{test_order}{tender_amount} = 0;

    my $shipping_restriction = Test::XT::Rules::Solve->solve( 'Shipment::restrictions', {
        restriction => 'CHINESE_ORIGIN',
    } );

    my $restricted_country  = $self->schema->resultset('Public::Country')
        ->find_by_name( $shipping_restriction->{address}{country} );

    my @product_ids;

    foreach my $item ($pre_order->pre_order_items) {

        $item->update_status($PRE_ORDER_ITEM_STATUS__EXPORTED);
        $item->reservation->update( { status_id =>  $RESERVATION_STATUS__UPLOADED } );
        my $ship_attr   = $item->variant->product->shipping_attribute;

        $item->variant->product->shipping_attribute->update( $shipping_restriction->{shipping_attribute} );

        push(@order_items, {
            sku         => $item->variant->sku,
            ol_id       => $item->id,
            description => $item->variant->product->product_attribute->name,
            unit_price  => $self->{test_order}{item}{unit_price},
            tax         => $self->{test_order}{item}{tax},
            duty        => $self->{test_order}{item}{duty},
        });

        push(@product_ids, $item->variant->product->id);

    }
    my ($order) = $self->{parser}->create_and_parse_order({
        customer => {
            country => $restricted_country->code,
        },

        order => {
            pre_auth_code   => $pre_order->get_payment->preauth_ref,
            tender_type     => $self->{test_order}{tender_type},
            preorder_number => $pre_order->pre_order_number,
            channel_prefix  => $channel->business->config_section,
            shipping_price  => '0.00',
            shipping_tax    => '0.00',
            tender_amount   => $self->{test_order}{tender_amount},
            items           => [@order_items],
        }
    });

    my $order_obj = $order->digest( { duplicate => 0 } );
    isa_ok($order_obj, 'XTracker::Schema::Result::Public::Orders', 'Order returned from digest');

    # Check pre_order email has the expected content
    ok( $self->{restrictions}->{restrict}, "There are product restrictions as expected");
    cmp_ok(
        $self->{restrictions}->{restricted_products}->{$product_ids[0]}->{reasons}[0]->{reason},
        'eq',
        'Chinese origin product',
        "Product Restricted due to Chinese Origin as expected"
    );
}

sub _redefined_send_email_alert_for_preorder {
    my $self    = shift;
    my $class   = shift;

    note "================== IN REDEFINED 'send_email_alert_for_preorder FUNCTION ==================";

    # Populate restrictions hash
    $self->{restrictions} = $class->_shipping_restrictions;

    return 1;

}

Test::Class->runtests;
