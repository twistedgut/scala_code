package XTracker::Schema::ResultSet::Public::Box;

use NAP::policy "tt";

use base 'DBIx::Class::ResultSet';

sub update_or_create {
    my ( $self, $parameters ) = @_;

    my $box_id = $parameters->{id} // undef;
    my $sort_order = $parameters->{sort_order};

    my $box = $self->result_source->resultset->search({
        channel_id => $parameters->{channel_id},
        sort_order => $sort_order })->first;

    if ( $box && ( !$box_id || $box->id != $box_id ) ) {
        $box->update_sort_order( $sort_order+1 );
        $box->update( { sort_order => $sort_order+1 } );
    }

    my $updated_box = $self->next::method($parameters);

    $updated_box->update_volumetric_weight;

    return $updated_box;
};

1;
