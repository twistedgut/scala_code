package XTracker::Schema::ResultSet::Public::RuntimeProperty;
use NAP::policy "tt";
use parent "DBIx::Class::ResultSet";

use Carp;
use XTracker::Config::Local 'config_var';

=head2 find_by_name($property_name) : $runtime_property_row

Find the PublicProperty with $property_name or return undef.

=cut

sub find_by_name {
    my ($self, $property_name) = @_;
    return $self->find({ name => $property_name });
}

=head2 pick_scheduler_properties : $properties

Return arrayref of the property rows relevant to pick scheduler.

=cut

sub pick_scheduler_properties {
    my $self = shift;

    my $properties_list = config_var('PickSchedulerRuntimeProperties', 'property');

    return [] unless $properties_list;

    my @properties = $self->search({
        name => { -in => $properties_list },
    },{
        order_by => ['sort_order', 'id'],
    })->all;

    return \@properties;
}

=head2 set_property($property_name, $value) : | die

Set the runtime property $property_name to $value, or die if it can't
be found.

=cut

sub set_property {
    my ($self, $property_name, $value) = @_;
    my $property_row = $self->find_by_name($property_name)
        or confess("Could not find runtime_property ($property_name) for update to ($value)");
    $property_row->update({ value => $value });
}
