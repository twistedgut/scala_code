package Test::XT::Data::FraudChangeLog;

use NAP::policy "tt",     qw( test role );

requires qw(
            schema
        );

=head1 NAME

Test::XT::Data::FraudChangeLog

=head1 SYNOPSIS

Used for creating a Change Log for Live Fraud Rules

=head2 USAGE

    use Test::XT::Flow;
            or
    use Test::XT::Data;

    my $framework = Test::XT::(Data|Flow)->new_with_traits(
        traits => [
            'Test::XT::Data::FraudChangeLog',
        ],
    );

    # Returns a Fraud Rule
    my $change_log  = $framework->change_log;

=cut

use Test::XTracker::Data;


=head2 MOOSE ATTRIBUTES

The following can be overridden with an object(s) of your own choosing before the Fraud Rule is created.

    $framework->operator( 'A Public::Operator object' );

=cut

=head2 fraud_change_log

When called will generate a Change Log, this can be replaced with your own Change Log
when using in conjunction with 'Text::XT::Data::FraudRule'.

=cut

has fraud_change_log => (
    is      => 'rw',
    lazy    => 1,
    builder => '_set_fraud_change_log',
);

=head2 operator

The Operator assigned to the Change Log.

=cut

has operator => (
    is      => 'rw',
    lazy    => 1,
    builder => '_set_operator',
);


# Create a Change Log
sub _set_fraud_change_log {
    my $self    = shift;

    my $rs      = $self->schema->resultset('Fraud::ChangeLog');
    my $max_id  = $rs->get_column('id')->max // 0;
    $max_id++;

    my $change_log  = $self->schema->resultset('Fraud::ChangeLog')
                                    ->create( {
        description => "Test Change Log Description - " . $max_id,
        operator_id => $self->operator->id,
    } );

    note "Created a Fraud Change Log: (" . $change_log->id . ") " . $change_log->description;

    return $change_log->discard_changes;
}

# gets the operator for the Rule
sub _set_operator {
    my $self    = shift;

    return $self->schema->resultset('Public::Operator')
                    ->search( { username => 'it.god' } )
                        ->first;
}

1;
