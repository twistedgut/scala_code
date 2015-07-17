package XTracker::Schema::ResultSet::SOS::ProcessingTime;
use NAP::policy qw/class tt/;
use MooseX::NonMoose;
extends 'DBIx::Class::ResultSet';

use MooseX::Params::Validate;
use DateTime::Duration;

has 'override_rs' => (
    is      => 'rw',
    default => sub {
        my ($self) = @_;
        return $self->result_source->schema->resultset('SOS::ProcessingTimeOverride');
    },
);

=head1 NAME

XTracker::Schema::ResultSet::SOS::ProcessingTime

=head1 PUBLIC METHODS

=head2 use_first_truck

Return true if the current processing_times indicate that a shipment should go on the
 first available truck (instead of the last one of the day)

=cut
sub use_first_truck {
    my ($self) = @_;

    # Do we go for the first truck available?

    my @rows = $self->all;

    # Shipments to 'special' destinations do...
    return 1 if grep { $_->is_country } @rows;
    # So do nominated-day...
    return 1 if grep { $_->is_nominated_day } @rows;
    # and Premier...
    return 1 if grep { $_->is_premier } @rows;

    # Everything else does not
    return 0;
}

=head2 filter_by_properties

Filter the resultset to contain only rows relating to relevant properties

=cut
sub filter_by_properties {
    my ($self, $shipment_class, $country, $region, $channel, $shipment_attributes) = validated_list(\@_,
        shipment_class              => { isa => 'XTracker::Schema::Result::SOS::ShipmentClass' },
        country                     => { isa => 'XTracker::Schema::Result::SOS::Country', optional => 1 },
        region                      => { isa => 'XTracker::Schema::Result::SOS::Region', optional => 1 },
        channel                     => { isa => 'XTracker::Schema::Result::SOS::Channel' },
        shipment_class_attributes   => { isa => 'ArrayRef[XTracker::Schema::Result::SOS::ShipmentClassAttribute]', default => [] },
    );

    my $search_parameters;

    if ($shipment_class->does_ignore_other_processing_times()) {
        $search_parameters = {
            class_id => $shipment_class->id(),
        };
    } else {
        my @attribute_ids = map { $_->id() } @$shipment_attributes;
        $search_parameters = {
            -or => [
                class_id            => $shipment_class->id(),
                channel_id          => $channel->id(),
                ( @attribute_ids ? ( class_attribute_id => \@attribute_ids ) : () ),
                ( $country ? ( country_id => $country->id() ) : () ),
                ( $region ? ( region_id => $region->id() ) : () ),
            ]
        }
    }

    my $processing_times_rs = $self->search_rs($search_parameters);

    # Ensure if we have a restricted override resultset that it gets passed on
    $processing_times_rs->override_rs($self->override_rs());

    # Apply processing time overrides
    return $processing_times_rs->_apply_overrides();
}

sub _apply_overrides {
    my ($self) = @_;

    # Fetch only the overrides that apply to these processing times
    my $override_rs = $self->override_rs->search({
        major_id => { -in => $self->get_column('id')->as_query() }
    });

    # Override any 'minor' processing times by filtering them out
    return $self->search({
        id => { -not_in => $override_rs->get_column('minor_id')->as_query() }
    });
}

=head2 processing_time_duration

Returns A Datetime::Duration object representing the total processing time for this
 resultset

=cut
sub processing_time_duration {
    my ($self) = @_;

    my $total_duration = DateTime::Duration->new( minutes => 0 );

    # Sum all the durations (some may be negative, and will be subtracted)
    my $iterator = $self->search();
    while (my $processing_time = $iterator->next()) {
        $total_duration->add_duration($processing_time->processing_time());
    }

    return $total_duration;
}

1;
