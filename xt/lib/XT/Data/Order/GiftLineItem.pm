package XT::Data::Order::GiftLineItem;
use NAP::policy "tt", 'class';

use XT::Data::Types qw(PosInt);

use XTracker::Database::Order       qw( create_order_promotion );
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw( :note_type );

=head1 NAME

XT::Data::Order::GiftLineItem - A Gift line item for an order for fulfilment

=head1 DESCRIPTION

This class represents a Gift line item for an order that is to be inserted into
XT's order database. It will end up populating the 'order_promotion' table.

=head1 ATTRIBUTES

=head2 schema

=cut

has schema => (
    is          => 'ro',
    isa         => 'DBIx::Class::Schema|XTracker::Schema|XT::DC::Messaging::Model::Schema',
    required    => 1,
);

=head2 description

=cut

has description => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

=head2 sku

=cut

has sku => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

=head2 quantity

Attribute must be a positive integer.

=cut

has quantity => (
    is          => 'rw',
    isa         => PosInt,
    required    => 1,
);

=head2 sequence

=cut

has sequence => (
    is          => 'rw',
    isa         => 'Int',
    required    => 1,
);

=head2 opted_out

=cut

has opted_out => (
    is          => 'rw',
    isa         => 'Bool',
    required    => 1,
);


=head1 METHODS

=head2 get_promo_type_for_sku

    $promo_type = $self->get_promo_type_for_sku( $channel );

This will return a 'Public::PromotionType' record based on the SKU for the Gift Item for the given Sales Channel.

=cut

sub get_promo_type_for_sku {
    my ( $self, $channel )  = @_;

    # search the Channel's Promotion Types
    return $channel->promotion_types->search( {
        name => { ilike => $self->sku },
    } )->first;
}

=head2 apply_to_order

    $self->apply_to_order( $order );

Will Apply to a 'Public::Orders' record the Gift Item.

=cut

sub apply_to_order {
    my ( $self, $order )    = @_;

    # get the 'promotion_type' record the Gift Line is for
    my $promo_type  = $self->get_promo_type_for_sku( $order->channel );
    if ( !defined $promo_type ) {
        die
              $order->channel->name
            . " - Order Nr: "
            . $order->order_nr
            . ", Gift Line Item: Couldn't Find a 'promotion_type' for '"
            . $self->sku
            . "'";
    }

    # see if the Customer Opted Out of Having the Gift or Not
    if ( !$self->opted_out ) {
        # they didn't so apply the Gift Promotion
        create_order_promotion(
            $self->schema->storage->dbh,
            $order->id,
            $promo_type->id,
            0,
            'none'
        );
    }
    else {
        # if they did then create an Order Note saying they were offered it but Opted Out
        $order->add_note(
            $NOTE_TYPE__ORDER,
              "Opted Out Of Free Gift: This Customer was Offered on the Web-Site the Following Gift: "
            . $promo_type->name
            . ",but Opted Out of receiving it."
        );
    }

    return;
}


=head1 SEE ALSO

L<XT::Data::Order>

=head1 AUTHOR

Andrew Beech <andrew.beech@net-a-porter.com>

=cut

__PACKAGE__->meta->make_immutable;

1;
