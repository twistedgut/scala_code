package XTracker::Schema::Role::Ordered;
use NAP::policy "tt", 'role';

=head1 NAME

XTracker::Schema::Role::Ordered - Role to get ordered quantity detail

=head1 DESCRIPTION

Provides access to the view L<Public::VirtualProductOrderedQuantityDetails> to
obtain additional stock level data about products.

THese methods are slow.

=head1 METHODS

=head2 C<get_ordered_item_quantity_details_rs>

Returns the resultset created by the view in
L<Public::VirtualProductOrderedQuantityDetails>

=cut

sub get_ordered_item_quantity_details_rs {
    my $self = shift;

    my $pid = $self->id;
    $self->result_source->schema->resultset('Public::VirtualProductOrderedQuantityDetails')->search(
        {},
        {bind => [$pid, $pid, $pid, $pid, $pid, $pid, $pid, $pid, $pid]}
    );
}

=head2 C<get_order_item_quantity_details>

Returns a hashref of the data returned from
L</get_ordered_item_quantity_details_rs>

=cut

sub get_ordered_item_quantity_details {
    my $self = shift;

    my $rs = $self->get_ordered_item_quantity_details_rs->search(
        {},
        {result_class => 'DBIx::Class::ResultClass::HashRefInflator'}
    );

    my $data;
    while (my $row = $rs->next) {
        my $vid = delete $row->{variant_id};
        my $vtype = delete $row->{variant_type_id};
        $data->{$vid}{$vtype} = $row;
    }

    return $data;
}
