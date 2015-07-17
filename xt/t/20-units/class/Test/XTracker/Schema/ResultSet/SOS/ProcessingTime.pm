package Test::XTracker::Schema::ResultSet::SOS::ProcessingTime;
use NAP::policy qw/tt class test/;
use Test::XTracker::LoadTestConfig;
use Test::MockObject::Builder;
use DateTime::Duration;

=head1 DESCRIPTION

Unit tests for XTracker::Schema::ResultSet::SOS::ProcessingTime

=cut

BEGIN {
    extends 'NAP::Test::Class';

    use Test::SOS::Data;
    has 'data_helper' => (
        is      => 'ro',
        default => sub {
            return Test::SOS::Data->new();
        },
    );

};

sub test__filter_by_properties :Tests {
    my ($self) = @_;

    for my $test (
        {
            name    => 'Class and Channel only with no overrides',
            setup   => {
                processing_times => [
                    { class     => 'Cheap',     processing_time => { hours => 2 } },
                    { class     => 'Expensive', processing_time => { hours => 3 } },
                    { channel   => 'MnS',       processing_time => { hours => 4 } },
                    { channel   => 'HoF',       processing_time => { hours => 10 } },
                ],
                filter_params   => {
                    shipment_class  => 'Cheap',
                    channel         => 'MnS',
                },
            },
            expected  => {
                # This is the total of the processing times for the 'Cheap' shipment class
                # and the 'MnS' channel as both are specified in the filter_params and
                # we have no overrides
                processing_time_duration_hours => 6,
            },
        },
        {
            name    => 'Class and Channel only with override',
            setup   => {
                processing_times => [
                    { class     => 'Cheap',     processing_time => { hours => 2 } },
                    { class     => 'Expensive', processing_time => { hours => 3 } },
                    { channel   => 'MnS',       processing_time => { hours => 4 } },
                    { channel   => 'HoF',       processing_time => { hours => 10 } },
                ],
                overrides   => [
                    { major => { class => 'Cheap' }, minor => { channel => 'MnS' } },
                ],
                filter_params   => {
                    shipment_class  => 'Cheap',
                    channel         => 'MnS',
                },
            },
            expected  => {
                # This is just the processing time for the 'Cheap' shipment class, as
                # even though the 'MnS' channel is included, it is overridden by the
                # class
                processing_time_duration_hours => 2,
            },
        },

        {
            name    => 'Class and Channel with country and attributes. No overrides',
            setup   => {
                processing_times => [
                    { class     => 'Cheap',     processing_time => { hours => 2 } },
                    { class     => 'Expensive', processing_time => { hours => 3 } },
                    { channel   => 'MnS',       processing_time => { hours => 6 } },
                    { channel   => 'HoF',       processing_time => { hours => 10 } },
                    { country   => 'UK',        processing_time => { hours => 1 } },
                    { country   => 'Scotland',  processing_time => { hours => 2 } },
                    { attribute => 'ForToddy',  processing_time => { hours => -7 } },
                ],
                filter_params   => {
                    shipment_class  => 'Cheap',
                    channel         => 'MnS',
                    country         => 'Scotland',
                    attribute       => 'ForToddy',
                },
            },
            expected  => {
                # This is the total of the processing times, which includes a big -7
                # for the attribute, leaving at the low value
                processing_time_duration_hours => 3,
            },
        },

        {
            name    => 'Class and Channel with country and attributes. With override',
            setup   => {
                processing_times => [
                    { class     => 'Cheap',     processing_time => { hours => 2 } },
                    { class     => 'Expensive', processing_time => { hours => 3 } },
                    { channel   => 'MnS',       processing_time => { hours => 6 } },
                    { channel   => 'HoF',       processing_time => { hours => 10 } },
                    { country   => 'UK',        processing_time => { hours => 1 } },
                    { country   => 'Scotland',  processing_time => { hours => 2 } },
                    { attribute => 'ForToddy',  processing_time => { hours => -9 } },
                ],
                filter_params   => {
                    shipment_class  => 'Cheap',
                    channel         => 'MnS',
                    country         => 'Scotland',
                    attribute       => 'ForToddy',
                },
                overrides   => [
                    { major => { attribute => 'ForToddy' }, minor => { country => 'Scotland' } },
                ],
            },
            expected  => {
                # This is the total of the processing times, which includes a big -7
                # for the attribute, leaving at the low value. The country override leaves
                # us with an even lower result than above!
                processing_time_duration_hours => 1,
            },
        },
    ) {
        subtest $test->{name } => sub {
            my ($processing_time_rs, $filter_params) = $self->_create_test_data($test);

            $processing_time_rs = $processing_time_rs->filter_by_properties($filter_params);

            is($processing_time_rs->processing_time_duration->hours(),
                $test->{expected}->{processing_time_duration_hours},
                'Processing time is as expected');
        };
    }
}

sub _create_test_data {
    my ($self, $test) = @_;

    my @processing_time_ids;
    my @override_ids;

    for my $processing_time_def (@{$test->{setup}->{processing_times}}) {
        push @processing_time_ids, $self->data_helper->find_or_update_processing_time({
            ( $processing_time_def->{class} ? ( class => $processing_time_def->{class} ) : () ),
            ( $processing_time_def->{channel} ? ( channel => $processing_time_def->{channel} ) : () ),
            ( $processing_time_def->{country} ? ( country => $processing_time_def->{country} ) : () ),
            ( $processing_time_def->{attribute} ? ( attribute => $processing_time_def->{attribute} ) : () ),
            processing_time => DateTime::Duration->new($processing_time_def->{processing_time}),
        })->id();
    }

    for my $override_def (@{$test->{setup}->{overrides}}) {
        push @override_ids, $self->data_helper->find_or_update_override({
            major => $override_def->{major},
            minor => $override_def->{minor}
        })->id();
    }

    my $processing_time_rs = $self->schema->resultset('SOS::ProcessingTime')->search({
        id => \@processing_time_ids,
    });

    my $filter_params = {
        ($test->{setup}->{filter_params}->{shipment_class}
            ? (shipment_class => $self->data_helper->find_or_create_shipment_class(name => $test->{setup}->{filter_params}->{shipment_class}))
            : ()
        ),
        ($test->{setup}->{filter_params}->{channel}
            ? (channel => $self->data_helper->find_or_create_channel(name => $test->{setup}->{filter_params}->{channel}))
            : ()
        ),
        ($test->{setup}->{filter_params}->{country}
            ? (country => $self->data_helper->find_or_create_country(name => $test->{setup}->{filter_params}->{country}))
            : ()
        ),
        ($test->{setup}->{filter_params}->{attribute}
            ? (shipment_class_attributes => [$self->data_helper->find_or_create_shipment_class_attribute(name => $test->{setup}->{filter_params}->{attribute})])
            : ()
        ),
    };

    my $override_rs;
    if (@override_ids) {
        $override_rs = $self->schema->resultset('SOS::ProcessingTimeOverride')->search({
            'me.id' => \@override_ids,
        });
    } else {
        # Make sure we get an empty resultset (no id should ever be 0)
        $override_rs = $self->schema->resultset('SOS::ProcessingTimeOverride')->search({
            'me.id' => 0,
        });
    }

    $processing_time_rs->override_rs($override_rs);

    return ($processing_time_rs, $filter_params);
}
