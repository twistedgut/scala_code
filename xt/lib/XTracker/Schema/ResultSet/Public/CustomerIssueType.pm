package XTracker::Schema::ResultSet::Public::CustomerIssueType;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

=head1 NAME

XTracker::Schema::ResultSet::Public::CustomerIssueType

=cut

use XTracker::Constants::FromDB qw/
    :customer_issue_type
    :customer_issue_type_group
/;

use Moose;

with 'XTracker::Schema::Role::ResultSet::HTMLSelect' => {
    group_label_column          => 'description',
    group_visible_column        => 'description_visible',
    group_sequence_column       => 'display_sequence',
    group_options_relationship  => 'customer_issue_types',
    relationship                => 'category',
    sequence_column             => 'display_sequence',
    enabled_column              => 'enabled',
    value_column                => 'id',
    display_column              => 'description',
};

=head1 METHODS

=head2 return_reason_from_pws_code

    $record = $self->return_reason_from_pws_code( $pws_reason );

Returns the Customer Issue Type record whose 'pws_reason' field matches the PWS Reason supplied.

=cut

sub return_reason_from_pws_code {
    my ($self, $code) = @_;

    return $self->return_reasons->search({
      pws_reason => $code,
      # 'Dispatch/Return' is being excluded because it is an internal
      # return reason for xTracker but appears on the Customer's account
      # as a 'Delivery Issue', excluding Dispatch/Return prevents a bug
      # where tax is NOT given back to the customer.
      # Excuding 'Item Returned - No RMA' because this is an internal reason
      # and has the PWS Reason 'UNWANTED' which clashes with another issue.
      id => { -not_in => [ $CUSTOMER_ISSUE_TYPE__7__DISPATCH_FSLASH_RETURN, $CUSTOMER_ISSUE_TYPE__7__ITEM_RETURNED__DASH__NO_RMA ] },
    })->first;
}

=head2 return_reasons

    $result_set = $self->return_reasons();

Returns all of the Customer Issue Types for the 'Return Reasons' Group

=cut

sub return_reasons {
    my $self = shift;

    return $self->search({
        group_id => $CUSTOMER_ISSUE_TYPE_GROUP__RETURN_REASONS
    });

}

=head2 cancellation_reasons

    $result_set = $self->cancellation_reasons();

Returns all of the Customer Issue Types for the 'Cancellation Reasons' Group

=cut

sub cancellation_reasons {
    my $self = shift;

    return $self->search({
        group_id => $CUSTOMER_ISSUE_TYPE_GROUP__CANCELLATION_REASONS
    });

}

=head2 return_reasons_for_rma_pages

    $hash_ref   = $self->return_reasons_for_rma_pages();

This returns a HASH Ref of Return reasons for use on the RMA pages. It excludes the
'Dispatch/Return' reason which is internal.

=cut

sub return_reasons_for_rma_pages {
    my $self    = shift;

    my %hash;

    %hash   = map { $_->id => $_->description }
                            $self->return_reasons
                                    ->search( {
                                                id => {
                                                        -not_in => [
                                                                    $CUSTOMER_ISSUE_TYPE__7__DISPATCH_FSLASH_RETURN,
                                                                ]
                                                      },
                                            } )->all;

    return \%hash;
}

1;
