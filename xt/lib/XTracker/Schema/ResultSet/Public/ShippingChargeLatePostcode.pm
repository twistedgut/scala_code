package XTracker::Schema::ResultSet::Public::ShippingChargeLatePostcode;
use NAP::policy 'class';
extends 'XTracker::Schema::ResultSetBase';

use MooseX::Params::Validate;
use XTracker::Postcode::Analyser;


=head1 filter_by_address

Filter this resultset to only the late_postcodes that are relevant to a given address

=cut
sub filter_by_address {
    my ($self, $address) = validated_list(\@_,
        address => { isa => 'XTracker::Schema::Result::Public::OrderAddress' },
    );

    # See if we know what the format for this countries postcodes are...
    my $postcode = $address->postcode();
    my $postcode_matcher;
    $postcode_matcher = XTracker::Postcode::Analyser->extract_postcode_matcher({
        country     => $address->country_table(),
        postcode    => $postcode
    }) if $postcode;

    if(!$postcode_matcher){
        # We have no valid postcode matcher, so we'll do the check with undef/NULL. The
        # postcode field is required, so this should always return an empty resultset,
        # which is correct.
    }

    return $self->search({
        country_id  => $address->country_table->id(),
        postcode    => $postcode_matcher,
    });
}

=head1 filter_by_address

Filter this resultset to only the late_postcodes that are relevant to a given shipping-charge

=cut
sub filter_by_shipping_charge {
    my ($self, $shipping_charge) = validated_list(\@_,
        shipping_charge => { isa => 'XTracker::Schema::Result::Public::ShippingCharge' },
    );

    return $self->search({
        shipping_charge_id => $shipping_charge->id(),
    });
}

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
