package XTracker::Schema::ResultSet::SOS::WmsPriority;
use NAP::policy 'tt';
use base 'DBIx::Class::ResultSet';
use MooseX::Params::Validate;

=head1 NAME

XTracker::Schema::ResultSet::SOS::WmsPriority

=head1 DESCRIPTION

Defines specialised methods for the WmsPriority resultset

=head1 PUBLIC METHODS

=head2 find_wms_priority

Find the wms_priority settings that should be used given data about a shipment

 param - shipment_class : A Result::ShipmentClass object
 param - country : (Optional) A Result::Country object
 param - region : (Optional) A Result::Region object
 param - attribute_list : (Optional) A list of Result:ShipmentClass attribute objects

 return - $WmsPriority : A WmsPriority object that matches the given settings

=cut
sub find_wms_priority {
    my ($self, $shipment_class, $country, $region, $attribute_list) = validated_list(\@_,
        shipment_class => { isa => 'XTracker::Schema::Result::SOS::ShipmentClass' },
        country => { isa => 'XTracker::Schema::Result::SOS::Country' },
        region => { isa => 'XTracker::Schema::Result::SOS::Region', optional => 1 },
        attribute_list => {
            isa => 'ArrayRef[XTracker::Schema::Result::SOS::ShipmentClassAttribute]',
            default => [],
        },
    );

    return $self->search({ -or => [
        shipment_class_id   => $shipment_class->id(),
        country_id => $country->id(),
        ( $region ? ( region_id => $region->id() ) : () ),
        ( @$attribute_list
            ? ( shipment_class_attribute_id => [map { $_->id } @$attribute_list] )
            : ()
        ),
    ]}, {
        order_by    => ['wms_priority', 'wms_bumped_priority', 'bumped_interval', 'id'],
        rows        => 1,
    })->first();
}
