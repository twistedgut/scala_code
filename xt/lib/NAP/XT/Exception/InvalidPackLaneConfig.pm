package NAP::XT::Exception::InvalidPackLaneConfig;
use NAP::policy "tt", 'exception';

=head1 NAME

NAP::XT::Exception::InvalidPackLaneConfig

=head1 DESCRIPTION

Exception thrown if an attempt is made to edit pack lane properties to a combination that is invalid (e.g. no premier pack lanes)

=head1 ATTRIBUTES

=head2 has_no_single_tote_standard

Set to 1 if the problem is that there are no standard single-tote packlanes (must be at least one)

=cut

has 'has_no_single_tote_standard' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

=head2 has_no_multi_tote_standard

Set to 1 if the problem is that there are no standard multi-tote packlanes (must be at least one)

=cut
has 'has_no_multi_tote_standard' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

=head2 has_no_single_tote_premier

Set to 1 if the problem is that there are no premier single-tote packlanes (must be at least one)

=cut
has 'has_no_single_tote_premier' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

=head2 has_no_multi_tote_premier

Set to 1 if the problem is that there are no premier multi-tote packlanes (must be at least one)

=cut
has 'has_no_multi_tote_premier' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

=head2 has_no_single_tote_sample

Set to 1 if the problem is that there is no pack lane assigned for sample single-tote packlanes (must be at least one)

=cut
has 'has_no_single_tote_sample' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

=head2 has_no_multi_tote_sample

Set to 1 if the problem is that there is no pack lane assigned for sample multi-tote packlanes (must be at least one)

=cut
has 'has_no_multi_tote_sample' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

=head2 has_active_unassigned

Set to 1 if the a lane is active, but not configured to accept any standard, premier or sample shipments.
(Flag a user error/confusion.. why activate a lane and not assign it a target)

=cut

has 'has_active_unassigned' => (
    is => 'ro',
    isa => 'Bool',
    default => '0'
);


has '+message' => (
    default => 'That would result in an invalid pack lane configuration',
);

1;
