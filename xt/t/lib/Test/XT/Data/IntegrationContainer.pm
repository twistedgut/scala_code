package Test::XT::Data::IntegrationContainer;

use NAP::policy qw /tt test/;
use MooseX::Params::Validate qw/validated_list/;

use Test::XT::Data::Container;
use XTracker::Constants::FromDB qw(
    :prl
);
use vars qw/ $PRL__GOH $PRL__DEMATIC /;

=head2 create_new_integration_containers(:$status = available, :$how_many = 1) : $container_ids | @container_ids

Adds new integration containers into system.

Takes exactly the same arguments as
    Test::XT::Data::Container->create_new_containers

Uses that to make containers with those specifications, and then creates a
related integration_container for each one.

Returns array of integration container rows.

=cut

sub create_new_integration_containers {
    my ($self, $args) = @_;

    my $prl_id = $PRL__GOH; # This is the only PRL where we integrate at the moment

    my $schema = Test::XTracker::Data->get_schema;

    my @new_container_rows = Test::XT::Data::Container->create_new_container_rows($args);

    return map {
        $schema->resultset('Public::IntegrationContainer')->create({
            container_id => $_->id,
            prl_id       => $prl_id,
        });
    } @new_container_rows;
}

sub route_to_integration {
    my $class = shift;
    my ($integration_container_row) = validated_list(
        \@_,
        integration_container     => { isa => 'XTracker::Schema::Result::Public::IntegrationContainer' },
    );
    $integration_container_row->update({
        routed_at   => $integration_container_row->result_source->schema->db_now(),
        from_prl_id => $PRL__DEMATIC, # This is the only PRL we integrate from at the moment
    });
}


1;

