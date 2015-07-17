package XTracker::Schema::ResultSet::Public::MarketingCustomerSegment;
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use DateTime;
use Carp;

=head2 get_enabled_customer_segment_by_channel

 my @array = $self->get_enabled_customer_segment_by_channel( channel_id);

This function returns an array of active customer_segment sorted by ASC
creation data.

=cut

sub get_enabled_customer_segment_by_channel {
    my $self       = shift;
    my $channel_id  = shift;

    return if (!$channel_id);

    #return active list
    return $self->get_segment_list($channel_id ,'t');


}

=head2 get_disabled_customer_segement_by_channel

my @array = $self->get_disabled_customer_segment_by_channel ( channel_id);

This function return array of disabled customer_segment sorted by ASC
creation data.

=cut

sub get_disabled_customer_segment_by_channel {
    my $self       = shift;
    my $channel_id  = shift;


    return if (!$channel_id);

    #return disabled list
    return $self->get_segment_list($channel_id, 'f');
}


sub get_segment_list {
    my ( $self, $channel, $flag ) = @_;

    if ( !$channel || ( ref( $channel ) !~ /::Public::Channel$/ && $channel !~ /^\d+$/ ) ) {
        croak "No Channel Object or Channel Id has been passed into '" . __PACKAGE__ . "->list_for_channel' method";
    }

    my $channel_id  = ( ref( $channel ) ? $channel->id : $channel );

    my %include=();
    if($flag) {
        %include = (
            enabled => $flag,
        );
    }


    my $segment_rs = $self->search( {
        channel_id => $channel_id,
        %include,
        },
        { order_by   => ['me.created_date ASC' ]},
    );


    return [ $segment_rs->all ];
}

=head2 is_unique

my $flag = $self->is_unique($customer_segement_name, $channel_id);

This function does case insensitive search on marketing_customer_segment table for
given channel and name. Returns true if no records are found else return false.
i.e, we use this information to decide if the name provided is unique or not.

=cut



sub is_unique {
    my ( $self, $name, $channel_id ) = @_;

    return 0 unless($name && $channel_id);

    my $count = $self->search( {
        name  => { 'ILIKE' => $name },
        channel_id  => $channel_id,
    })->count;

    return ( $count > 0 ?  0 : 1  );
}


sub search_by_name {
    my ( $self, $name ) = @_;

    my $schema = $self->result_source->schema;

    my $segment_rs = $self->search( {
        name => $name,
        },
        { order_by => ['me.created_date ASC' ] },
    );

    return [ $segment_rs->all ];
}
1;
