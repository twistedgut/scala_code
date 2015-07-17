package Test::XT::Data::MarketingCustomerSegment;

use NAP::policy "tt",     qw( role test );
requires 'schema';

has name   => (
    is          => 'rw',
    isa         => 'Str',
    default     => "Test Segment - " . $$,
);

has operator    => (
    is      => 'rw',
    lazy    => 1,
    builder => '_set_operator',
);

has enabled => (
    is      => 'rw',
    isa    => 'Bool',
    lazy    => 1,
    default => 1,
);

has job_queue_flag => (
    is => 'rw',
    isa => 'Bool',
);

has date_of_last_jq => (
    is => 'rw',
    isa => 'DateTime',
);

has customer_segment => (
    is => 'ro',
    lazy  => 1,
    builder => '_set_segment',
);


# Get a Marketing Customer Segment
sub _set_segment{
    my $self    = shift;

    my $segment    = $self->schema
                            ->resultset('Public::MarketingCustomerSegment')
                                ->create( {
                                        name            => $self->name,
                                        channel_id      => $self->channel->id,
                                        operator_id     => $self->operator->id,
                                        enabled         => $self->enabled,
                                        job_queue_flag  => $self->job_queue_flag,
                                        date_of_last_jq => $self->date_of_last_jq,
                                    });

    return $segment->discard_changes;
}

# gets the operator for the Reservation
sub _set_operator {
    my $self    = shift;

    return $self->schema->resultset('Public::Operator')
                    ->search( { username => 'it.god' } )
                        ->first;
}

1;
