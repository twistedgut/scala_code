package XT::Business::Base;

use Moose;

use XTracker::Config::Local     qw( config_var );


=head2 call ( $method, ..<parameters> )

Checks if the method exists for the module and calls it with the remaining
paramters. Otherwise return undef;

=cut

sub call {
    my $self = shift @_;
    my $method = shift @_;

    if ($self->can($method)) {
        return $self->$method(@_);
    }

    # we could warn something if the method isn't there but its not a must
    return;
}

=head1 apply_default_welcome_pack

    $boolean = $self->apply_default_welcome_pack( $order, $code );

Method to add a Welcome Pack to an Order for the default language of the DC.

=cut

sub apply_default_welcome_pack {
    my ( $self, $order )    = @_;

    return $self->_apply_welcome_language_pack(
        $order,
        config_var('Customer', 'default_language_preference'),
    );
}

=head1 apply_multi_language_welcome_pack

    $boolean = $self->apply_multi_language_welcome_pack( $order, $code );

Method to add a Welcome Pack using the Customer's Preferred Language.

=cut

sub apply_multi_language_welcome_pack {
    my ( $self, $order )    = @_;

    my $cpl = $order->customer->get_language_preference;

    return $self->_apply_welcome_language_pack(
        $order,
        $cpl->{language}->code,
    );
}

# assign a Welcome Pack for the supplied Language Code to an Order
sub _apply_welcome_language_pack {
    my ( $self, $order, $language_code )    = @_;

    my $schema  = $order->result_source->schema;
    my $channel = $order->channel;

    my $promo   = $channel->find_welcome_pack_for_language( $language_code );
    # just leave if there's no promo found
    return 0    if ( !$promo );

    if ( my $exclusion_product_types = $channel->welcome_pack_product_type_exclusion ) {
        return 0    if (
            $order->get_standard_class_shipment
                    ->has_only_items_of_product_types( $exclusion_product_types )
        );
    }

    # assign the Welcome Pack Promotion to the Order
    $order->create_related( 'order_promotions', {
        promotion_type_id => $promo->id,
        # neutral values for these other fields
        value   => 0,
        code    => 'none',
    } );

    return 1;
}

=head2 local_welcome_pack_qualification

    $boolean = $self->local_welcome_pack_qualification( $order );

Return TRUE or FALSE based on whether the Order should qualify
for a Welcome Pack.

This should be used as a Fallback if Seaview can't be reached to
get the 'welcomePackSent' flag or if the Sales Channel does not
use Seaview yet to check if a Welcome Pack has been sent.

=cut

sub local_welcome_pack_qualification {
    my ( $self, $order ) = @_;

    my $customer = $order->customer;

    my $can_send_pack = (
        $customer->orders->not_cancelled->count == 1
        ? 1
        : 0
    );

    if ( !$can_send_pack ) {
        # if it's not the first Order and there are Product Exclusions
        # for the Sales Channel then check to see if any Previous Orders
        # have had Welcome Packs applied, if not then return TRUE. Because
        # all previous Orders may have been made up of only the Excluded
        # Types and so no Pack would have been sent with those Orders
        my $channel    = $order->channel;
        my $exclusions = $channel->welcome_pack_product_type_exclusion // [];
        if ( @{ $exclusions } ) {
            my $previous_welcome_pack = $customer->orders->not_cancelled
                        ->search_related('order_promotions')
                            ->search_related( 'promotion_type', {
                name => { 'ILIKE' => 'Welcome Pack%' }
            } )->count;

            $can_send_pack = ( $previous_welcome_pack == 0 ? 1 : 0 );
        }
    }

    return $can_send_pack;
}


1;
