
package XTracker::Schema::ResultSet::Public::Shipment;
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';

use Moose;
use MooseX::NonMoose;
with "XTracker::Schema::Role::ResultSet::GroupBy";
with 'XTracker::Role::AccessConfig';

use DateTime;
use DateTime::Format::DateParse;
use Carp qw/ croak /;
use MooseX::Params::Validate;

use XTracker::Config::Local     qw(
    config_var get_ups_qrt
);
use XTracker::Constants::FromDB qw(
    :shipment_status :shipment_item_status :shipment_type
    :customer_category
    :shipment_class
    :allocation_status
    :allocation_item_status
    :fulfilment_overview_stage
);

use XT::Data::DateStamp;
use XTracker::Schema::Result::Public::ShipmentClass;
has 'use_wms_priority_fields' => (
    is      => 'ro',
    isa     => 'Bool',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return $self->get_config_var('SOS', 'enabled');
    },
);

=head1 NAME

XTracker::Schema::ResultSet::Public::Shipment

=head1 METHODS

=cut

sub all_shipment_item_rs {
    my $self = shift;
    $self->result_source->schema->resultset('Public::ShipmentItem')
}

=head2

List of Shipment statuses that indicate the shipment is on hold.

=cut

sub hold_status_list {
    return [
        $SHIPMENT_STATUS__RETURN_HOLD,
        $SHIPMENT_STATUS__FINANCE_HOLD,
        $SHIPMENT_STATUS__EXCHANGE_HOLD,
        $SHIPMENT_STATUS__HOLD,
        $SHIPMENT_STATUS__DDU_HOLD,
        $SHIPMENT_STATUS__PRE_DASH_ORDER_HOLD,
    ];
}

=head2 packing_summary

=cut

sub packing_summary {
    my $resultset = shift;

    my $list = $resultset->search(
        {
            shipment_status_id => $SHIPMENT_STATUS__PROCESSING,
            'shipment_item.shipment_item_status_id' => {
                '-in' => [
                    $SHIPMENT_ITEM_STATUS__NEW,
                    $SHIPMENT_ITEM_STATUS__SELECTED,
                    $SHIPMENT_ITEM_STATUS__PICKED,
                    $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                    $SHIPMENT_ITEM_STATUS__PACKED,
                ],
            },
        },
        {
            prefetch => [ qw/orders shipment_item/ ],
        },
    );

    #        order_by => ['start_date DESC', 'end_date DESC'],

    return $list;
}


=head2 invalid_shipments_rs

Return a result set of non-premier invalid shipments
UPS shipments are filtered by AQR% if the DC uses UPS as a carrier

=cut

sub invalid_shipments_rs {
    my $self = shift;

    my $shipment_rs = $self->search(
                    { shipment_status_id                      => { 'in' => [ $SHIPMENT_STATUS__PROCESSING, $SHIPMENT_STATUS__HOLD, $SHIPMENT_STATUS__DDU_HOLD ] },
                     'me.shipment_type_id'                    => { '-not_in' => [ $SHIPMENT_TYPE__UNKNOWN, $SHIPMENT_TYPE__PREMIER ] },
                     'shipment_items.shipment_item_status_id' => { 'in' => [ $SHIPMENT_ITEM_STATUS__NEW, $SHIPMENT_ITEM_STATUS__SELECTED, $SHIPMENT_ITEM_STATUS__PICKED, $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION, $SHIPMENT_ITEM_STATUS__PACKED ] },
                     'destination_code'                       => [ undef, '' ] ,
                     'real_time_carrier_booking'              => 0,
                    },
                    {
                        '+columns' => {
                            'order_number'     => 'orders.order_nr',
                            'orders_id'        => 'orders.id',
                            'customer_id'      => 'orders.customer_id',
                            'customer_number'  => 'customer.is_customer_number',
                            'country'          => 'shipment_address.country',
                            'sales_channel'    => 'channel.name',
                            'item_status_id'   => 'MAX(shipment_items.shipment_item_status_id)',
                            'item_status'      => 'shipment_item_status.status',
                            'status'           => 'shipment_status.status',
                            'carrier'          => 'carrier.name',
                        },
                        join     => [
                            { 'shipment_items' => 'shipment_item_status' },
                            'shipment_address',
                            'shipment_status',
                            { link_orders__shipments => {
                                orders => [
                                    'customer', 'channel'
                                ] }
                            },
                            { shipping_account => 'carrier' },
                        ],
                        group_by => [
                            $self->aliased_columns,
                            'orders.id',
                            'shipment_address.country',
                            'channel.name',
                            'orders.order_nr',
                            'orders.customer_id',
                            'customer.is_customer_number',
                            'shipment_item_status.status',
                            'shipment_status.status',
                            'carrier.name'
                        ],
                    }
                );

    $shipment_rs = $self->filter_above_qr_threshold($shipment_rs) if ( config_var( 'UPS', 'enabled' ) );

    return $shipment_rs;

}

=head2 filter_above_qr_threshold

Filters a result set of shipments to remove any UPS shipments that have an average
quality rating that is >= to the threshold for the relevant channel
A filtered result set is returned

=cut


sub filter_above_qr_threshold {
    my ( $self, $shipment_rs ) = @_;

    my $channel_config = $self->result_source->schema->resultset('Public::Channel')->get_channel_config();

    # store the Quality Rating Threshold for each channel
    my %qrt;
    foreach ( keys %{ $channel_config } ) {
        $qrt{ $_ }  = get_ups_qrt( $channel_config->{$_} ) * 100;
    }
    my @filtered_rows;
    while ( my $row = $shipment_rs->next ) {
        my $avqr    = ( $row->av_quality_rating || 0 ) * 100;
        # if the shipment's address quality rating is >= to that channels threshold then don't want it
        next if $row->carrier_is_ups && $avqr >= $qrt{ $row->get_column('sales_channel') };
        push @filtered_rows, $row;
    }
    my $filtered_rs = $self->result_source->resultset;
    $filtered_rs->set_cache(\@filtered_rows);
    return $filtered_rs;
}


=head2 invalid_shipments( C<$channel_config_hash_ref> )

This gets a hash containing all shipments (not premier & not dispatched)
which have failed Address Validation.

DHL shipments are missing the destination code having gone through the DHL
Address Validation process.

UPS shipments have the ability to be processed using Carrier Automation but have
failed the UPS Address Validation process with an Address Quality level lower
than the threshold in the configuration file.

The data structure is a hash reference containing shipment data, with the channel
name, carrier name and epoch time difference between SLA cutoff and now (used for
sorting on the UI)as the keys. An example is provided below:

{   'NET-A-PORTER.COM' => {
        'DHL Express' =>{
            '-124566' =>{
                '236371' =>{
                    'order_id' => 219991,
                    'status' => 'On Hold',
                    'shipment_date' => '16/10/2014'
                }
            }
        }
    }
};

=cut

sub invalid_shipments {
    my $self            = shift;

    my %shipment_list;

    my $ups_enabled = config_var( 'UPS', 'enabled' );

    my $shipment_rs = $self->invalid_shipments_rs();

    while ( my $row = $shipment_rs->next ) {

        my $time_now = $self->result_source->schema->db_now();
        my $time_now_epoch = $time_now->epoch();
        my $sla_cutoff = $row->sla_cutoff;
        my $sla_countdown = $self->sla_countdown_display_format($sla_cutoff, $time_now);
        my $sla_sort_parameter = $sla_cutoff ? $sla_cutoff->epoch() - $time_now_epoch : $time_now_epoch;

        my $sales_channel   = $row->get_column('sales_channel');
        my $avqr    = ( $row->av_quality_rating || 0 ) * 100 . "%"; ## no critic(ProhibitMismatchedOperators)
        my $is_ups_carried = $ups_enabled && $row->carrier_is_ups;

        # shipment is processing - use item status
        my $status = $row->get_column( $row->is_processing ? 'item_status' : 'status' );
        $shipment_list{ $sales_channel }{$row->get_column('carrier')}{ $sla_sort_parameter }{ $row->id } = {
                    order_id        => $row->get_column('orders_id'),
                    sla_countdown   => $sla_countdown,
                    status          => $status,
                    order_number    => $row->get_column('order_number'),
                    customer_id     => $row->get_column('customer_id'),
                    customer_number => $row->get_column('customer_number'),
                    country         => $row->get_column('country'),
                    ( $is_ups_carried ? (
                                ship_addr       => join(",",$row->shipment_address->towncity,$row->shipment_address->county,$row->shipment_address->postcode),
                                avq_rating      => $avqr,
                                shipment_date   => $row->date->mdy('/'),
                            ) : ( shipment_date => $row->date->dmy('/') ) ),
                };
    }
    return \%shipment_list;
}

=head2 sla_countdown_display_format

Helper method that returns the signed difference between the SLA cutoff and the
current time in a format suitable for display, e.g. -7 day(s), 10:39

=cut

sub sla_countdown_display_format {
    my ( $self, $sla_cutoff, $time_now ) = @_;
    return 'Not set' unless $sla_cutoff;
    my $sla_diff = $sla_cutoff->subtract_datetime($time_now);
    my $dt_format = DateTime::Format::Duration->new(
        pattern => ($sla_diff->in_units( 'months' ) ? '%m months(s), ' : q{}) . ($sla_diff->in_units( 'days' ) ? '%e day(s), ' : q{}) . '%H:%M',
        normalise => 1
    );
    return $dt_format->format_duration($sla_diff);
}


=head2

Return a list of the container IDs that this shipment's items are distributed across.

=cut

sub container_ids {
    return shift->search_related('shipment_items',
        undef,
        {
            select => [ { distinct => 'container_id' } ],
            as     => [ 'container_id' ]
        }
    )->get_column('container_id')->all;
}

sub containers {
    return shift->search_related('shipment_items')
                ->search_related('container');
}

# Note: $ready_dt needs to be in UTC
sub nominated_day_possible_sla_breach {
    my($self, $ready_dt) = @_;
    my $condition = {
        'me.shipment_status_id' => $SHIPMENT_STATUS__PROCESSING,
        'shipment_items.shipment_item_status_id' => $SHIPMENT_ITEM_STATUS__NEW,
        # we don't care about our staff's deliveries ;)
        'customer.category_id' => { '!=' => $CUSTOMER_CATEGORY__STAFF },
        # this is how we know its a nominated day shipment
        'me.nominated_delivery_date' => { q{!=} => undef },
        'me.sla_cutoff' => {
            # point where now()+time_needed_process_order_for_dispatch
            '<'        => $ready_dt,
            # ignore slas that have past - that's a different case
            '>'        => \'NOW()',
            # if it doesn't have an sla then its too old
            q{!=}      => undef,
         },
    };

    my $set = $self->search_rs(
        $condition, {
        join => [
            'shipment_items',
            { shipping_account => ['carrier'] },
            { link_orders__shipments => [ { orders => ['customer'] }, ], },
        ],
    });

    return $set;
}

sub nominated_day_sla_breach {
    my($self) = @_;
    my $condition = {
        'me.shipment_status_id' => $SHIPMENT_STATUS__PROCESSING,

        # we don't care about our staff's deliveries ;)
        'customer.category_id' => { '!=' => $CUSTOMER_CATEGORY__STAFF },
        # this is how we know its a nominated day shipment
        'me.nominated_delivery_date' => { q{!=} => undef },


        'me.sla_cutoff' => {
            # it has defeinitely passed its sla_cutoff
            '<'        => \'NOW()',
            # if it doesn't have an sla then its too old
            q{!=}      => undef,
         },
    };

    my $set = $self->search_rs(
        $condition, {
        join => [
            'shipment_items',
            { shipping_account => ['carrier'] },
            { link_orders__shipments => [ { orders => ['customer'] }, ], },
        ],
    });

    return $set;
}


=head2 nominated_day_shipments_summary({ :$query_day_count, :$report_day_count }) : @$date_shipment_resultsets

Create a daily report by querying up to $query_day_count days and
returning a total of $report_day_count dates. The resulting records
for the dates not included in the $query_day_count are empty. This is
to avoid making expensive queries for dates we know there aren't any
orders.

Return array ref with hash refs with (keys: date; set (Shipment
resultset)), one for each $query_day_count, starting with today.

    [
        {
            date => $datetime,
            set  => $rs,
        },
        ...
    ]

In addition, add dates up to $report_day_count, with empty resultsets.

=cut

sub nominated_day_shipments_summary {
    my ($self, $args) = @_;

    my $days = $args->{query_day_count};
    my $today = XT::Data::DateStamp->today;

    my @summary;
    for my $i (0 .. $days-1) {
        my $date = $today->clone->add( days => $i );

        my $date_summary = {
            date => $date,
            set => $self->nominated_to_dispatch_on_day($date),
            cap => $args->{daily_shipment_cap},
        };

        push @summary, $date_summary;
    }

    # Fill the report up to report_day_count with 0 for each day
    my $last_date = $summary[-1]->{date};
    my $empty_rs = $self->search_literal("1 = 0");
    while(scalar @summary < $args->{report_day_count}) {
        $last_date = $last_date->clone->add(days => 1);
        push(
            @summary,
            {
                date => $last_date,
                set  => $empty_rs,
                cap  => $args->{daily_shipment_cap},
            }
        )
    }

    return @summary if (wantarray);
    return \@summary;
}

=head2 premier

Filter the resultset to include only premier shipments

=cut

sub premier {
    my($self) = @_;
    return $self->search_rs({
        shipment_type_id => $SHIPMENT_TYPE__PREMIER,
    });
}

=head2 non_premier

Filter the resultset to include only non premier shipments

=cut

sub non_premier {
    my($self) = @_;
    return $self->search_rs({
        shipment_type_id => { '!=' => $SHIPMENT_TYPE__PREMIER },
    });
}

=head2 sample

Filter the resultset to include only sample shipments

=cut

sub sample {

    return shift->search_rs({
        shipment_class_id => { '-in' => XTracker::Schema::Result::Public::ShipmentClass->get_sample_classes }
    });
}

sub nominated_day_status_count_for_day {
    my($self,$date) = @_;
    my $statuses = $self->result_source->schema
        ->resultset('Public::ShipmentItemStatus')->search(undef,{
            order_by => 'id DESC',
        });

    # create a lookup map
    my $status_map;
    foreach my $status ($statuses->all) {
        $status_map->{$status->id} = $status->status;
    }


    # count the sets we have
    my $set = $self->nominated_to_dispatch_on_day($date);
    my @status;
    my $shipment_count;
    foreach my $method (qw/premier non_premier/) {
        my @status_ids = map {
            $_->shipment_items->get_column('shipment_item_status_id')->min
        } $set->$method()->all;

        foreach my $status_id (@status_ids) {
            $shipment_count->{$status_id}->{$method}++;
        }
    }


    # prepare it for returning
    my @data;
    my $total = {
        premier => 0,
        non_premier => 0,
    };
    foreach my $status_id  (sort keys %{$shipment_count}) {
        my $status_data = $shipment_count->{$status_id};
        $status_data->{label} = $status_map->{$status_id};

        foreach my $method (qw/premier non_premier/) {
            $status_data->{$method} //= 0;
            $total->{$method} += $status_data->{$method};
        }
        push @data, $status_data;
    }

    return {
        status => \@data,
        total => $total,
    };
}

sub nominated_to_dispatch_on_day {
    my($self,$date) = @_;

    return $self->search_rs({
        'timestamp_to_date(nominated_dispatch_time)' => $date->ymd,
    });
}

=head2 get_prl_totals

Total the shipment items for each prl in this resultset

    return - $prl_totals : Hashref where key=prl name, value = total shipment items for this prl

=cut

sub get_prl_totals {
    my ($self) = @_;

    # Avoid infinite loop that can be caused if a 'virgin' resultset object is passed
    my $search_rs = $self->search();

    my $prl_totals = {};
    while (my $shipment = $search_rs->next) {

        my $items_by_prl = $shipment->get_items_by_prl_name();
        for (keys %$items_by_prl) {
            $prl_totals->{$_} += scalar @{$items_by_prl->{$_}};
        }
    }
    return $prl_totals;
}

use Readonly;
Readonly my $CUSTOMER_ORDERS => 1;
Readonly my $TRANSFER_ORDERS => 2;
Readonly my @VALID_SELECTION_TYPES => ($CUSTOMER_ORDERS, $TRANSFER_ORDERS);

=head2 get_transfer_selection_list

Returns a resultset of transfer (sample) shipments that are valid for 'selection', they will be in priority order

    param - $args : Hashref of optional parameters:
        exclude_non_prioritised_samples - (Default=0), if set to 1, transfer shipments without the 'is_prioritised'
        flag set will filtered from the results

    return - $shipments : A resultset of transfer shipments, this is context sensitive in the same way as a
        resultset->search() call

=cut

sub get_transfer_selection_list {
    my ($self, $args) = @_;
    return $self->_get_selection_list({ %{$args||{}}, selection_type => $TRANSFER_ORDERS, });
}

=head2 get_order_selection_list

Returns a resultset of non transfer (sample) shipments that are valid for 'selection', they will be in priority order

    param - $args : Hashref of optional parameters:
        exclude_held_for_nominated_selection - (Default=0), if 0, nominated day shipments that have not yet reached their
            nominated_earliest_selection_time will be included, but assigned lower priority than any other shipment.
            If 1, those shipments will be excluded from the list entirely

    return - $shipments : A resultset of transfer shipments, this is context sensitive in the same way as a
        resultset->search() call

=cut

sub get_order_selection_list {
    my ($self, $args) = @_;
    return $self->_get_selection_list({ %{$args||{}}, selection_type => $CUSTOMER_ORDERS, });
}

sub get_pick_scheduler_selection_list {
    my ($self, $args) = @_;
    $args //= {};
    return $self->_get_selection_list({
        %$args,
        allocation_statuses => [
            $ALLOCATION_STATUS__ALLOCATED,             # should be picked (All)
            $ALLOCATION_STATUS__STAGED,                # wants pack space at induction (Full)
            $ALLOCATION_STATUS__ALLOCATING_PACK_SPACE, # wants pack space (GOH)
        ],
        allocation_item_statuses => [
            $ALLOCATION_ITEM_STATUS__ALLOCATED, # should be picked (All)
            $ALLOCATION_ITEM_STATUS__PICKED,    # wants pack space (GOH)
        ],
        shipment_statuses => [
            $SHIPMENT_STATUS__PROCESSING,   # still processing (All)
            $SHIPMENT_STATUS__CANCELLED,    # may need to be prepared if cancelled after picking (GOH)
        ],
        shipment_item_statuses => [
            $SHIPMENT_ITEM_STATUS__NEW,         # Allocated (All)
            $SHIPMENT_ITEM_STATUS__SELECTED,    # Picking, allocating (All)
            $SHIPMENT_ITEM_STATUS__PICKED,      # Staged (Full)
            $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,  # may need to be prepared if cancelled after picking (GOH)
        ],
    });
}

=head2 get_selection_list( $args )

Like L<get_transfer_selection_list> and L<get_order_selection_list> but doesn't
filter by C<shipment_class_id>.

    param - $args : Hashref of optional parameters:
        prioritise_samples - (Default=0), if 1, sample-shipments will be prioritised higher
            in the returned list than non-sample shipments


=cut

sub get_selection_list { $_[0]->_get_selection_list($_[1]); }

sub _get_selection_list {
    my ($self, $args) = @_;
    $args //= {};

    my $exclude_held_for_nominated_selection = $args->{exclude_held_for_nominated_selection} || 0;
    my $exclude_non_prioritised_samples = $args->{exclude_non_prioritised_samples} || 0;
    my $prioritise_samples = $args->{prioritise_samples} || 0;
    my $selection_type = $args->{selection_type};
    my $shipment_statuses = $args->{shipment_statuses}
        // $SHIPMENT_STATUS__PROCESSING;
    my $shipment_item_statuses = $args->{shipment_item_statuses}
        // $SHIPMENT_ITEM_STATUS__NEW;
    my $allocation_statuses = $args->{allocation_statuses}
        // $ALLOCATION_STATUS__ALLOCATED;
    my $allocation_item_statuses = $args->{allocation_item_statuses}
        // $ALLOCATION_ITEM_STATUS__ALLOCATED;


    # We need to filter the shipments to only those that contain
    # shipment items in 'new' status (or also 'selected' in the case
    # of the pick scheduler)
    my $items = $self->all_shipment_item_rs->search({
        'me.shipment_item_status_id' => $shipment_item_statuses,
    });

    # In addition, if using PRLs we only want shipments that have PRL
    # allocated shipment_items
    my $using_prls = config_var('PRL','rollout_phase');
    if($using_prls) {
        $items = $items->search(
            {
                'allocation_items.status_id' => $allocation_item_statuses,
                'allocation.status_id'       => $allocation_statuses,
            },
            {
                join => { allocation_items => 'allocation' },
            }
        );
    }

    my $rs = $self;
    # If we have a selection type restrict our resultset by shipment_class_id
    if ( defined $selection_type ) {
            croak "Invalid \$selection_type '$selection_type'"
                unless grep { $_ == $selection_type } @VALID_SELECTION_TYPES;
        $rs = $rs->search({ shipment_class_id => {
            ( $selection_type == $CUSTOMER_ORDERS ? '<>' : '=' ) => $SHIPMENT_CLASS__TRANSFER_SHIPMENT,
        }});
    }

    # We want the $exclude* flag to be 0 when we're listing the items - so we
    # see them all. We want it to be 1 when we're selecting items, so we only
    # pick nominated shipments that are past their earliest selection date
    $rs = $rs->search({
        nominated_earliest_selection_time => [ undef, { q{<=} => \'NOW()' } ]
    }) if $exclude_held_for_nominated_selection;

    $rs = $rs->search({
        -or => {
            is_prioritised => 1,
            # This filter only applies to transfer_shipments
            shipment_class_id => { '<>' => $SHIPMENT_CLASS__TRANSFER_SHIPMENT }
        },
    }) if $exclude_non_prioritised_samples;

    my $me = $self->current_source_alias;
    my $is_held_sql = $self->_get_is_held_sql();
    my $epoch_sort_sql = $self->_get_epoch_sort_sql();
    my $is_sample_sql = $self->_get_is_sample_sql();

    return $rs->search(
        {
            'shipment_status_id' => $shipment_statuses,
            "${me}.id"           => { -in => $items->get_column('shipment_id')->as_query },
        },
        {
            # Nominated day shipments that have not reached their earliest selection time are always given lowest priority
            # (Non-nominated day shipments and those that have reached their earliest selection time are equal)
            '+columns' => [
                { held => \$is_held_sql, },
                { cutoff => \'date_trunc(\'second\',sla_cutoff - current_timestamp)' },
                { cutoff_epoch => \'extract(epoch from (sla_cutoff - current_timestamp))' },
                { epoch_sort => \$epoch_sort_sql },
                ( $prioritise_samples ? ({ is_sample => \$is_sample_sql }) : () ),
            ],
        },
    )->sort_for_selection({
        prioritise_samples => $prioritise_samples,
    });
}

sub sort_for_selection {
    my ($self, $prioritise_samples) = validated_list(\@_,
        prioritise_samples  => { isa => 'Bool', default => 0 },
    );

    my $me = $self->current_source_alias;
    my $is_sample_sql = $self->_get_is_sample_sql();
    my $is_held_sql = $self->_get_is_held_sql();
    my $wms_priority_sql = $self->_get_wms_priority_sql();
    my $epoch_sort_sql = $self->_get_epoch_sort_sql();

    return $self->search({}, {
        order_by => (
            $self->use_wms_priority_fields()
                ? [
                    ( $prioritise_samples ? ({ -desc => \$is_sample_sql }) : () ),
                    \$is_held_sql,
                    {-desc => 'is_prioritised'},
                    \$wms_priority_sql,
                    $epoch_sort_sql,
                    'wms_deadline',
                    "${me}.id",
                ]

                : [
                    ( $prioritise_samples ? ({ -desc => \$is_sample_sql }) : () ),
                    \$is_held_sql,
                    {-desc => 'is_prioritised'},
                    'sla_priority',
                    \$epoch_sort_sql,
                    "${me}.id",
                ]
        ),
    });
}

sub _get_is_sample_sql { "(CASE WHEN shipment_class_id = $SHIPMENT_CLASS__TRANSFER_SHIPMENT THEN 1 ELSE 0 END)"; }
sub _get_is_held_sql { '(CASE WHEN nominated_earliest_selection_time IS NOT NULL THEN (CASE WHEN extract(epoch from (nominated_earliest_selection_time - current_timestamp)) > 0 THEN 1 ELSE 0 END) ELSE 0 END)' }
sub _get_wms_priority_sql { '(CASE WHEN wms_bump_deadline IS NOT NULL AND wms_bump_deadline <= NOW() THEN wms_bump_pick_priority ELSE wms_initial_pick_priority END)' }
sub _get_epoch_sort_sql { '(CASE WHEN sla_cutoff IS NULL THEN 0 ELSE extract(epoch from(sla_cutoff - current_timestamp)) END) + 1000000000' }

=head2 not_cancelled

    $result_set = $self->not_cancelled;

Returns a Result Set for All Shipments that have NOT been Cancelled.

=cut

sub not_cancelled {
    my $self    = shift;
    return $self->search( { shipment_status_id => { '!=' => $SHIPMENT_STATUS__CANCELLED } } );
}

=head2 yet_to_be_dispatched

Filters the resultset to include only those shipments that are still expected to be
 dispatched, but have not yet. (e.g. Anything that has not been cancelled or has already
 left the warehouse)

=cut
sub yet_to_be_dispatched {
    my ($self) = @_;
    my $alias = $self->current_source_alias;
    return $self->search({
        "$alias.shipment_status_id" => { -in => [
            $SHIPMENT_STATUS__PROCESSING,
            @{ $self->hold_status_list },
        ]},
    });
}

sub with_items_between_picking_and_dispatch {
    my ($self) = @_;
    my $alias = $self->current_source_alias;
    return $self->search({
        'shipment_items.shipment_item_status_id' => { -in => [
            $SHIPMENT_ITEM_STATUS__PICKED,
            $SHIPMENT_ITEM_STATUS__PACKED,
            $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
            $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
        ]}
    },{
        join => 'shipment_items',
    });
}

sub with_items_selected {
    my ($self) = @_;
    my $alias = $self->current_source_alias;
    return $self->search({
        'shipment_items.shipment_item_status_id' => { -in => [
            $SHIPMENT_ITEM_STATUS__SELECTED,
        ]}
    },{
        join => 'shipment_items',
    });
}

sub filter_on_hold {
    my ($self) = @_;
    return $self->search({
        shipment_status_id => { 'in' => $self->hold_status_list },
    });
}

=head2 staged_status_ids() : $status_ids

Return arrayref of $status_ids for when the Shipment is "staged".

=cut

sub staged_status_ids {
    return [ $SHIPMENT_STATUS__PROCESSING, $SHIPMENT_STATUS__HOLD ];
}

=head2 staged_shipments

Return the number of distinct shipments are currently being processed
(or on hold) and have staged allocations.

=cut

sub staged_shipments {
    my ($self) = @_;
    my $me = $self->current_source_alias;
    return $self->search({
        "allocations.status_id"  => $ALLOCATION_STATUS__STAGED,
        "$me.shipment_status_id" => { "in" => $self->staged_status_ids },
    },{
        join     => "allocations",
        distinct => 1,
    });
}

=head2 get_fulfilment_overview_list : $result_set

Returns a Result Set for Shipments that have an sla_cutoff and carrier that correspond
to a particular truck departure. Sample, staff and on hold shipments are excluded.

The list for late shipments is generated if no carrier_ids are provided in the args.

=cut

sub get_fulfilment_overview_list {
    my ($self, $args) = @_;

    my $condition = {
        'me.shipment_class_id'     => { '!=' => $SHIPMENT_CLASS__SAMPLE },
        ( $args->{carrier_ids} ?
            ('carrier.id'  => { "in" => $args->{carrier_ids} },
             'me.sla_cutoff'  => $args->{sla_cutoff},
             'me.shipment_status_id'    => { '!=' => $SHIPMENT_STATUS__HOLD },
            ) :
            ('me.sla_cutoff'         => { '<=' => \'NOW()' },
             'me.shipment_status_id' => $SHIPMENT_STATUS__PROCESSING,
            )
        ),
        'customer.category_id'     => { '!=' => $CUSTOMER_CATEGORY__STAFF },
    };
    return $self->search(
        $condition, {
        join => [
            { shipping_account => ['carrier'] },
            { link_orders__shipments => {
                orders => [
                    'customer', { channel => 'business' }
                ] } },
        ],
    });
}

=head2 search_by_channel_ids

Returned a filterd list/rs of shipments that are associated with one of the given channel_ids

param - $channel_ids : An arrayref of channel_ids to filter by

return - $resultset/@shipments : Filtered resultset or list (context dependent) of shipments

=cut
sub search_by_channel_ids {
    my ($self, $channel_ids) = @_;
    return $self->search({
        "orders.channel_id" => $channel_ids
    }, {
        join => { link_orders__shipments => 'orders' }
    });
}

=head2 get_shipment_item_statuses : $shipment_item_statuses

Takes a parameter of an arrayref of shipments and returns a HashRef with
(keys: fulfilment_overview_stage.id, values: number of shipments)

=cut

sub get_shipment_item_statuses {
    my ( $self, $shipments ) = @_;

    my @shipment_objects = @{ $shipments };
    my @shipment_ids;
    my $shipments_dispatched = 0;
    for my $shipment ( @shipment_objects ) {
        $shipments_dispatched++ if $shipment->is_dispatched;
        push @shipment_ids, $shipment->id;
    }
    my $shipment_items_rs = $self->all_shipment_item_rs->search(
        {
            'me.shipment_id' => { 'in' => \@shipment_ids },
        },
        {   'join'     => [
                'shipment_item_status',
                { 'allocation_items' => { 'allocation' => 'prl' }},
            ],
            '+columns' => {
                            'fulfilment_overview_stage'    => 'shipment_item_status.fulfilment_overview_stage_id',
                            'prl_name'                     => 'prl.name',
                          },
       });

    my %shipment_item_statuses;
    my %prl_allocation_stages = map { $_ => 1 } ( $FULFILMENT_OVERVIEW_STAGE__AWAITING_SELECTION,
                                                  $FULFILMENT_OVERVIEW_STAGE__AWAITING_PICKING );
    while ( my $row = $shipment_items_rs->next ) {
        my $fulfilment_stage = $row->get_column('fulfilment_overview_stage');
        if ( $prl_allocation_stages{$fulfilment_stage} && config_var('PRL','rollout_phase') ) {
            my $prl_location_name = $row->get_column('prl_name') || 'N/A';
            $shipment_item_statuses{PRL}{$fulfilment_stage}{$prl_location_name}++;
        }
        elsif (config_var('Fulfilment', 'labelling_subsection') ) {
            $fulfilment_stage = $FULFILMENT_OVERVIEW_STAGE__AWAITING_LABELLING if $row->is_awaiting_labelling;
        }
        $shipment_item_statuses{$fulfilment_stage}++;
    }
    $shipment_item_statuses{'shipments_total' } = @shipment_objects;
    $shipment_item_statuses{'shipments_dispatched'} = $shipments_dispatched;
    return \%shipment_item_statuses;
}

=head2 get_historic_min_shipment_id

    $integer = $self->get_historic_min_shipment_id( $interval_string );

Return the Mimimum Shipment Id from the past.

Passing in a string that can be used in an SQL 'INTERVAL' clause get the Minimum
Shipment Id from that point in time.

use this if you want to get Shipments since X amount of time ago but don't want to
use the 'date' field as it slows the query down because it isn't as effeciant as just
getting Shipments with an Id greater than whatever this method returns.

Values for the '$interval_string' could be '25 DAYS' or '1 MONTH' see SQL docs for
more options.

=cut

sub get_historic_min_shipment_id {
    my ( $self, $interval_str ) = @_;

    return $self->search(
        {
            date => { '>=' => \"DATE_TRUNC( 'day', NOW() - INTERVAL '${interval_str}' )" },
        },
        {
            # use 'order_by' with '->first' because it's faster than
            # using 'max' as 'max' won't use the index on 'date' but
            # ordering by 'id' will and therfore is faster.
            order_by => 'id',
        }
    )->get_column('id')->first // 0;
}

=head2 get_shipments_for_variant_id

    $result_set = $self->get_shipments_for_variant_id( $variant_id, {
        # optional
        channel         => $channel_rec,
        min_shipment_id => 234566,      # get records greater or equal to this Shipment Id
        order_by        => 'me.id',     # what to sort the output by
    } );

Given a Variant Id will find all of the Shipments that have at least one item for that
Variant. It will return a distinct list of Shipments.

By using the 'channel' argument this will cause the query to link to the 'orders' table
and check against the 'channel_id' field.

=cut

sub get_shipments_for_variant_id {
    my ( $self, $variant_id, $args ) = @_;

    my $rs = $self->search(
        {
            'shipment_items_ij.variant_id' => $variant_id,
            # don't want to include Exchanges and Re-Shipments
            'me.shipment_class_id'         => $SHIPMENT_CLASS__STANDARD,
        },
        {
            join     => 'shipment_items_ij',
            distinct => 1,
        }
    );

    if ( defined $args->{min_shipment_id} ) {
        my $min_shipment_id = $args->{min_shipment_id};
        $rs = $rs->search( { 'me.id' => { '>=' => $min_shipment_id } } );
    }

    if ( my $channel = $args->{channel} ) {
        $rs = $rs->search(
            {
                'orders.channel_id' => $channel->id,
            },
            {
                # use the inner join relationship to the 'link_orders__shipment' table
                join => { link_orders__shipment_ij => 'orders' },
            }
        );
    }

    if ( my $order_by = $args->{order_by} ) {
        $rs = $rs->search( {}, { order_by => $order_by } );
    }

    return $rs;
}

=head2 get_shipment_ids_for_variant_id

    $result_set = $self->get_shipment_ids_for_variant_id( $variant_id, { ... } );

This method will use the result set method 'get_shipments_for_variant_id' and then
change it to only return the 'shipment.id' column. The parameters for this method
are the same for 'get_shipments_for_variant_id'.

=cut

sub get_shipment_ids_for_variant_id {
    my ( $self, @params ) = @_;

    return $self->get_shipments_for_variant_id( @params )
                    ->get_column('me.id');
}

1;
