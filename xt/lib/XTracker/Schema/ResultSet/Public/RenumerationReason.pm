package XTracker::Schema::ResultSet::Public::RenumerationReason;
# vim: ts=8 sts=4 et sw=4 sr sta

=head1 NAME

XTracker::Schema::ResultSet::Public::RenumerationReason

=cut

use NAP::policy;
use base 'DBIx::Class::ResultSet';

use Moose;
with 'XTracker::Schema::Role::ResultSet::Orderable' => {
    order_by => {
        reason  => 'reason',
     }
};

use XTracker::Constants::FromDB     qw( :renumeration_reason_type );

=head1 METHODS

=head2 get_reasons_for_type

    $result_set = $self->get_reasons_for_type( $RENUMERATION_REASON_TYPE__? );
            or
    $result_set = $self->get_reasons_for_type( $RENUMERATION_REASON_TYPE__?, $dbic_department_obj );
            or
    $result_set = $self->get_reasons_for_type( $RENUMERATION_REASON_TYPE__?, $department_id );

Returns a Result Set of Reasons for the Renumeration Reason Type Id.

A Department can be optionally passed in to get All Reasons assigned to a Department, this can be
either a DBIC Department Object or the Department's Id. When a Department is passed Reasons
which have a Department assigned to them will be returned along with any Reasons with NO
Department assigned as these can be seen by ALL Departments.

=cut

sub get_reasons_for_type {
    my ( $self, $type_id, $department ) = @_;

    croak "No Renumeration Reason Type Id was passed to '" . __PACKAGE__ . "::get_reasons_for_type'"
                if ( !$type_id );

    my $department_id   = ( ref( $department ) ? $department->id : $department );

    return $self->search(
        {
            renumeration_reason_type_id => $type_id,
            department_id               => ( $department_id ? [ undef, $department_id ] : undef ),
        }
    );
}

=head2 get_compensation_reasons

    $result_set = $self->get_compensation_reasons;
            or
    $result_set = $self->get_compensation_reasons( $dbic_department_obj );
            or
    $result_set = $self->get_compensation_reasons( $department_id );

Returns a Result Set for 'Compensation' Renumeration Reasons.

A Department can be passed in the same way as for the 'get_reasons_for_type' method.

=cut

sub get_compensation_reasons {
    my ( $self, $department )   = @_;

    return $self->get_reasons_for_type(
        $RENUMERATION_REASON_TYPE__COMPENSATION,
        $department
    );
}

=head2 enabled_only

Filter a ResultSet so it only includes rows where the C<enabled> column is
TRUE.

    my @enabled_reasons = $schema->resultset('Public::RenumerationReason')
        ->enabled_only
        ->all;

=cut

sub enabled_only {
    my $self = shift;

    return $self->search({
        enabled => 1,
    });

}

1;
