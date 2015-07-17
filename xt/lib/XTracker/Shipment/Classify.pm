package XTracker::Shipment::Classify;
use NAP::policy "class";
use XTracker::Constants::FromDB ':shipment_class';
use Const::Fast;

=head1 NAME

XTracker::Shipment::Classify - Classify shipments

=head1 DESCRIPTION

See if a shipment is customer/sample/rtv

=cut

const my $_class_type_map => {
    $SHIPMENT_CLASS__STANDARD => 'customer',
    $SHIPMENT_CLASS__RE_DASH_SHIPMENT => 'customer',
    $SHIPMENT_CLASS__EXCHANGE => 'customer',
    $SHIPMENT_CLASS__REPLACEMENT => 'customer',
    $SHIPMENT_CLASS__SAMPLE => 'sample',
    $SHIPMENT_CLASS__PRESS => 'sample',
    $SHIPMENT_CLASS__TRANSFER_SHIPMENT => 'sample',
    $SHIPMENT_CLASS__RTV_SHIPMENT => 'rtv',
};

sub _is_type_match {
    my ($self, $id, $type) = @_;
    return ($_class_type_map->{ $id } eq $type);
}

=head1 METHODS

=head2 is_sample ($shipment_class_id) : Bool

Determine if this shipment a sample shipment

=cut

sub is_sample {
    my ($self, $id) = @_;
    $self->_is_type_match($id, 'sample');
}

=head2 is_customer ($shipment_class_id) : Bool

Is the shipment for a customer

=cut

sub is_customer {
    my ($self, $id) = @_;
    $self->_is_type_match($id, 'customer');
}

=head2 is_rtv ($shipment_class_id) : Bool

Is the shipment a return-to-vendor one

=cut

sub is_rtv {
    my ($self, $id) = @_;
    $self->_is_type_match($id, 'rtv');
}

=head2 type ($shipment_class_id) : Str

Return the shipment type as a string

=cut

sub type {
    my ($self, $id) = @_;
    return $_class_type_map->{ $id };
}

=head2 get_sample_classes () : Array['Int']

Return an array of shipment_class_ids that
corrolate to sample shipments

=cut

sub get_sample_classes {
    my $self = shift;
    return [ grep { $self->is_sample($_) } keys %{ $_class_type_map } ];
}


