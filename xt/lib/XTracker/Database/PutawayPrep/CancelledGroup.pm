package XTracker::Database::PutawayPrep::CancelledGroup;

use NAP::policy "tt", qw/class/;

extends 'XTracker::Database::PutawayPrep';

use MooseX::Params::Validate;
use XTracker::Constants::FromDB qw(:stock_process_type);
use XTracker::Database::FlowStatus qw/:stock_process/;

=head1 NAME

XTracker::Database::PutawayPrep::CancelledGroup - Utility class for the Putaway
Prep for Packing exception process based on Cancelled group, part of 'Goods In'.

=head1 DESCRIPTION

Used to putaway stock that comes from Packing exceptions via "Cancelled location".
It uses its own format of group IDs: 'cXXXXX', where XXXXX - is number.

It inherits and behaves in the same way as L<XTracker::Database::PutawayPrep>. Both
modules support same interface. For more information please refer to parent class's POD.

=head2 container_group_field_name

Name of column in C<putaway_prep_group> table that holds ID that current class deals with.

=cut

sub container_group_field_name { 'putaway_prep_cancelled_group_id' }

=head2 name

Name of entity that methods from current class accept as "group_id".

=cut

sub name { 'CGID' }

=head2 extract_group_number

Convert group's ID into form suitable to use for database queries. Basically it
just removes prefix that set indicates that value is "cancelled group".

=cut

sub extract_group_number {
    my ($class, $group_id) = @_;

    $group_id =~ s/^c\-?//;

    return $group_id;
}

=head2 get_canonical_group_id

Present passed ID as canonical "Cancelled group ID".

=cut

sub get_canonical_group_id {
    my ($class, $group_id) = @_;

    return "c$group_id";
}

=head2 is_group_id_valid($cancelled_group_id):boolean

Class method that checks if passed string is valid Cancelled group ID from format point of view.

=cut

sub is_group_id_valid {
    my ($class, $group_id) = @_;

    # case when undefined ID was passed
    $group_id //= '';

    return !! $group_id =~ /^(c\-?)?\d+$/i;
}

=head2 is_group_id_suitable: Bool

Supposed to check if provided container is suitable for Cancelled group.
But because Cancelled groups are fake ones and do not content anything
until some stock was putaway prep via them, there is no need to have
implementation for is_group_id_suitable method.

This method stays here just to support interface of XTracker::Database::PutawayPrep::*.

=cut

sub is_group_id_suitable {
    return 1;
}

=head2 does_sku_belong_to_group_id(:$sku [, :$group_id]): Bool

Check if provided SKU could be associated with provided Cancelled group ID.

Actually for Cancelled groups do not contain any stock and are just
a substitutions for PGIDs and recode groups. So instead of checking entry
of the SKU into Cancelled group we need to check that this SKU comes
from "Cancelled location".

Actually "group_id" parameter exists only for supporting interface of the same
method provided by XTracker::Database::PutawayPrep::*, and is not used.

=cut

sub does_sku_belong_to_group_id {
    my ($self, $group_id, $sku) = validated_list(
        \@_,
        group_id=> { isa => 'Str', optional => 1 },
        sku     => { isa => 'Str' },
    );

    my $variant =
        $self->schema->resultset('Public::Variant')->find_by_sku($sku);

    my $cancelled_location_row =
        $self->schema->resultset('Public::Location')
            ->get_cancelled_location;

    return $cancelled_location_row->does_include_variants([ $variant ]);
}

=head2 get_stock_type_name_from_group_id

Always return "MAIN", that is so by requirements.

=cut

sub get_stock_type_name_from_group_id {
    my $self = shift;

    # recode always have stock of "MAIN" stock type
    return $self->schema
        ->resultset('Public::StockProcessType')
        ->find($STOCK_PROCESS_TYPE__MAIN)->type;
}

=head2 generate_new_group_id: $new_cancelled_group_id

Produces entirely new ID of Cancelled group.

=cut

sub generate_new_group_id {
    my $class = shift;

    return $class->schema->storage->dbh
        ->selectrow_arrayref(
            q{select nextval('putaway_prep_group__putaway_prep_cancelled_group_id_seq')}
        )->[0];
}

=head2 get_stock_status_row: $flow_status_row

For provided PGID return Flow status row object that represents
stock status.

=cut

sub get_stock_status_row {
    my $self = shift;

    # recode is always MAIN
    return $self->schema->resultset('Flow::Status')
        ->find( flow_status_from_stock_process_type( $STOCK_PROCESS_TYPE__MAIN ) );
}
