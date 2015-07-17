package XTracker::Schema::ResultSet::Public::MarketingPromotion;
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';
use DateTime;


=head2 get_enabled_promotion_by_channel

 my @array = $self->get_enabled_promotion_by_channel( channel_id);

This function returns an array of active expired and non-expired
marketing_promotions sorted by the promotion start date and end date

=cut

sub get_enabled_promotion_by_channel {
    my $self       = shift;
    my $channel_id  = shift;

    return if (!$channel_id);

    #return active list
    return $self->_get_promotion_list($channel_id ,'t');


}

=head2 get_disabled_promotion_by_channel

my @array = $self->get_disabled_promotion_by_channel ( channel_id);

This function return array of disabled marketing promotion
sorted by the promotion start date and end date

=cut

sub get_disabled_promotion_by_channel {
    my $self       = shift;
    my $channel_id  = shift;


    return if (!$channel_id);

    #return disabled list
    return $self->_get_promotion_list($channel_id, 'f');
}

=head2 get_active_promotions_by_channel

my $result_set = $self->get_active_promotions_by_channel ( channel_id)

Returns resultset contaning all non-expired active promotions

=cut
sub get_active_promotions_by_channel {
    my $self       = shift;
    my $channel_id = shift;


    my $promotion_rs  = $self->search( {
        channel_id => $channel_id,
        enabled    => 't',
        start_date => { '<=' => \"current_timestamp"},
        end_date   => { '>=' => \"current_timestamp" },
    });

    return $promotion_rs;


}

sub _get_promotion_list {
    my ( $self, $channel_id, $flag ) = @_;

    my $promotion_rs = $self->search( {
        channel_id => $channel_id,
        enabled    => $flag,
        },
        { order_by   => ['me.start_date DESC', 'me.end_date ASC' ]},
    );


    return [ $promotion_rs->all ];
}

=head2 get_weighted_promotions

Return a ResultSet of Marketing Promotions that are weighted. Weighted
promotions are defined by having an associate Promotion Type.

    my $weight_promotions = $schema
        ->resultset('Public::MarketingPromotion')

=cut

sub get_weighted_promotions {
    my $self = shift;

    return $self->search( {
        promotion_type_id => { '!=' => undef },
    } );

}

1;
