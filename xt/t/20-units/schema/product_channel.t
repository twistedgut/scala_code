package Test::Schema::ProductChannel;

use NAP::policy "tt", 'test';

use FindBin::libs;


use DateTime;

use Test::XTracker::Data;
use XTracker::Constants::FromDB qw{:recommended_product_type :channel};

use base 'Test::Class';

sub startup : Test(startup => 2) {
    my $schema = Test::XTracker::Data->get_schema;
    isa_ok($_[0]->{schema} = $schema, 'XTracker::Schema');

    my $rs = $schema->resultset('Public::ProductChannel');
    isa_ok($_[0]->{rs} = $rs, 'XTracker::Schema::ResultSet::Public::ProductChannel');
}

sub test_rs_pids_live_on_channel : Tests {
    my ( $self ) = @_;

    my ( $schema, $pc_rs ) = @{$self}{qw/schema rs/};

    my $pids = $self->create_products({how_many => 2});
    my @pcs = map { $_->{product_channel} } @$pids;
    is( @pcs, 2, 'got two products' );

    # Ensure all products are live to test success case
    $_->update({live => 1}) for @pcs;
    ok( $pc_rs->pids_live_on_channel(
            $pcs[0]->channel_id,
            [ map { $_->product_id } @pcs ],
        ), 'pids_live_on_channel success' );

    # Ensure one product isn't live to test fail case
    $pcs[0]->update({live => 0});
    ok( !$pc_rs->pids_live_on_channel(
            $pcs[0]->channel_id,
            [ map { $_->product_id } @pcs ],
        ), 'pids_live_on_channel fail' );
}

sub test_row_get_recommended_with_live_products : Tests {
    my ( $self ) = @_;

    my ( $schema, $pc_rs ) = @{$self}{qw/schema rs/};

    my $pids = $self->create_products({how_many => 2});
    my ( $pc, $recommended ) = map { $_->{product_channel} } @$pids;
    isa_ok( $_, 'XTracker::Schema::Result::Public::ProductChannel' )
        for $pc, $recommended;

    # Delete any existing recommendations/colour variations and add our own
    $recommended->recommended_product_parents->delete;
    $recommended->add_to_recommended_with($pc, {
        type_id => $RECOMMENDED_PRODUCT_TYPE__RECOMMENDATION,
        slot => 1,
        sort_order => 1,
    });
    $pc->update({live => 1});
    is( $recommended->get_recommended_with_live_products->count,
        1,
        'found one recommended live product'
    );
    $pc->update({live => 0});
    is( $recommended->get_recommended_with_live_products->count,
        0,
        'found no recommended live products'
    );
}

sub create_products {
    my $self = shift;
    return Test::XTracker::Data->find_or_create_products({
        channel_id => $_[0]{channel_id} || $self->get_any_channel->id,
        how_many => $_[0]{how_many} || 1,
    });
}

sub get_any_channel {
    return $_[0]->{schema}->resultset('Public::Channel')->slice(0,0)->single;
}

Test::Class->runtests;

1;
