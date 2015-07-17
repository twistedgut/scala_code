#!/usr/bin/perl

use FindBin::libs;
use parent 'NAP::Test::Class';
use NAP::policy "tt", 'test';

=head2 Tests methods of 'XTracker::Schema::Result::Public::MarketingPromotion


=cut

use Test::XTracker::Data;
use Test::XTracker::Data::MarketingPromotion;

sub start_tests :Tests(startup) {
    my ($self) = @_;

    $self->{schema} = Test::XTracker::Data->get_schema();

    # Start a transaction, so we can rollback after testing
    $self->{schema}->txn_begin;
}

sub rollback : Test(shutdown) {
    my $self = shift;

    $self->{schema}->txn_rollback;
}

sub test_get_promotion_by_channel :Tests() {
    my ($self) = @_;


    my $channel = Test::XTracker::Data->any_channel;
    my $expected = {
        first_enabled_count  => 3,
        second_enabled_count => 3,
        first_disabled_count => 2,
    };

    my $got= {};
    # delete all promotions
    Test::XTracker::Data::MarketingPromotion->delete_all_promotions_by_channel($channel->id);

    #create 5 promotions
    my $promotions = Test::XTracker::Data::MarketingPromotion->create_marketing_promotion({channel_id => $channel->id, count=> 5});
    #disable two of them
    @$promotions[0]->update({enabled => 'false' });
    @$promotions[1]->update({enabled => 'false' });

    my $mk_promo = $self->{schema}->resultset('Public::MarketingPromotion');
    $got->{first_enabled_count} = scalar( @{$mk_promo->get_enabled_promotion_by_channel($channel->id)});


    #expire one of the prmotion and check the count is still the same
    my $now = DateTime->now( time_zone => 'local' );
    my $yesterday = $now - DateTime::Duration->new( days => 1 );
    @$promotions[3]->update({ end_date => $yesterday } );
    $got->{second_enabled_count} = scalar( @{$mk_promo->get_enabled_promotion_by_channel($channel->id)});
    $got->{first_disabled_count} = scalar( @{$mk_promo->get_disabled_promotion_by_channel($channel->id)});


    is_deeply($got, $expected, 'test_get_enabled_promotion_by_channel : Got correct records for enabled');

    return;
}

sub test_get_active_promotion_by_channel : Tests() {
    my ($self) = @_;

    my $channel = Test::XTracker::Data->any_channel;

    my $expected = {
        first_active_count => 3,
    };

    my $got ={};
    # delete all promotions
    Test::XTracker::Data::MarketingPromotion->delete_all_promotions_by_channel($channel->id);

    my $promotions = Test::XTracker::Data::MarketingPromotion->create_marketing_promotion({channel_id => $channel->id, count=> 6});
    #create 6 promotions
    #disable two, expire one and check the count
    @$promotions[0]->update({enabled => 'false' });
    @$promotions[1]->update({enabled => 'false' });
    my $now = DateTime->now( time_zone => 'local' );
    my $yesterday = $now - DateTime::Duration->new( days => 1 );
    @$promotions[3]->update({ end_date => $yesterday } );

    @$promotions[3]->update({ end_date => $yesterday } );

    my $mk_promo = $self->{schema}->resultset('Public::MarketingPromotion');
    $got->{first_active_count} = $mk_promo->get_active_promotions_by_channel($channel->id)->count;

    is_deeply($got, $expected, 'test_get_active_promotions_by_channel : Got correct records for active list');

}

sub test_is_weighted : Tests() {
    my $self = shift;

    my $channel = Test::XTracker::Data->any_channel;

    # Delete all existing promotions for this channel.
    Test::XTracker::Data::MarketingPromotion
        ->delete_all_promotions_by_channel( $channel->id );


    # Create a new Marketing Promotion without a promotion type (un-weighted).
    my $non_weighted_promotion = Test::XTracker::Data::MarketingPromotion
        ->create_marketing_promotion( {
            channel_id => $channel->id,
        } );

   # Create a new Marketing Promotion with a promotion type (weighted).
    my $weighted_promotion = Test::XTracker::Data::MarketingPromotion
        ->create_marketing_promotion( {
            channel_id     => $channel->id,
            promotion_type => {},
        } );

    is( $non_weighted_promotion->[0]->is_weighted, 0, 'Marketing Promotion without a promotion type is un-weighted' );
    is( $weighted_promotion->[0]->is_weighted, 1, 'Marketing Promotion with a promotion type is weighted' );

}

Test::Class->runtests;
