
package Test::XTracker::Schema::Result::Shipping::DeliveryDateRestriction;
use FindBin::libs;
use parent "NAP::Test::Class";
use NAP::policy "tt", 'test';

use XTracker::Schema::Result::Shipping::DeliveryDateRestriction;

sub restriction_rs      { return shift->rs("Shipping::DeliveryDateRestriction") }
sub shipping_charge_rs  { return shift->rs("ShippingCharge") }

sub composite_shipping_charge_ids : Tests() {
    my $self = shift;

    my $restriction_row = $self->restriction_rs->new({});
    ok($restriction_row, "Got row");

    note "* Setup";
    my @descriptions = ("Premier Daytime", "Premier Evening");
    my @shipping_charges = $self->shipping_charge_rs->search({
        description => $_,
    })->all;
    SKIP: {
        skip "No nom-day shipping charges found", 1 unless @shipping_charges;
        my %description_composite_id = map {
            $_ => join( "-", sort map { $_->id } @shipping_charges )
        } @descriptions;
        my $expected_composite_ids = [ sort values %description_composite_id ];

        note "* Run";
        my @shipping_charge_ids =
            map { $_->id }
            $self->shipping_charge_rs->search({
                description => { -in => \@descriptions },
            })->all;
        my $composite_ids
            = $restriction_row->composite_shipping_charge_ids(\@shipping_charge_ids);

        note "* Test";

        eq_or_diff(
            $composite_ids,
            $expected_composite_ids,
            "Composite ids as expected",
        );
    }
}

1;
