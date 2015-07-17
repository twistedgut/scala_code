package Test::XT::Data::Order;
use FindBin::libs;
use parent "NAP::Test::Class";

use NAP::policy 'test';

use XTracker::Constants qw( :application );

use XT::Data::Order;

use Test::More::Prefix qw/ test_prefix /;

use XT::Data::Address;
use XT::Data::CustomerName;
use XT::Data::Money;

use XTracker::Config::Local qw( config_var );

use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use Test::XTracker::Mock::PSP;


sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup();

    Test::XTracker::Mock::PSP->use_all_mocked_methods();    # get the PSP Mock in a known state
}

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup();
    $self->{channel} = Test::XTracker::Data->channel_for_mrp();
    $self->{time_zone} = $self->{channel}->timezone;
}

sub test_shutdown : Test( shutdown => no_plan ) {
    my $self = shift;
    $self->SUPER::shutdown();

    Test::XTracker::Mock::PSP->use_all_original_methods();
}

sub nominated_day__dispatch_time__no_nominated_day : Tests() {
    my $self = shift;

    my $order = $self->create_order({
        order_args => { tenders => [], line_items => [], }
    });
    is(
        $order->nominated_dispatch_time,
        undef,
        "No Nominated Day - undef nominated_dispatch_time",
    );
}

sub get_shipping_charge_for_dispatch_daytime {
    my ($self, $time_of_day) = @_;

    my $time_of_day_str = $time_of_day // "";
    ok(
        my $shipping_charge = $self->search_one(
            ShippingCharge => {
                latest_nominated_dispatch_daytime => $time_of_day,
            },
        ),
        "Got Shipping Charge for ($time_of_day_str)",
    );

    return $shipping_charge;
}

sub nominated_day__dispatch_time__nominated_day : Tests() {
    my $self = shift;

    # In production code, this date will be parsed into a UTC tz
    # during import (coerced via DateStamp when assigned the
    # XT::Data::Order->nominated_dispatch_date)
    my $today_date = DateTime->now->truncate(to => "day"); # In UTC
    my $today_date_str = $today_date->ymd;

    my $no_nominated_day_shipping_charge
        = $self->get_shipping_charge_for_dispatch_daytime(undef);
    my $no_nominated_day_sku = $no_nominated_day_shipping_charge->sku;

    my $morning_daytime = "11:00:00";
    my $morning_nominated_day_shipping_charge
        = $self->get_shipping_charge_for_dispatch_daytime($morning_daytime);

    my $evening_daytime = "15:00:00";
    my $evening_nominated_day_shipping_charge
        = $self->get_shipping_charge_for_dispatch_daytime($evening_daytime);

    my $midday_daytime = "17:00:00";
    my $midday_nominated_day_shipping_charge
        = $self->get_shipping_charge_for_dispatch_daytime($midday_daytime);

    my $cases = [
        {
            description => "No Dispatch Date, Shipping Charge without nominated day => No Dispatch Time",
            setup       => {
                nominated_dispatch_date => undef,
                shipping_charge         => $no_nominated_day_shipping_charge,
            },
            expected => {
                nominated_dispatch_date        => undef,
                nominated_dispatch_time_of_day => undef,
            },
        },
        {
            description => "Dispatch Date, but no Shipping Charge => Die",
            setup       => {
                nominated_dispatch_date => $today_date,
            },
            expected => {
                exception => qr/Nominated Day but no Shipping Charge specified/ms,
            },
        },
        {
            description => "Dispatch Date, but Shipping Charge without nominated day => Bad data, die",
            setup       => {
                nominated_dispatch_date => $today_date,
                shipping_charge         => $no_nominated_day_shipping_charge,
            },
            expected => {
                exception => qr/Bad data for ORDER_NUMBER\(\d+\)\. A Nominated Day is specified with DELIVERY_DATE \($today_date_str\), DISPATCH_DATE \($today_date_str\), but the Shipping SKU \($no_nominated_day_sku\) isn't a Nominated Day sku/,
            },
        },
        {
            description => "Dispatch Date, Shipping Charge with nominated day (morning) => Dispatch Time",
            setup       => {
                nominated_dispatch_date => $today_date,
                shipping_charge         => $morning_nominated_day_shipping_charge,
            },
            expected => {
                nominated_dispatch_date        => $today_date,
                nominated_dispatch_time_of_day => $morning_daytime,
            },
        },
        {
            description => "Dispatch Date, Shipping Charge with nominated day (evening) => Dispatch Time",
            setup       => {
                nominated_dispatch_date => $today_date,
                shipping_charge         => $evening_nominated_day_shipping_charge,
            },
            expected => {
                nominated_dispatch_date        => $today_date,
                nominated_dispatch_time_of_day => $evening_daytime,
            },
        },
        {
            description => "Dispatch Date, Shipping Charge with nominated day (mid-day) => Dispatch Time",
            setup       => {
                nominated_dispatch_date => $today_date,
                shipping_charge         => $midday_nominated_day_shipping_charge,
            },
            expected => {
                nominated_dispatch_date        => $today_date,
                nominated_dispatch_time_of_day => $midday_daytime,
            },
        },
    ];

    for my $case (@$cases) {
        note "\n\n*** $case->{description}";
        my $setup = $case->{setup};
        my $expected = $case->{expected};
        my $order = $self->create_order({
            order_args => {
                nominated_delivery_date => $setup->{nominated_dispatch_date},
                nominated_dispatch_date => $setup->{nominated_dispatch_date},
                tenders                 => [],
                line_items              => [],
                $self->arg_if_exists($setup, "shipping_charge"),
            },
        });

        my $nominated_dispatch_time = eval { $order->nominated_dispatch_time };
        my $err = $@;
        if(my $exception_rex = $expected->{exception}) {
            like($err, $exception_rex, "nominated_dispatch_time died correctly");
            next;
        }
        ok(!$err, "No error thrown") or fail("Died with exception: ($err)");

        if($expected->{nominated_dispatch_date}) {
            is(
                $nominated_dispatch_time->ymd,
                $expected->{nominated_dispatch_date}->ymd,
                "  nominated_dispatch_time is the correct date, the same as dispatch_date",
            );
        }
        else {
            is(
                $nominated_dispatch_time,
                undef,
                "  nominated_dispatch_time is unset correctly",
            );
        }

        if(my $dispatch_time_of_day = $expected->{nominated_dispatch_time_of_day}) {
            is(
                $nominated_dispatch_time->hms,
                $dispatch_time_of_day,
                "  nominated_dispatch_time is the correct time of day",
            );
            is(
                $nominated_dispatch_time->time_zone->name,
                $self->{time_zone},
                "  nominated_dispatch_time has the correct TZ",
            );
        }
    }

}

sub arg_if_exists {
    my ($self, $key_value, $key) = @_;
    exists $key_value->{$key} or return ();
    return( $key => $key_value->{$key} );
}

sub date_plus_daytime {
    my ($self, $date, $daytime) = @_;
    my ($h, $m, $s) = split(/:/, $daytime);
    return $date->clone->set(hour => $h, minute => $m, second => $s);
}

sub nominated_day__earliest_selection_time__no_nominated_day : Tests() {
    my $self = shift;

    my $order = $self->create_order({
        order_args => { tenders => [], line_items => [] },
    });
    is(
        $order->nominated_earliest_selection_time(),
        undef,
        "No Nominated Day - undef nominated_earliest_selection_time",
    );
}

sub nominated_day__earliest_selection_time__nominated_day : Tests() {
    my $self = shift;

    my $days_ago = 3;  # Could be any days earlier than now
    my $times = Test::XTracker::Data::Order->nominated_day_times(
        $days_ago,
        $self->{channel},
    );

    my $order = $self->create_order({
        order_args => {
            nominated_delivery_date => $times->{nominated_delivery_date},
            nominated_dispatch_time => $times->{nominated_dispatch_time},
            tenders                 => [],
            line_items              => [],
        },
    });
    my $nominated_earliest_selection_time = $order->nominated_earliest_selection_time();

    is(
        $nominated_earliest_selection_time->ymd,
        $times->{nominated_dispatch_time}->clone->subtract(days => 1)->ymd,
        "nominated_earliest_selection_time is the correct date, the day before dispatch (" . $times->{nominated_dispatch_time}->ymd . ")",
    );

    # Currently all carriers' last pickup is at 5pm
    my $pickup_time_of_day = "17:00:00";
    is(
        $nominated_earliest_selection_time->hms,
        $pickup_time_of_day,
        "nominated_earliest_selection_time is the correct time of day",
    );
    is(
        $nominated_earliest_selection_time->time_zone->name,
        $self->{time_zone},
        "nominated_earliest_selection_time time_zone is correct",
    );
}

sub test_premier_routing : Tests {
    my $self = shift;

    ok(
        my $no_premier_routing_shipping_charge = $self->search_one(
            ShippingCharge => {
                premier_routing_id => undef,
            },
        ),
        "Got Shipping Charge without premier_routing",
    );
    ok(
        my $premier_routing_shipping_charge = $self->search_one(
            ShippingCharge => {
                premier_routing_id => { '!=' => undef },
            },
        ),
        "Got Shipping Charge with premier_routing",
    );


    my $cases = [
        {
            description => "Shipping Charge with no Premier Routing",
            setup       => {
                shipping_charge => $no_premier_routing_shipping_charge,
            },
            expected => {
                premier_routing    => undef,
                premier_routing_id => undef,
            },
        },
        {
            description => "Shipping Charge with Premier Routing",
            setup       => {
                shipping_charge => $premier_routing_shipping_charge,
            },
            expected => {
                premier_routing    => $premier_routing_shipping_charge->premier_routing,
                premier_routing_id => $premier_routing_shipping_charge->premier_routing->id,
            },
        },
    ];

    for my $case (@$cases) {
        note "*** $case->{description}";
        my $setup = $case->{setup};
        my $expected = $case->{expected};
        my $order = $self->create_order({
            order_args => {
                tenders => [],
                line_items => [],
                $self->arg_if_exists($setup, "shipping_charge"),
            },
        });

        is(
            $order->premier_routing_id,
            $expected->{premier_routing_id},
            "premier_routing_id is the same as imported",
        );
        if($expected->{premier_routing}) {
            is(
                $order->premier_routing->id,
                $expected->{premier_routing}->id,
                "premier_routing is the same as imported",
            );
        }
        else {
            is(
                $order->premier_routing,
                $expected->{premier_routing},
                "premier_routing is undef, as expected",
            );
        }
    }

}

=head2 create_order({:order_args :shipping_charge_args}) : $order_object

Create a default C<XT::Data::Order> object with any given overrides.

=cut

sub create_order {
    my ($self, $args) = @_;
    $args->{order_args} ||= {};
    $args->{shipping_charge_args} ||= {};
    # Create a new default variant if we haven't provided one
    $args->{variants} ||= [(Test::XTracker::Data->grab_products({force_create => 1}))[1][0]{variant}];

    my $zero = XT::Data::Money->new({ currency => "GBP", value => 0 });

    # The website passes shipping charges as line items - provide overrides so
    # we can only override the bits we're interested in
    my $line_item_count = 1;
    my $shipping_charge = XT::Data::Order::LineItem->new(
        id             => $line_item_count,
        description    => 'shipping charge',
        quantity       => 1,
        unit_net_price => $zero,
        tax            => $zero,
        duties         => $zero,
        sku            => $self->default_shipping_charge('domestic')->sku,
        %{$args->{shipping_charge_args}},
    );

    # This is the actual sku we want to order
    my @line_items = map { XT::Data::Order::LineItem->new(
        id             => ++$line_item_count,
        description    => $_->product->product_attribute->name,
        quantity       => 1,
        unit_net_price => $zero,
        tax            => $zero,
        duties         => $zero,
        sku            => $_->sku,
    ) } @{$args->{variants}};

    my $schema = $self->schema;
    my $tender = XT::Data::Order::Tender->new({
        id    => ($schema->resultset('Orders::Tender')->get_column('id')->max||0)+1,
        type  => 'Card Debit',
        rank  => '1',
        value => $zero
    });
    return XT::Data::Order->new({
        billing_address         => XT::Data::Address->new({
            line_1              => "Line 1",
            line_2              => "Line 2",
            line_3              => '',
            town                => "Town city",
            country_code        => "GB",
            county              => q{},
            postcode            => "W12",
        }),
        billing_email           => 'noone@nowhere.com',
        billing_name            => XT::Data::CustomerName->new({
            title               => "title",
            first_name          => "first_name",
            last_name           => "last_name",
        }),
        channel_name            => 'NAP-' . uc config_var(qw/XTracker instance/),
        order_number            => Test::XTracker::Data->_next_order_id,
        order_date              => '2011-01-01',
        customer_name           => XT::Data::CustomerName->new({
            title               => "title",
            first_name          => "first_name",
            last_name           => "last_name",
        }),
        customer_number         => 123,
        customer_ip             => '127.0.0.1',
        placed_by               => 'placed_by',
        used_stored_credit_card => 0,
        delivery_address        => XT::Data::Address->new({
            line_1              => "Line 1",
            line_2              => "Line 2",
            line_3              => '',
            town                => "Town city",
            country_code        => "GB",
            county              => q{},
            postcode            => "W12",
        }),
        delivery_name           => XT::Data::CustomerName->new({
            title               => "title",
            first_name          => "first_name",
            last_name           => "last_name",
        }),
        gross_total             => XT::Data::Money->new({
            currency            => "GBP",
            value               => 123,
        }),
        shipping_net_price      => XT::Data::Money->new({
            currency            => "GBP",
            value               => 234,
        }),
        shipping_tax            => $zero,
        shipping_duties         => $zero,
        gift_message            => undef,
        is_gift_order           => 0,
        sticker                 => undef,
        line_items              => [ $shipping_charge, @line_items ],
        tenders                 => [ $tender ],
        %{$args->{order_args}}
    });
}


=head2 virtual_voucher_only_avoids_ddu_hold

Tests that an order that only has virtual vouchers will not be put on hold

=cut

sub virtual_voucher_only_avoids_ddu_hold : Tests {
    my $self = shift;

    Test::XTracker::Mock::PSP->set_payment_method('default');

    my $zero = XT::Data::Money->new({ currency => "GBP", value => 0 });

    my $tender = XT::Data::Order::Tender->new({
        id      => 101,
        type    => 'Card Debit',
        rank    => '1',
        value   => $zero
    });

    my ($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => 0, virt_vouchers => { how_many => 1, }
    });

    Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id );

    my $line_item = XT::Data::Order::LineItem->new(
        id                  => 10001,
        description         => 'Test voucher code item',
        quantity            => 1,
        unit_net_price      => $zero,
        tax                 => $zero,
        duties              => $zero,
        sku                 => $pids->[0]{sku},
        is_voucher          => 1
    );

    my $order = $self->create_order({
        order_args => { line_items => [ $line_item ], tenders  => [ $tender ], }
    });

    $order->digest();

    $order->_check_ddu_acceptance($order, $APPLICATION_OPERATOR_ID);

    #get the shipment for the order we just created
    my $shipment = $self->schema->resultset('Public::Orders')
        ->find({ order_nr => $order->order_number })
        ->get_standard_class_shipment;
    #shipment should not be on DDU hold
    ok(!$shipment->is_on_ddu_hold, 'Shipment is not DDU on hold');
}

=head2 get_default_shipping_charge('domestic'|'international', channel_id=nap_channel_id) : $shipping_charge_row

Return a shipping charge DBIC row for the given shipping type (domestic or
international) and channel_id.

=cut

sub default_shipping_charge {
    my ( $self, $shipping_type, $channel_id ) = @_;

    croak q{Your first argument must be 'domestic' or 'international'}
        unless ($shipping_type//q{}) =~ m{^(?:domestic|international)$};

    # Seems like this is currently the 'best' way to get a shipping charge :/
    my $channel = $channel_id
        ? $self->schema->resultset('Public::Channel')->find($channel_id)
        : Test::XTracker::Data->channel_for_nap;

    my $shipping_charge_config = Test::XTracker::Data->default_shipping_charge;
    return $channel->find_related(
        'shipping_charges',
        { description => $shipping_charge_config->{$shipping_type}{$channel->web_name} }
    );
}
