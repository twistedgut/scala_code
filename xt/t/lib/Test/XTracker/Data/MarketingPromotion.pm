package Test::XTracker::Data::MarketingPromotion;

use NAP::policy     qw( test );

use Test::XTracker::Data;

use XTracker::Constants     qw( :application );
use XTracker::Constants::FromDB qw(
    :promotion_class
);

=head1 NAME

Test::XTracker::Data::MarketingPromotion - Does Marketing Promotion- 'In the Box'
related functionality.

=cut

=head1 METHODS
=head2 create_marketing_promotion

    $array_ref_rs = __PACKAGE__->create_marketing_promotion( {
        channel_id          => <channel_id>,
        start_date          => <date>,                         # optional, defaults to now()
        end_date            => <date>,                         # optional, defaults to now()
        count               => <no of promotions to create>,   # optional, defaults to 1
        send_once           => <true or false>,                # optional, defaults to 1

        # The following parameters are optional, but C<promotion_type_id> always overrides C<with_promotion_type>.
        # In other words, specifying a specific ID means no new C<Public::PromotionType> record wil be created,
        # even if C<with_promotion_type> is present (with or without keys).

        promotion_type_id   => <Public::PromotionType ID>,     # optional, defaults to undef
                                                               # (meaning it's un-weighted).

        promotion_type      => {
            name               => <string>,                    # optional, default: 'Test Promotion Type'
            product_type       => <string>,                    # optional, default: 'Test Product Type'
            weight             => <number>,                    # optional, default: 0.5
            fabric             => <string>,                    # optional, default: 'Plastic'
            origin             => <Public::Country>,           # optional, default: a Country row.
            hs_code            => <Public::HSCode>,            # optional, default: an HSCode row,
            promotion_class_id => <Public::PromotionClass ID>, # optional, default: $PROMOTION_CLASS__FREE_GIFT,
        },

    });

Will create C<count> number of marketing_promotion records for the given C<channel_id>.

=cut

sub create_marketing_promotion {
    my( $self, $args ) = @_;

    my $schema = Test::XTracker::Data->get_schema;
    my $count = $args->{count} || 1;
    my $promotion_type_id = $args->{promotion_type_id};
    my @rows;

    if (
        !defined $promotion_type_id &&
        exists $args->{promotion_type} &&
        ref( $args->{promotion_type} ) eq 'HASH'
    ) {

        # Makes no sense creating a Promotion Type for another channel.
        delete $args->{promotion_type}{channel_id};

        # Create a Promotion Type for every Marketing Promotion.
        my $promotion_type = $schema->resultset('Public::PromotionType')->create( {
            name               => 'Test Promotion Type',
            product_type       => 'Test Product Type',
            weight             => 0.5,
            fabric             => 'Plastic',
            origin             => $schema->resultset('Public::Country')->first->country,
            hs_code            => $schema->resultset('Public::HSCode')->first->hs_code,
            promotion_class_id => $PROMOTION_CLASS__IN_THE_BOX,
            channel_id         => $args->{channel_id},
            %{ $args->{promotion_type} },
        } );

        $promotion_type_id = $promotion_type->id;

        print "Promotion Type Create with ID $promotion_type_id\n";

    }

    for my $i ( 1..$count) {
       my $record = $schema->resultset('Public::MarketingPromotion')->create({
                   title                => $args->{title}       // 'Test Promotion',
                   description          => 'This promotion is created by test data',
                   channel_id           => $args->{channel_id},
                   start_date           => $args->{start_date}  || \'now()',
                    end_date            => $args->{end_date}    || \'now()',
                    is_sent_once        => $args->{send_once}   || '1',
                    message             => $args->{message}     // 'Test message for packers',
                    operator_id         => $APPLICATION_OPERATOR_ID,
                    promotion_type_id   => $promotion_type_id,
                });
        print "Marketing Promotion Created Id/Name/Channel: ". $record->id ."/". $record->title ."/". $record->channel_id."\n";
        push (@rows, $record);
    }

    return \@rows;

}

=head2 create_link

created record in link_orders__marketing_promotions table
for given order and promotion object.

=cut
sub create_link {
    my $self      = shift;
    my $order     = shift;
    my $promotion = shift;

    my $schema = Test::XTracker::Data->get_schema;
    $order->create_related('link_orders__marketing_promotions',{
        marketing_promotion_id => $promotion->id,
    });

    return;

}

=head2 delete_all_link_promotions

This method deletes records from link_orders__marketing_promotions table
for a customer of given order.


=cut

sub delete_all_link_promotions {
    my $self = shift;
    my $order = shift;

    my $schema = Test::XTracker::Data->get_schema;
    my $order_rs = $schema->resultset('Public::Orders')->search(
    { customer_id => $order->customer_id,
    });

    while ( my $order = $order_rs->next ) {
        $order->link_orders__marketing_promotions->delete;
    }

    return;

}

=head2 delete_all_promotions_by_channel


=cut

sub delete_all_promotions_by_channel {
    my $self = shift;
    my $channel_id  = shift;

    my $schema = Test::XTracker::Data->get_schema;
    my $promo_rs =  $schema->resultset('Public::MarketingPromotion')->search(
    {   channel_id => $channel_id,
    });

    while ( my $promo = $promo_rs->next ) {
        $promo->marketing_promotion_logs->delete;
        $promo->link_orders__marketing_promotions->delete;
        $promo->delete;
    }
    return;

}


1;
