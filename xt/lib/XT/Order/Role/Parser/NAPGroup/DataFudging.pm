package XT::Order::Role::Parser::NAPGroup::DataFudging;
use NAP::policy "tt", 'role';

# in an ideal world we will have 'state' removed from the incoming data, and
# it'll either all go into 'county', or state/county/province will all be
# replaced by one coverall name (region? postalregion?)
sub _fudge_address {
    my ($self, $address) = @_;

    if (
        exists $address->{state}
           and $address->{state} ne q{}
    ) {
        # nuke county with value of state
        $address->{county} =
            delete $address->{state};
    }

    return;
}
