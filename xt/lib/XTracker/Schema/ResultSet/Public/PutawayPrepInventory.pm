package XTracker::Schema::ResultSet::Public::PutawayPrepInventory;

=head1 NAME

XTracker::Schema::ResultSet::Public::PutawayPrepInventory - ResultSet for items in a PutawayPrepContainer

=head1 DESCRIPTION

A PutawayPrepContainer contains many PutawayPrepInventory

=head1 SYNOPSIS

my $items = $schema->resultset('Public::PutawayPrepContainer')->putaway_prep_inventories;

=head1 METHODS

=cut

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';
use Class::Method::Modifiers;
use Carp 'confess';
use List::MoreUtils qw/uniq/;
use DateTime::Format::Pg;

use XTracker::Logfile qw(xt_logger);
use XTracker::Constants::FromDB qw(
    :delivery_item_type
    :putaway_prep_group_status
    :putaway_prep_container_status
    :stock_process_type
);

my $log = xt_logger(__PACKAGE__);

=head2 search_with_variant

Extend DBIC's built-in search method. If variant_id is specified,
first try to match it against the variant_id column, then try
to match it against the voucher_variant_id column.

=cut

# I tried doing "around 'search'", but got some confusing 'deep recursion' errors
sub search_with_variant {
    my ($self, $args) = @_;

    my $result = $self->search($args);

    if ($result->count) {
        # there is a match
        return $result;
    } elsif (exists $args->{variant_id}) {
        # variant_id was not matched
        # try matching ID against voucher_variant_id column
        $args->{voucher_variant_id} = delete $args->{variant_id};
        return $self->search($args);
    }
    else {
        return $result; # no matches
    }
};

=head2 create

Extend DBIC's built-in create method. If variant_id is specified,
first try to insert it in the variant_id column, then if the database
throws an error, try to insert it in the voucher_variant_id column.

=cut

around 'create' => sub {
    my ($orig, $self, $args) = @_;

    my $variant_id = $args->{variant_id} or confess "missing parameter variant_id";
    if ($self->result_source->schema->resultset('Public::Variant')->find($variant_id)) {
        # it's a normal variant, don't change anything
        # (i.e. allow variant ID to be matched against the variant_id column)
    }
    elsif ($self->result_source->schema->resultset('Voucher::Variant')->find($variant_id)) {
        # it's a voucher, match the variant ID against the voucher_variant_id column
        $args->{voucher_variant_id} = delete $args->{variant_id};
    }
    else {
        confess "variant ID '$variant_id' does not exist in either Public::Variant or Voucher::Variant,"
            ." cannot insert it into either variant_id or voucher_variant_id column of putaway_prep_inventory";
    }

    $self->$orig($args);
};

=head2 filter_active_inventory $customer_returns_only

Returns a filtered ppi resultset, with variant/voucher_variant and
container information prefetched.

To make this query faster you now have to choose whether you want
customer return data only or everything else.

This query explicitly doesn't use binded params because we connect to
postgres with server_side_prepare on, and that leads to a poor, generic
execution plan. So we manually escape that.

=cut

sub filter_active_inventory {
    my ($self, $customer_returns_only) = @_;

    # NOTE: This query REALLY STRUGGLES (> 1m exec time) with binded parameters
    # so I explicitly use string literals.

    my $query_restrict;
    if ($customer_returns_only) {
        $query_restrict = { '=' => \"$DELIVERY_ITEM_TYPE__CUSTOMER_RETURN" };
    } else {
       $query_restrict = [ '-or' =>  { '!=' => \"$DELIVERY_ITEM_TYPE__CUSTOMER_RETURN" }, { '=', undef } ];
    }

    # Get all the pp_inventories.
    return $self
        # Find each PP-Inventory where there's an active pp_group
        ->search({
            'putaway_prep_group.status_id' => [ -or =>
                {'=', \"$PUTAWAY_PREP_GROUP_STATUS__IN_PROGRESS" },
                {'=', \"$PUTAWAY_PREP_GROUP_STATUS__PROBLEM" },
            ],
            'delivery_item.type_id' => $query_restrict
        # Additionally grabbing the kitchen sink...
        }, {
            prefetch => [
                { 'putaway_prep_group' => [
                    { 'putaway_prep_inventories' => 'putaway_prep_container' },
                    { 'stock_processes' => {
                        'delivery_item' => [
                            'delivery',
                            { 'link_delivery_item__stock_order_items' => 'stock_order_item' },
                            { 'link_delivery_item__return_item' => 'return_item' },
                            { 'link_delivery_item__quarantine_processes' => 'quarantine_process' },
                            { 'link_delivery_item__shipment_items' => 'shipment_item' }
                        ],
                    }}
                ]},
                'outer_voucher_variant',
                { putaway_prep_container => ['operator','destination'] },
                { outer_variant => { outer_product => [ 'outer_designer', 'outer_storage_type' ] }},
                { outer_variant => { product => [ 'product_channel', 'designer', 'storage_type' ] }}
            ],
        });
}

=head2 prepare_data_for_putaway_admin

Gets some ppi rows (as returned from active_inventory_data), fetches
additional related stock_process and stock_recode information, and arranges
it in a format suitable for passing to the putaway admin handler.

Due to the messy nature of the code, the performance of the SQL dropped
and to speed it up, we've split the PutawayPrepAdmin page into two halves
to reduce the db workload. Customer Returns or everything else. When you
call this function (and you shouldn't) you need to pass in a boolean of
whether you want the customer returns data or not.

Don't bother using this function for new code. It's too difficult to debug
and it's slow and ugly. Write everything from scratch.

=cut

sub prepare_data_for_putaway_admin {
    my ($self, $customer_returns_only) = @_;

    my @inventories = $self->filter_active_inventory($customer_returns_only)->all;

    return $self->get_group_statistics_for_inventories(\@inventories);
}

=head2 get_group_statistics_for_inventories

For provided pp_inventory DBICs fetches additional related stock_process and
stock_recode information, and arranges
it in a format suitable for passing to the putaway admin handler.

Returns an array of groups (which are hashes at the highest level but also
includes dbix objects). Also returns a hash containing variant_id => sku
fields which are used to the page

This code iterates through all the putaway prep and stock related tables
creating hashes of DBIx::Class objects in a bizarre, partially duplicated,
non-obvious structure that doesn't reflect the database schema or
minimise confusion. New code should not call this function. You'd just be
shackling yourself to a high change of performance degredation and difficult
to hunt down bugs.

=cut

sub get_group_statistics_for_inventories {
    my ($self, $inventories) = @_;

    # Fetch related information about stock processes which we'll need later.
    my @stock_process_group_ids =
        uniq
        map { $_->putaway_prep_group->group_id || () }
        @$inventories;

    my $stock_processes = $self->result_source->schema->resultset('Public::StockProcess')
        ->stock_process_data_for_group_ids(\@stock_process_group_ids);

    # Recodes don't have any related stock_process data, they are linked to
    # stock_recode rows instead.
    my @stock_recode_ids =
        uniq
        map { $_->putaway_prep_group->recode_id || () }
        @$inventories;

    my $stock_recodes = $self->result_source->schema->resultset('Public::StockRecode')
        ->stock_recode_data_for_ids(\@stock_recode_ids);

    my $all_flow_statuses = $self->result_source->schema->resultset('Flow::Status')->as_lookup;

    # Returns will need some more info, so we'll keep track of Return delivery
    # ids as we process the ppi rows for fetching it later.
    my @return_delivery_ids;

    my $groups = {};

    # Now go through all the active ppi rows building up the data we want.
    for my $ppi ( @$inventories ) {

        my $pp_group = $ppi->putaway_prep_group;
        my $pp_container = $ppi->putaway_prep_container;
        my $key = $ppi->putaway_prep_group->id;

        my $group = $groups->{ $key };

        # Collate group information if it's the first time we've seen it.
        unless ( $group ) {

            # Start with the info we can get easily from the ppi row.
            $group = $ppi->inventory_group_data_for_putaway_admin($all_flow_statuses);

            # There are several things we want to do different if it has a
            # stock_process - for starters, it'll have information about
            # deliveries, and also we need to do some more digging in to its
            # type.
            if ( $pp_group->is_stock_process ) {

                my $single_stock_process = $stock_processes
                    ->{$pp_group->group_id}
                    ->{'stock_process_rows'}
                    ->[0]; # It doesn't matter which one we choose, since the design
                           # of the page assumes they're all for the same delivery
                my $delivery_item =
                    $single_stock_process->{'delivery_item'};
                my $delivery = $delivery_item->{'delivery'};

                $group->{'delivery'} = $delivery_item->{'delivery'}->{'id'};
                $group->{'delivery_date'} = DateTime::Format::Pg->parse_datetime(
                    $delivery_item->{'delivery'}->{'date'}
                );
                $group->{'quantity_expected'} = $stock_processes
                    ->{$pp_group->group_id}
                    ->{'quantity'};

                # Which type of stock are we dealing with?
                if ($delivery_item->{'type_id'} == $DELIVERY_ITEM_TYPE__CUSTOMER_RETURN) {
                    $group->{'putaway_type'} = 'Return';
                    push @return_delivery_ids, $group->{'delivery'};
                } elsif ($delivery_item->{'type_id'} == $DELIVERY_ITEM_TYPE__SAMPLE_RETURN) {
                    $group->{'putaway_type'} = 'SampleReturn';
                    push @return_delivery_ids, $group->{'delivery'};
                 } else {    # Put everything else under Main for now
                    # Main equates to 'Goods In' in the putaway_type database table
                    $group->{'putaway_type'} = 'Main';
                }

                # Is it Main or Dead? Putaway Prep page restricts by stock_process_type
                if ($single_stock_process->{type_id} == $STOCK_PROCESS_TYPE__DEAD) {
                    $group->{'stock_process_type'} = 'Dead';
                } else {
                    $group->{'stock_process_type'} = 'Main';
                }

                $group->{'pgid'} = $pp_group->canonical_group_id;
                $group->{'bare_group_id'} = $pp_group->group_id;
            } elsif ( $pp_group->is_stock_recode ) {
                # Recodes are simpler
                $group->{'quantity_expected'} = $stock_recodes
                    ->{$pp_group->recode_id}
                    ->{'quantity'};
                $group->{'putaway_type'}       = 'Recode';
                $group->{'pgid'}               = $pp_group->canonical_group_id;
                $group->{'bare_group_id'}      = $pp_group->recode_id;
                $group->{'stock_process_type'} = 'Main'; # always main
            } elsif ( $pp_group->is_cancelled_group ) {

                $group->{'putaway_type'}       = 'CancelledGroup';
                $group->{'pgid'}               = $pp_group->canonical_group_id;
                $group->{'bare_group_id'}      = $pp_group->putaway_prep_cancelled_group_id;
                $group->{'stock_process_type'} = 'Main'; # always main
            } elsif ( $pp_group->is_migration_group ) {

                $group->{'putaway_type'}       = 'MigrationGroup';
                $group->{'pgid'}               = $pp_group->canonical_group_id;
                $group->{'bare_group_id'}      = $pp_group->putaway_prep_migration_group_id;
                $group->{'stock_process_type'} = 'Main'; # always main
            }

            # Count upwards here for quantity_scanned
            $group->{'quantity_scanned'} = 0;
            # Add an empty containers hashref to store details of the container
            $group->{'container_data'} = {};
            # And an arrayref for the array the template cares about
            $group->{'containers'} = [];


            $group->{putaway_prep_group_row} = $pp_group;

            # Set a flag for whether or not the group can be removed
            # from the Admin page with no adverse effects
            $group->{'can_mark_resolved'} = $pp_group->can_mark_resolved;

            $groups->{ $key } = $group;
        }

        my $container = $group->{'container_data'}->{ $pp_container->id };

        # Add container information if it's the first time we've seen this
        # container for this group...
        unless ( $container ) {
            $container = $pp_container->container_data_for_putaway_admin;

            # We'll add each pp_inventory's quantity to this
            $container->{'quantity_scanned'} = 0;

            # Put this inside the group object
            $group->{'container_data'}->{ $pp_container->id } = $container;
            # And push the container ref onto the group's array of containers
            push @{$group->{'containers'}}, $container;

            # Set the last_action for the group to the last_scan_time for
            # this container, unless it's already later.
            unless ($group->{'last_action'} && (
                DateTime->compare(
                    $group->{'last_action'}, $container->{'last_scan_time'}
                ) == 1
            )) {
                $group->{'last_action'} = $container->{'last_scan_time'};
            }
        }

        if ( $group->{putaway_type} eq 'CancelledGroup' ) {
            $container->{content} //= [];
            my ( $variant, $designer );

            # the reason why following block was not factored out into separate
            # method on "putaway prep container" row is: we rely on prefetched reletions
            # of "putaway prep container" row object to get all necessary data
            # and to reduce number of database queries.
            if ($ppi->is_voucher) {
                $variant  = $ppi->outer_voucher_variant;
                $designer = '-';
            } else {
                $variant  = $ppi->outer_variant;
                $designer = $variant->product->designer->designer;
            }
            push @{ $container->{content}  },
                {
                    designer_name => $designer,
                    sku           => $variant->sku,
                    quantity      => $ppi->quantity,
                    product_id    => $variant->product_id,
                };
        }

        # Add the quantity from this pp_inventory to the container and group's
        $group->{'quantity_scanned'} += $ppi->quantity;
        $container->{'quantity_scanned'} += $ppi->quantity;

        # for groups based on "Cancelled group" - we expect exactly same quantity
        # as was scanned in fact; this is because we cannot determine how many
        # items we expect
        $group->{quantity_expected} = $group->{quantity_scanned}
            if $pp_group->is_cancelled_group;

    }

    # Now fetch RMA numbers for all deliveries belonging to Return groups -
    # we're waiting until now because before we processed them all we didn't
    # have an easy way to get a delivery id for each one.
    my $rma_numbers = $self->result_source->schema->resultset('Public::Return')
        ->delivery_id_to_rma_number(\@return_delivery_ids);
    SMARTMATCH: {
        use experimental 'smartmatch';
        # And populate the Return group data with this information.
        foreach my $group (values %$groups) {
            if ( $group->{'putaway_type'} ~~ [qw/Return SampleReturn/] ) {
                $group->{'rma_number'} = $rma_numbers->{$group->{'delivery'}};
            }
        }
    }

    # Now lookup all SKUs in a single query.
    my $variant_ids_to_resolve = {};

    foreach my $group (values %$groups) {
        if ($group->{putaway_prep_group_row}->can_mark_resolved) {
            my @group_variant_ids = keys %{$group->{putaway_prep_group_row}->cached_expected_quantities//{}};
            $variant_ids_to_resolve->{$_} = 1 foreach @group_variant_ids;
        }
    }

    return $groups;
}

1;
