package Test::AssertRecords::Plugin::Public::ShippingCharge;
use Moose;
use Test::More 0.98;
use Test::More::Prefix qw/ test_prefix /;
use Data::Dump qw/pp/;


with 'Test::AssertRecords::PluginBase';

has '+map' => (
    default => sub {
        return {
            'sku' => undef,
            'description' => undef,
            'currency' => [qw/currency currency/],
            'flat_rate' => undef,
            'class' => [qw/shipping_charge_class class/],
        };
    },
);


sub test_assert {
    my($self,$schema,$data) = @_;

    my $charge_rs = $schema->resultset('Public::ShippingCharge');

    foreach my $rec (@{$data}) {
        my $sku = $rec->{sku};
        test_prefix("SKU ($sku)");
        note "Shipping charge SKU ($sku)";
        my $charges = $self->find_base_record($charge_rs,$rec);

        is($charges->count, 1, 'found one record') || note pp($rec);
        my $charge = $charges->first;

        if($rec->{latest_nominated_dispatch_daytime}) {
            my $latest_nominated_dispatch_daytime = $charge->latest_nominated_dispatch_daytime;
            if(!$latest_nominated_dispatch_daytime) {
                fail("latest_nominated_dispatch_daytime is undef, but expected ($rec->{latest_nominated_dispatch_daytime})");
                next;
            }
            is(
                join(
                    ":",
                    map { $_ || "00" }
                    $latest_nominated_dispatch_daytime->in_units("hours", "minuts", "seconds"),
                ),
                $rec->{latest_nominated_dispatch_daytime},
                "latest_nominated_dispatch_daytime matches",
            ) || note pp($rec);
        }
        else {
            is(
                $charge->latest_nominated_dispatch_daytime,
                undef,
                "latest_nominated_dispatch_daytime is undef",
            ) || note pp($rec);
        }

        is(
            $charge->premier_routing_id,
            $self->get_premier_routing_id_from_code($schema, $rec->{premier_routing_code}),
            "premier_routing is correct",
        );

        if (exists $rec->{is_enabled}) {
            is(
                $charge->is_enabled,
                $rec->{is_enabled},
                "is_enabled set to $rec->{is_enabled}",
            );

        }

        if (exists $rec->{is_return_shipment_free}) {
            is(
                $charge->is_return_shipment_free,
                $rec->{is_return_shipment_free},
                "is_return_shipment_free set to $rec->{is_return_shipment_free}",
            );
        }
    }
    test_prefix("");
}

sub get_premier_routing_id_from_code {
    my ($self, $schema, $code) = @_;
    $code // return;

    my $premier_routing_rs = $schema->resultset('Public::PremierRouting');
    my $premier_routing = $premier_routing_rs->search({
        code => $code,
    })->first or return;

    return $premier_routing->id;
}

1;
