package Test::NAP::PackLaneDisplay;
use FindBin::libs;
use parent "NAP::Test::Class";

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XT::Data::Container;
use Test::XTracker::Data::PackRouteTests;

use NAP::ShippingOption;

sub startup : Test(startup) {
    my ( $self ) = @_;
    $self->SUPER::startup;

    $self->{schema} = Test::XTracker::Data->get_schema;
    my $plt = Test::XTracker::Data::PackRouteTests->new;

    $plt->reset_and_apply_config($plt->like_live_packlane_configuration());
}

sub check_data_structure_for_template : Tests() {
    my $self = shift;

    # Get a packlane
    my $schema = $self->{schema};
    my $packlane = $schema->resultset('Public::PackLane')
                   ->search( undef, { 'order_by' => 'me.human_name' } )
                   ->slice(3,3)
                   ->single;

    # Set up two containers in the packlane
    my ($container_1, $container_2) = Test::XT::Data::Container->get_unique_ids( { how_many => 2 } );
    for my $container_id ($container_1, $container_2) {
       my $container = $schema->resultset('Public::Container')->find( $container_id );

       unless ($container) {
           $container = $schema->resultset('Public::Container')
               ->new( { id => $container_id, has_arrived => 1 } );
           $container->insert;
       }

       $container->update( { pack_lane_id => $packlane->id });
    }

    # Call method we wish to test
    my @pl_info = $schema->resultset('Public::PackLane')->packlanes_and_containers;

    # Check if our pack lane is in the list of packlanes
    my $our_pl;
    for my $pl (@pl_info) {
      if ($pl->pack_lane_id eq $packlane->pack_lane_id) {
          $our_pl = $pl;
          last;
      }
    }
    ok($our_pl,"Found correct pack lane in array");

    # Check if our containers are in the list of containers on the pack lane
    my ($container_1_found, $container_2_found);
    for my $con ($our_pl->containers) {
      $container_1_found = $con if $con->id eq $container_1;
      $container_2_found = $con if $con->id eq $container_2;
    }
    ok($container_1_found,"Found first container in pack lane");
    ok($container_2_found,"Found second container in pack lane");
}

1;
