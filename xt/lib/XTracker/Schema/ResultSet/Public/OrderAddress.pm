package XTracker::Schema::ResultSet::Public::OrderAddress;

use NAP::policy "tt";
use base 'DBIx::Class::ResultSet';

use Storable 'dclone';

=head1 NAME

XTracker::Schema::ResultSet::Public::OrderAddress

=head1 DESCRIPTION

ResultSet class for Public::OrderAddress

=head1 METHODS

=head2 matching_id

Match the address on a hash of data. Return the address primary key or
0. Attempts to replicate the semantics of XTracker::Database::Address::check_address

=cut

sub matching_id {
    my ($self, $addr_data) = @_;

    my $schema = $self->result_source->schema;

    # Input should be a hashref of address data with keys matching the
    # database field names. We're just going to stuff this into a simple
    # search
    my $input_data = dclone($addr_data);

    # Remove attributes that falsely limit the match
    delete $input_data->{hash};
    my $urn = delete $input_data->{urn};
    my $last_mod = delete $input_data->{last_modified};

    # Simple search
    my $address_rs
      = $schema->resultset('Public::OrderAddress')->search($input_data);

    # Return either a matching address id or 0
    my $address_id = 0;
    if(defined $address_rs){
        if($address_rs->count == 1){
            $address_id = $address_rs->first->id;
        }
        elsif($address_rs->count > 1){
            # More than one match. For now just take the first one
            $address_id = $address_rs->first->id;
        }
    }

    return $address_id;
}
