#!/usr/bin/env perl

# TODO: This should probably be a .pm, no real reason for it being in a .t
#   other than I couldn't think of a good place to put the .pm
#   see http://reviewboard.jaffar.dave.net-a-porter.com/r/413/#comment2729

use NAP::policy "tt", 'test', 'class';
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends 'NAP::Test::Class';
    with 'NAP::Test::Class::Template';
};

use Test::XTracker::RunCondition prl_phase => 'prl';



use Test::XTracker::Data;
use Test::XT::Data::PutawayPrep;
use XTracker::Database::PutawayPrep;
use XTracker::Database::PutawayPrep::RecodeBased;

use XTracker::Constants::FromDB qw(
    :putaway_prep_container_status
    :putaway_prep_group_status
);

sub startup :Test(startup) {
    my ($self) = @_;
    $self->{setup} = Test::XT::Data::PutawayPrep->new;
}

sub display_group_status_changes :Tests {
    my ($self) = @_;

    # Tests
    foreach my $config (
        {
            test_type           => 'stock process',
            recode              => 0,
            group_id_field_name => 'pgid',
            pp_helper           => XTracker::Database::PutawayPrep->new({ schema => $self->schema }),
        },
        {
            test_type           => 'stock recode',
            recode              => 1,
            group_id_field_name => 'recode_id',
            pp_helper           => XTracker::Database::PutawayPrep::RecodeBased->new({ schema => $self->schema }),
        }
    ) {
        note("set up ".$config->{test_type});

        my ($stock_process, $product_data)
            = $self->{setup}->create_product_and_stock_process( 1, {
                group_type => $config->{pp_helper}->name,
            });
        my $group_id = $product_data->{ $config->{group_id_field_name} };
        my $sku      = $product_data->{sku};
        my $pp_group = $self->{setup}->create_pp_group({
            group_id   => $group_id,
            group_type => $config->{pp_helper}->name,
        });

        # Initially, we shouldn't have any containers
        is ($self->display_status($pp_group), "Not Started",
            "Display status is 'Not Started' when we have no containers");

        my $expected_quantity = $pp_group->expected_quantity;

        # Put all except one in a container and send an advice

        my $pp_container = $self->{setup}->create_pp_container;
        for (1 .. ($expected_quantity - 1)) {
            $self->schema->resultset('Public::PutawayPrepContainer')->add_sku({
                container_id => $pp_container->container_id,
                sku          => $sku,
                group_id     => $group_id,
                putaway_prep => $config->{pp_helper},
            });
        }

        $pp_group = $self->schema->resultset('Public::PutawayPrepGroup')->find($pp_group->id);
        is ($self->display_status($pp_group), "In Progress",
            "Display status is 'In Progress' when we have a container that hasn't been completed");

        $self->schema->resultset('Public::PutawayPrepContainer')->finish({
            container_id => $pp_container->container_id,
        });

        $pp_group = $self->schema->resultset('Public::PutawayPrepGroup')->find($pp_group->id);
        is ($self->display_status($pp_group), "Part Complete",
            "Display status is 'Part Complete' when advice has been sent but not for full quantity");


        # Put the final item in a container and send another advice

        my $pp_container_2 = $self->{setup}->create_pp_container;
        $self->schema->resultset('Public::PutawayPrepContainer')->add_sku({
            container_id => $pp_container_2->container_id,
            sku          => $sku,
            group_id     => $group_id,
            putaway_prep => $config->{pp_helper},
        });
        $self->schema->resultset('Public::PutawayPrepContainer')->finish({
            container_id => $pp_container_2->container_id,
        });

        $pp_group = $self->schema->resultset('Public::PutawayPrepGroup')->find($pp_group->id);
        is ($self->display_status($pp_group), "Awaiting Putaway",
            "Display status is 'Awaiting Putaway' when advice has been sent for exact quantity");


        # Pretend we found another one

        my $pp_container_3 = $self->{setup}->create_pp_container;
        $self->schema->resultset('Public::PutawayPrepContainer')->add_sku({
            container_id => $pp_container_3->container_id,
            sku          => $sku,
            group_id     => $group_id,
            putaway_prep => $config->{pp_helper},
        });

        $pp_group = $self->schema->resultset('Public::PutawayPrepGroup')->find($pp_group->id);
        is ($self->display_status($pp_group), "Problem",
            "Display status is 'Problem' if we've added too many items for this group");

        $self->schema->resultset('Public::PutawayPrepContainer')->finish({
            container_id => $pp_container_3->container_id,
        });

        $pp_group = $self->schema->resultset('Public::PutawayPrepGroup')->find($pp_group->id);
        is ($self->display_status($pp_group), "Problem",
            "Display status is still 'Problem' after the final advice is sent");


        # Now pretend that last bit never happened, so we're back to the right amount

        $pp_container_3->putaway_prep_inventories->delete;
        $pp_container_3->delete;

        $pp_group = $self->schema->resultset('Public::PutawayPrepGroup')->find($pp_group->id);
        is ($self->display_status($pp_group), "Awaiting Putaway",
            "Display status is back to 'Awaiting Putaway'");


        # Update the containers as if advice_response messages had been received

        $pp_container->update({
            putaway_prep_status_id => $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE,
        });

        $pp_group = $self->schema->resultset('Public::PutawayPrepGroup')->find($pp_group->id);
        is ($self->display_status($pp_group), "Awaiting Putaway",
            "Display status is still 'Awaiting Putaway' when not all responses have been received");

        $pp_container_2->update({
            putaway_prep_status_id => $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE,
        });

        $pp_group = $self->schema->resultset('Public::PutawayPrepGroup')->find($pp_group->id);
        is ($self->display_status($pp_group), "Complete",
            "Display status is 'Complete' when all responses have been received");

        $pp_container_2->update({
            putaway_prep_status_id => $PUTAWAY_PREP_CONTAINER_STATUS__FAILURE,
            failure_reason => 'Test failure',
        });

        $pp_group = $self->schema->resultset('Public::PutawayPrepGroup')->find($pp_group->id);
        is ($self->display_status($pp_group), "Failed Advice",
            "Display status is still 'Failed Advice' if a response says failure");
    }
}

# Utility functions


=head2 display_status

Utility function to process the template and extract the status

First calls a wrapper template, which then includes the template we're testing.

=cut

sub display_status {
    my ($self, $pp_group) = @_;

    my @containers = $pp_group->putaway_prep_containers->all;

    my $template_vars = {
        containers             => \@containers,
        inventory_quantity     => $pp_group->inventory_quantity || undef,
        expected_quantity      => $pp_group->expected_quantity || undef,
        group_id               => $pp_group->canonical_group_id, # Used for error message
        group_display_status   => 'Unset',
        putaway_prep_group_row => $pp_group,
    };

    my $output = $self->process('putaway/group_status.tt', $template_vars);

    my ($status) = $output =~ m/group_display_status is "(.+)"/;
    return $status;
}


Test::Class->runtests;
