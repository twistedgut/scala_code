package Test::NAP::Carrier;
use NAP::policy "tt", 'class';
use Module::Runtime 'require_module';
extends 'NAP::Carrier';

=head1

 Test::NAP::Carrier - Library which extends NAP::Carrier

This is used to call the correct test library object when a NAP::Carrier object is
instatiated, by deciding what the Carrier is and calling the appropriate test library,
currently Test::NAP::Carrier::UPS is the only one supported.

=cut

# after NAP::Carrier's BUILD will need to point
# to the correct Carrier's Test Object
# Currently only 'Test::NAP::Carrier::UPS' exists
# any others will crash;
after 'BUILD' => sub {
    my $self    = shift;

    # call _derive_carrier_class which is what
    # the normal BUILD func would do if it wasn't
    # being called from this Test Library
    my $subclass    = $self->_derive_carrier_class();
    my $newclass    = ref($self).'::'.$subclass;
    try {require_module $newclass}
    catch {
        die "Can't USE: ".$newclass.", probably hasn't been written?\n$_";
    };
    # bless the new object and call it's BUILD function
    my $new_object  = bless $self, $newclass;
    return $new_object->BUILD(@_);
};
