
package Test::Role::NominatedDay::WithRestrictedDates;
use NAP::policy "tt", ("test", "role");

requires "rs";
requires "schema";

use XTracker::Constants qw( :application );
use XT::Data::NominatedDay::RestrictedDate;

use Test::XTracker::Data;

sub restriction_rs      { return shift->rs("Shipping::DeliveryDateRestriction") }
sub restriction_log_rs  { return shift->rs("Shipping::DeliveryDateRestrictionLog") }
sub restriction_type_rs { return shift->rs("Shipping::DeliveryDateRestrictionType") }
sub shipping_charge_rs  { return shift->rs("ShippingCharge") }

sub operator_id { $APPLICATION_OPERATOR_ID } # Application user

sub operator {
    my $self = shift;
    $self->schema->find(Operator => $self->operator_id);
}

sub restricted_date {
    my ($self, $args) = @_;

    my $type = "delivery";
    # Any Shipping Charge will do for most tests, but let's default to
    # a predictable channel
    my $shipping_charge_id = $self->rs("ShippingCharge")->search({
        channel_id => Test::XTracker::Data->channel_for_nap->id,
        # Exclude empty skus, as it can cause issues with some tests, specifically
        # t/20-units/class/Test/XTracker/Schema/Result/Shipping/DeliveryDateRestrictionLog.pm
        sku => { '!=' => '' },
    })->first->id;
    XT::Data::NominatedDay::RestrictedDate->new({
        restriction_type   => $type,
        shipping_charge_id => $shipping_charge_id,
        %$args,
    });
}

sub delete_all_restrictions {
    my $self = shift;
    $self->restriction_log_rs->delete();
    $self->restriction_rs->delete();
}

sub with_emptied_restriction {
    my ($self, $sub_ref) = @_;

    $self->schema->txn_dont( sub {
        $self->delete_all_restrictions();
        $sub_ref->();
    });
}
