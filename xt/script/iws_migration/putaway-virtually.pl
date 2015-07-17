#!/opt/xt/xt-perl/bin/perl
#
# FOR MIGRATION PURPOSES ONLY!  NOT FOR NORMAL USE ON A LIVE SYSTEM!!
#
# See DCEA-1389 for more details.
#
# The explanatory comment from that ticket is duplicated here:
#
#   For the live switch-over, we need to complete all putaway processes.
#
#   Those that have corresponding physical items will be put away normally, by the warehouse staff.
#
#   Those that don't, will have to be put away "virtually", and the
#   stock thus created will have to be destroyed (adjusted
#   down). Since there are a few hundred of these processes, we need a
#   program.
#
#   A way to see all the processes that need put away is:
#
#   > /tmp/putaway.lst perl -Mlib=lib \
#        -MXTracker::Stock::GoodsIn::Putaway \
#        -MData::Dump=pp <<EOF
#   print pp XTracker::Stock::GoodsIn::Putaway::get_putaway_process_groups(
#   XTracker::Database::get_database_handle({
#      name=>"xtracker_schema",type=>"transaction"
#   })
#   ,0)
#   EOF
#
#   The program should:
#
#       * for each process group:
#             o complete the put away, creating stock in some predefined location ("GI" seems sensible)
#             o adjust the stock down, with a note saying where the stock came from
#
#   To implement the first part, we can re-use the code from the stock_received consumer controller. The second part is easier.
#
#   Yes, we adjust the stock after each put away, because we want to
#   join the adjustment with the delivery / return / out-of-quarantine / whatever.
#
#   At the very least, the note should read "missing items from
#   process group $pgid"; additional information
#   (like, "delivery $id", "return $return_id for shipment $shipment_id" and the like)
#   welcome but not strictly required.
#
#   Pete did some implementation via WWW::Mechanize, but it was quite hard to make it work right.
#
#

use strict;
use warnings;
use Data::Printer;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Getopt::Long::Descriptive;
use XTracker::Config::Local;
BEGIN {
    $XTracker::Config::Local::config{'Model::MessageQueue'}{traits}=['+Net::Stomp::MooseHelpers::TraceOnly'];
    $XTracker::Config::Local::config{'Model::MessageQueue'}{args}{trace}=1;
    $XTracker::Config::Local::config{'Model::MessageQueue'}{args}{trace_basedir}='/var/data/xt_static/queue/amq_dump_dir';
}
use XTracker::Role::WithAMQMessageFactory;
use XTracker::Constants qw(
    :application
);
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :flow_status
    :stock_process_status
    :stock_action
    :putaway_type
);
use XTracker::Comms::FCP ();
use XTracker::Database qw/schema_handle/;
use XTracker::Database::Logging ();
BEGIN {
    ## no critic(ProhibitNoStrict)
    # let's disable the functions that talk to the web db, or log
    # stuff related to the web db: these putaways won't affect it
    no warnings 'redefine';
    sub XTracker::Comms::FCP::IMPORT {
        my $caller=caller();
        for my $req (@_) {
            if ($req eq 'update_web_stock_level'
                    or $req eq 'amq_update_web_stock_level') {
                no strict 'refs';
                *{"${caller}::${req}"}=sub{};
            }
        }
    };
    sub XTracker::Database::Logging::IMPORT {
        my $caller=caller();
        for my $req (@_) {
            if ($req eq 'log_pws_stock') {
                no strict 'refs';
                *{"${caller}::${req}"}=sub{};
            }
        }
    };
}
use XTracker::Stock::GoodsIn::Putaway;
use XTracker::Database::StockProcess qw/get_putaway_type/;
use XTracker::Database::StockProcessCompletePutaway qw( complete_putaway );

package FakeStockManager {
    use NAP::policy "tt", 'class';
    sub stock_update {}
};

my $msg_factory = XTracker::Role::WithAMQMessageFactory->build_msg_factory;
my $stock_manager = FakeStockManager->new();

# some useful DB-related stuff...

my $schema = schema_handle();
my $dbh = $schema->storage->dbh;

my ($opts,$usage) = describe_options(
    "%c %o [pgid1 pgid2 ...]",
    [ 'location|l=s',
      'location to use when putting things away (default: GI)',
      { default => 'GI' } ],
    [ 'pretend|P',
      q{roll-back the database at the end, don't really change anything},
      { default => 0 } ],
    [],
    [ 'help',       "print usage message and exit" ],
    {
        getopt_conf => [qw(
                              no_ignore_case
                              no_getopt_compat
                              no_auto_abbrev
                      )]
    },
);
if ($opts->help) {
    print $usage->text;
    print <<'EOF';

Putaway all incomplete process groups (or only the specified ones),
then adjust down the stock this created.
EOF
    exit 0;
}

my $virtual_putaway_location_name = $opts->location;

my $putaway_location = $schema->resultset('Public::Location')->find({ location => $virtual_putaway_location_name });

die "No Virtual Putaway location '$virtual_putaway_location_name'\n" unless $putaway_location;

die "$virtual_putaway_location_name contains stock, can't proceed"
    if ($putaway_location->quantities->get_column('quantity')->sum||0) > 0;

$putaway_location->delete_related('location_allowed_statuses');
for my $status (
    $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS,
    $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS,
    $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS,
) {
    $putaway_location->create_related('location_allowed_statuses',{
        status_id => $status,
    });
}

# and now, to work

if (@ARGV) {
    for my $pgid (@ARGV) {
        print "handling argument PGID $pgid\n";

        eval {
            do_virtual_putaway( { dbh => $dbh,
                                  schema => $schema,
                                  pgid => $pgid,
                              });
        };

        if ($@) {
            # oh, poop
            warn "PROBLEM with $pgid: $@\n";
        }
    }
    exit;
}

my $groups_to_putaway = XTracker::Stock::GoodsIn::Putaway::get_putaway_process_groups( $schema, 0 );

#p $groups_to_putaway;

foreach my $channel_name ( keys %$groups_to_putaway ) {
    my $channelized_groups = $groups_to_putaway->{$channel_name};

    foreach my $putaway_type (keys %$channelized_groups ) {
        my $typalized_groups = $channelized_groups->{$putaway_type};

        #next if $putaway_type eq 'delivery';
        #next if $putaway_type eq 'returns';
        #next if $putaway_type eq 'quarantine';
        #next if $putaway_type eq 'samples';

        foreach my $thing_id ( keys %$typalized_groups ) {
            my $process_group_data = $typalized_groups->{$thing_id};

            #next if $process_group_data->{sp_type_id} == 5; # dead

            my $pgid = $process_group_data->{group_id} || $thing_id;
            my $stock_type = $process_group_data->{type};

            print "handling $channel_name:$putaway_type:$stock_type:$pgid\n";
            #p $process_group_data;

            eval {
                do_virtual_putaway( { dbh => $dbh,
                                      schema => $schema,
                                      channel_name => $channel_name,
                                      putaway_type => $putaway_type,
                                      pgid => $pgid,
                                      process_group_data => $process_group_data } );
            };

            if ($@) {
                # oh, poop
                warn "PROBLEM with $channel_name:$putaway_type:$pgid: $@\n";
            }
        }
    }
}

$putaway_location->delete_related('location_allowed_statuses');
for my $status (
    $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
) {
    $putaway_location->create_related('location_allowed_statuses',{
        status_id => $status,
    });
}

sub do_virtual_putaway {
    my $hashref = shift;

    my ($dbh, $schema, $process_group_id)
        =  @{$hashref}{qw(dbh schema pgid)};

    # ripped from ...::XTWMS::stock_received()

    my $stock_process_rs = $schema->resultset('Public::StockProcess')->search({
        "me.group_id" => $process_group_id,
        "me.status_id" => {'!=' => $STOCK_PROCESS_STATUS__PUTAWAY}
    });

    if (!$stock_process_rs->count) {
        warn "PGID $process_group_id has no StockProcess record: why did it appear in the putaway screen?";
        return;
    }

    my @stock_processes=$stock_process_rs->all;

    my $log_stock_rs=$schema->resultset('Public::LogStock');

    $schema->txn_do( sub {
        my $putaway_type = $stock_process_rs->get_voucher
            ? $PUTAWAY_TYPE__GOODS_IN
            : get_putaway_type($dbh, $process_group_id)->{putaway_type};

        my $putaway_ref = [];
        for my $sp  (@stock_processes) {
            my  $variant_id = $sp->variant->id;
            my $putaway;
            $putaway->{id} = $sp->id;
            $putaway->{variant_id} = $variant_id;
            $putaway->{quantity} = $sp->quantity;
            $putaway->{ext_quantity} = $sp->quantity;
            $putaway->{location} = $putaway_location->location;
            $putaway->{location_id}  = $putaway_location->id;
            $putaway->{stock_process_type_id} = $sp->type_id;

            if (   $putaway_type == $PUTAWAY_TYPE__RETURNS
                || $putaway_type == $PUTAWAY_TYPE__STOCK_TRANSFER) {
                my $ret_item = $sp->delivery_item->get_return_item;
                $putaway->{return_item_id} = $ret_item->id;
                $putaway->{shipment_id} = $ret_item->shipment_item->shipment_id;
            }

            $schema->resultset('Public::Putaway')->create({
                stock_process_id => $putaway->{id},
                location_id => $putaway->{location_id},
                quantity => $putaway->{quantity},
                complete => 0,
            });

            push @$putaway_ref, $putaway;
        }

        my $lastid=$log_stock_rs->get_column('id')->max;
        complete_putaway( $schema, $stock_manager, $process_group_id, $APPLICATION_OPERATOR_ID, $msg_factory, $putaway_type, $putaway_ref );
        $log_stock_rs->search({id => { '>' => $lastid } })
            ->update({notes => "virtual putaway of lost stock, for PGID $process_group_id"});

        # ripped from ...::XTWMS::inventory_adjust()

        for my $sp  (@stock_processes) {
            my $variant_id = $sp->variant->id;
            my $quantity = $sp->quantity;
            my $status_id = $sp->stock_status_for_putaway;

            my $quant_rs = $schema->resultset('Public::Quantity')->search({
                variant_id => $variant_id,
                location_id => $putaway_location->id,
                status_id => $status_id,
                quantity => { '>=', $quantity },
            });
            my $quant_count = $quant_rs->count;
            my $quant = $quant_rs->slice(0,0)->single;

            if ($quant && $quant_count==1) {
                $quant->update({
                    quantity => \ [ 'quantity - ?', [ quantity => $quantity ] ],
                });
                $quant->discard_changes;
            }
            elsif ($quant_count==0) {
                warn "what, no stock in the Virtual Putaway location? (variant $variant_id status $status_id, at least $quantity items)";
                next;
            }
            elsif ($quant_count>1) {
                die "more than one quantity record for $variant_id; not sure what to do";
            }

            $log_stock_rs->log({
                variant_id => $variant_id,
                channel_id => $quant->channel_id,
                stock_action_id => $STOCK_ACTION__MANUAL_ADJUSTMENT,
                operator_id => $APPLICATION_OPERATOR_ID,
                quantity => -$quantity,
                notes => "clearing putaway of lost stock, for PGID $process_group_id",
            });

            if ($quant->quantity() == 0) {
                $quant->delete_and_log($APPLICATION_OPERATOR_ID);
            }

            # kill RTV quantities, if present, created by this putaway
            $schema->resultset('Public::RTVQuantity')->search({
                variant_id => $variant_id,
                location_id => $putaway_location->id,
                quantity => $quantity,
                delivery_item_id => $sp->delivery_item_id,
            })->delete;
        }

        $schema->txn_rollback if $opts->pretend;
    });
}
