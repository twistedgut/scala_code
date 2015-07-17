package Test::NAP::GoodsIn::PutawayAdmin;

=head1 NAME

Test::NAP::GoodsIn::PutawayAdmin - Flow tests for XTracker::Stock::GoodsIn::PutawayAdmin

=head1 DESCRIPTION

Test the Putaway Prep Admin Page.

Incorporates model, database and handler logic.

#TAGS goodsin putaway prl html

=cut

use NAP::policy "tt", qw/test class/;

BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with (
        "Test::Role::GoodsIn::PutawayPrep",
        "NAP::Test::Class::PRLMQ",
        "NAP::Test::Class::PRLMQ::Messages",
    );
};

use FindBin::libs;
use Test::XTracker::RunCondition prl_phase => 'prl';


use Data::Dumper;

use Test::XT::Flow;
use Test::XT::Data::PutawayPrep;
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :putaway_prep_group_status
    :putaway_prep_container_status
    :flow_status
);
use XTracker::Constants qw(
    :prl_type
);

sub startup : Test(startup => 2) {
    my ($self) = @_;
    $self->SUPER::startup;

    use_ok 'XTracker::Stock::GoodsIn::PutawayAdmin';

    $self->{pp_container_rs} = $self->schema->resultset('Public::PutawayPrepContainer');
    $self->{pp_helper} = XTracker::Database::PutawayPrep->new({ schema => $self->schema });
    $self->{setup} = Test::XT::Data::PutawayPrep->new;

    $self->{flow} = $self->get_flow; # we only need to log in once
}

=head2 basic_handler_logic

Perform following steps:

    * First, go to Putaway Prep page.

    * Group should not be visible on Admin page until the first SKU has been scanned
        into a container.

    * On Putaway Prep page, scan one SKU. Group should now be visible on Admin page.
    * On Putaway Prep page, scan a second SKU into the first container.
    * Verify quantity updated correctly on Admin page.

    * PP: Scan a second container
    * PP: Scan a third SKU into second container
    * Admin: Check both containers and quantities updated correctly
    * PP: Finish first container
    * Admin: Check containers updated correctly

    * PP: Scan remaining 7 SKUs, plus one more SKU, into second container
    * Admin: Group should now be in 'Problem' status

    * Set group up to be removed:
        * PP: Finish second container
        * Setup: Mark both containers as 'Putaway' (Warning: This skips the AdviceResponse message)
        * Admin: Click the 'Remove' button for this group (javascript confirmation is bypassed)
        * Admin Group should have disappeared

=cut

sub basic_handler_logic : Tests {
    my ($self) = @_;

    my $config = { recode => 0, pp_helper => $self->{pp_helper} };
    # setup
    my ($stock_process, $product_data) = $self->{setup}->create_product_and_stock_process;
    my $group_id = $product_data->{pgid};
    my $sku = $product_data->{sku};
    note("using Group ID $group_id");
    my $pp_group = $self->{setup}->create_pp_group({
        group_id   => $group_id,
        group_type => (
            $config->{recode}
                ? XTracker::Database::PutawayPrep::RecodeBased->name
                : XTracker::Database::PutawayPrep->name
        ),
    });
    my $pp_container = $self->{setup}->create_pp_container;
    my $container_id = $pp_container->container_id;

    # just return hashrefs, not all the fancy DBIC row objects
    $self->schema->resultset('Public::PutawayPrepGroup')->result_class('DBIx::Class::ResultClass::HashRefInflator');

    # generate the DBIC object in the same way the handler does,
    # with prefetching of the relevant rows all in the initial query
    my @pp_groups = $self->schema->resultset('Public::PutawayPrepGroup')
        ->filter_ready_for_putaway->filter_active->filter_normal_stock
        ->search ({ 'me.group_id' => $group_id })->all;

    die "no groups matched" unless scalar(@pp_groups);
    die "more than one group matched" if scalar(@pp_groups) > 1;
    is($pp_groups[0]->canonical_group_id, $pp_group->canonical_group_id,
        'group was selected using filter');

    # Group exists but should not be visible on page yet
    $self->reload_page;
    my $group_on_page = $self->find_group_on_page($pp_group->canonical_group_id);
    is( $group_on_page, undef, "group is not started yet so doesn't appear on page" );
    my $container_on_page = $self->find_container_on_page($container_id);
    is($container_on_page, undef, "container doesn't appear on page yet");

    # Scan one SKU into first container
    note("scan one SKU");
    $self->{pp_container_rs}->add_sku({
        container_id => $container_id,
        sku => $sku,
        putaway_prep => $config->{pp_helper},
        group_id => $group_id,
    });

    # Group is now visible on page
    $self->reload_page;
    $group_on_page = $self->find_group_on_page($pp_group->canonical_group_id);
    isnt( $group_on_page, undef, "group has been started so shows up on the page" );
    is( $group_on_page->{'Status'}, 'In Progress', "group status is 'In Progress'" );
    $container_on_page = $self->find_container_on_page($container_id);
    isnt($container_on_page, undef, "container appears on page");

    is($container_on_page->{'Qty Scanned'}, 1, 'quantity scanned is as expected' );

    # Scan a second SKU into first container
    note("scan another SKU");
    $self->{pp_container_rs}->add_sku({
        container_id => $container_id,
        sku => $sku,
        putaway_prep => $config->{pp_helper},
        group_id => $group_id,
    });

    # Check quantity updated correctly
    $self->reload_page;
    $group_on_page = $self->find_group_on_page($pp_group->canonical_group_id);
    $container_on_page = $self->find_container_on_page($container_id);
    is($group_on_page->{'Qty Scanned'}, 2, "group quantity scanned is as expected" );
    is($container_on_page->{'Qty Scanned'}, 2, "container quantity scanned is as expected" );

    # Scan a second container
    note("set up container 2");
    my $pp_container2 = $self->{setup}->create_pp_container;

    # Scan a third SKU into second container
    note("scan another SKU into container 2");
    $self->{pp_container_rs}->add_sku({
        container_id => $pp_container2->container_id,
        sku => $sku,
        putaway_prep => $config->{pp_helper},
        group_id => $group_id,
    });

    # Check both containers and quantities updated correctly
    $self->reload_page;
    $group_on_page = $self->find_group_on_page($pp_group->canonical_group_id);
    $container_on_page = $self->find_container_on_page($container_id);
    my $container2_on_page = $self->find_container_on_page($pp_container2->container_id);
    isnt($container_on_page, undef, "container 1 still appears on page");
    is($container_on_page->{'Qty Scanned'}, 2, "container 1 quantity scanned remains as expected" );
    isnt($container2_on_page, undef, "container 2 appears on page");
    is($container2_on_page->{'Qty Scanned'}, 1, "container 2 quantity scanned is as expected" );
    is($group_on_page->{'Qty Scanned'}, 3, "group quantity scanned is as expected" );

    # Finish first container
    note("finish container 1");
    $self->{pp_container_rs}->finish({
        container_id => $container_id,
    });

    # Check containers updated correctly
    $self->reload_page;
    $group_on_page = $self->find_group_on_page($pp_group->canonical_group_id);
    is( $group_on_page->{'Status'}, 'Part Complete', 'group is part complete');
    is( $group_on_page->{'Qty Scanned'}, 3, 'group quantity is as expected');
    $container_on_page = $self->find_container_on_page($container_id);
    is( $container_on_page->{'Container ID'}, $container_id, 'container ID is correct');
    is( $container_on_page->{'Qty Scanned'}, 2, 'container quantity scanned is 2');
    is( $container_on_page->{'Advice Status'}, 'Sent', 'container status is sent');

    # Scan remaining 7 SKUs, plus one more SKU, into second container
    note("scan remaining SKUs into second container");
    $self->{pp_container_rs}->add_sku({
        container_id => $pp_container2->container_id,
        sku => $sku,
        putaway_prep => $config->{pp_helper},
        group_id => $group_id,
    }) for 1 .. 8;

    # Group should now be in 'Problem' status
    $self->reload_page;
    $group_on_page = $self->find_group_on_page($pp_group->canonical_group_id);
    is( $group_on_page->{'Status'}, 'Problem', 'group problem is detected');

    # Set group up to be removed:
    # Finish second container
    note("finish container 2");
    $self->{pp_container_rs}->finish({ container_id => $pp_container2->container_id });
    # Mark both containers as 'Putaway' (Warning: This skips the AdviceResponse action)
    $_->update({ putaway_prep_status_id => $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE }) for $pp_container, $pp_container2;

    ok( $pp_group->can_mark_resolved, 'Group can be resolved' );

    # Click the 'Remove' button for this group (javascript confirmation is bypassed)
    $self->reload_page;
    $self->{flow}->mech__goodsin__putaway_prep_admin_remove_group($pp_group->canonical_group_id);

    # Group should have disappeared
    my $info_message_removed = sprintf("Group '%s' was removed.", $pp_group->canonical_group_id);
    like( $self->{flow}->mech->app_info_message,
        qr/$info_message_removed/,
        'User is informed that group was removed',
    );
    $self->reload_page;
    $group_on_page = $self->find_group_on_page($pp_group->canonical_group_id);
    is( $group_on_page, undef, "group doesn't appear on page anymore" );
    $pp_group->discard_changes;
    is($pp_group->status_id, $PUTAWAY_PREP_GROUP_STATUS__RESOLVED, 'group status is "Resolved"');
}

=head2 mark_container_as_completed

Mark container as completed in Putaway Prep, verify that it appears as
'Awaiting Putaway' on the Admin page.

=cut

sub mark_container_as_completed :Tests {
    my ($self) = @_;

    # setup
    my ($stock_process, $product_data) = $self->{setup}->create_product_and_stock_process;
    my $pgid = $product_data->{pgid};
    #my $user_id = $self->{setup}->get_user_id;

    my $group_on_page = $self->find_group_on_page("p$pgid");
    is( $group_on_page, undef, "Group doesn't appear on Putaway Prep Admin page yet");

    # get SKU from PGID
    my ($sku) = sort @{ $self->{pp_helper}->get_skus_for_group_id($pgid) };

    # start a container
    my $pp_group = $self->{setup}->create_pp_group({ group_id => $pgid });
    my $pp_container = $self->{setup}->create_pp_container;

    # add all items to the container
    $self->{pp_container_rs}->add_sku({
        container_id => $pp_container->container_id,
        sku => $sku,
        putaway_prep => $self->{pp_helper},
        group_id => $pgid,
    }) for 1..10;

    $self->reload_page;

    # shows up on putaway prep admin page
    $group_on_page = $self->find_group_on_page("p$pgid");
    isnt( $group_on_page, undef, "Group (p$pgid) appears on Putaway Prep Admin page now");

    # mark current container as completed
    $self->{pp_container_rs}->finish({
        container_id => $pp_container->container_id,
    });

    $self->reload_page;

    $group_on_page = $self->find_group_on_page("p$pgid");
    is( $group_on_page->{Status}, 'Awaiting Putaway', "Group (p$pgid) is awaiting putaway");

}

sub _normalize_html {
    my ($self, $html) = @_;

    $html =~ s/name="dbl_submit_token" value=".+?"//gsm;

    return $html;
}

sub ensure_page_didnt_break {
    my ($self, $original_html) = @_;

    note "Ensure the page didn't break";
    lives_ok(sub {$self->reload_page});
}

=head2 migration_does_not_affect_putaway_prep_admin

Take a snapshot of the page, then pretend we've migrated a container of stock.
Send the StockAdjust message with: migrate_container => "N".

Take another snapshot of the page and verify the page did not change.

Pretend we've migrated a container of stock, the last one for the PID.
Send the StockAdjust message with: migrate_container => "Y".

Take a snapshot of the page again, and verify the page did not change.

=cut

sub migration_does_not_affect_putaway_prep_admin : Tests() {
    my $self = shift;

    note "Take a snapshot of the page";
    $self->reload_page();
    my $original_html = $self->{flow}->mech->content;

    note "Add some migrations";
    my $migration_name = XTracker::Database::PutawayPrep::MigrationGroup->name;
    my ($stock_process, $product_data)
        = $self->{setup}->create_product_and_stock_process(
            1,
            { group_type => $migration_name },
        );

    note "Create a migration stock adjust to kick off a pprep group";
    my $first_container_row
        = Test::XT::Data::Container->create_new_container_row();
    $self->send_stock_adjust({
        delta_quantity         => -4,
        total_quantity         => 1,
        sku                    => $product_data->{sku},
        migration_container_id => $first_container_row->id . "",
        migrate_container      => $PRL_TYPE__BOOLEAN__FALSE,
    });

    note "Sanity: Is there a pprep_container with a pprep_group in progress?";
    my $pprep_container_row = $self->schema->resultset(
        "Public::PutawayPrepContainer",
    )->find({ container_id => $first_container_row->id . "" });
    ok($pprep_container_row, "Found pprep container");
    my $pprep_group_row = $pprep_container_row->putaway_prep_groups->first;
    ok($pprep_group_row, "    and it's got a pprep group");

    $self->ensure_page_didnt_break();


    note "Send advice, check again";

    note "Create a migration stock adjust to kick off a pprep group";
    my $final_container_row
        = Test::XT::Data::Container->create_new_container_row();
    $self->send_stock_adjust({
        delta_quantity         => -1,
        total_quantity         => 0,
        sku                    => $product_data->{sku},
        migration_container_id => $first_container_row->id . "",
        migrate_container      => $PRL_TYPE__BOOLEAN__TRUE,
    });
    $self->ensure_page_didnt_break();
}


# Utility methods

sub reload_page {
    my ($self) = @_;
    $self->{flow}->mech__goodsin__putaway_prep_admin;
    $self->{page_data} = $self->{flow}->mech->as_data;
}

sub find_group_on_page {
    my ($self, $group_id) = @_;
    return $self->_find_on_page('Group', $group_id, 'stock_process_table');
}

sub find_container_on_page {
    my ($self, $container_id) = @_;
    return $self->_find_on_page('Container ID', $container_id, 'container_table');
}

sub _find_on_page {
    my ($self, $key, $value, $table_name) = @_;

    if ($self->{page_data}) {
        my $table_data = $self->{page_data}->{$table_name};
        if ($table_data && ref $table_data eq 'ARRAY') {
            foreach my $row (@$table_data) {
                return $row if ($row->{$key} eq $value);
            }
        }
    }

    return;
}

1;
