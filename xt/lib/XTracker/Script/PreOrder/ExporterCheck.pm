package XTracker::Script::PreOrder::ExporterCheck;

use NAP::policy "tt", 'class';
extends 'XT::Common::Script';

with map { "XTracker::Script::Feature::$_" } qw(
    SingleInstance
    Schema
    Logger
);

sub log4perl_category { return 'PreOrder' }

use XTracker::Database;
use XTracker::Database::PreOrder qw( :utils );

use XTracker::Config::Local     qw( config_var );
use XTracker::Constants::FromDB qw( :pre_order_item_status
                                    :pre_order_status );

use IO::Interactive qw(is_interactive);


=head1 NAME

  XTracker::Script::PreOrder::ExporterCheck

=head1 SYNOPSIS

  XTracker::Script::PreOrder::ExporterCheck->invoke();

=head1 DESCRIPTION

  blah

=cut

has verbose => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has dryrun => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has webdb_hash => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub {
        return {}
    },
);

=over 4

=item B<invoke>

Script entry point

=back

=cut

sub invoke {
    my $self = shift;

    my $interval = config_var( 'PreOrder', 'export_to_order_delay' ) || '1 hour';

    $self->_log('Checking for orphaned exported PreOrderItems');

    try {
        $self->schema->txn_do(sub {
            $self->_log('Dryrun Mode: Nothing will be fixed') if ($self->dryrun);

            $self->_verbose('Running SQL query');
            my $pre_order_items = get_pre_order_items_awaiting_orders($self->schema, $interval);

            my $prepared_mysql_qry = qq{
                SELECT    1
                FROM      orders
                JOIN      order_item on orders.id = order_item.order_id
                WHERE     orders.pre_order_id = ?
                AND       order_item.sku      = ?;
            };

            $self->_log('Found '.@{$pre_order_items}.' orphaned exported PreOrderItems');

          PRE_ORDER_ITEM:
            foreach my $poi (@{$pre_order_items}) {

                $self->_verbose("\nWorking on PreOrderItem #".$poi->id.' for PreOrder #'.$poi->pre_order->id);

                my $webdb = $self->_get_connection_to_webdb($poi->pre_order->customer->channel);

                my $sth = $webdb->prepare($prepared_mysql_qry);

                $sth->execute($poi->pre_order_number, $poi->variant->sku);

                my $results = $sth->fetchrow_arrayref();

                if (defined($results) && $results->[0] == 1) {
                    $self->_verbose('Order found. No fix needed');
                }
                else {
                    # didn't find it

                    # Step 1: Delete PreOrderItem Log and set status to 'Complete'

                    $self->_verbose("Setting PreOrderItem status to 'Complete'");
                    $poi->update_status($PRE_ORDER_ITEM_STATUS__COMPLETE);

                    # Step 2: Delete PreOrder Log entry and set PreOrder status to either 'Complete' or 'Part Exported'

                    $poi->discard_changes();

                    my $po = $poi->pre_order;

                    if ($po->some_items_are_exported) {
                        $self->_verbose("Setting PreOrder status to 'Part Exported'");
                        $po->update_status($PRE_ORDER_STATUS__PART_EXPORTED);
                    }
                    else {
                        $self->_verbose("Setting PreOrder status to 'Complete'");
                        $po->update_status($PRE_ORDER_STATUS__COMPLETE);
                    }
                }
            }

            if ($self->dryrun) {
                $self->_log("\nDryrun Mode: Nothing fixed");
                die 'Dryrun Mode';
            }
            elsif (@{$pre_order_items} > 0) {
                $self->_log("\nFixed ".@{$pre_order_items}.' PreOrderItems');
            }
        });
    }
    catch {
        $self->logger->warn($_);
    };
}

sub _get_connection_to_webdb {
    my ($self, $channel) = @_;

    $self->_verbose('Checking connection to WebDB for '.$channel->web_name);

    if (defined $self->webdb_hash->{$channel->id}) {
        $self->_verbose('DB connection found for '.$channel->web_name);
    }
    else {
        $self->_verbose('Opennig DB connection to WebDB for '.$channel->web_name);

        $self->webdb_hash->{$channel->id} = XTracker::Database::get_database_handle({
            name => 'Web_Live_'.($channel->business->config_section),
            type => 'readonly',
        });
    }

    return $self->webdb_hash->{$channel->id};
}

sub _verbose {
    my ($self, $msg) = @_;

    if ($self->verbose) {
        $self->_log($msg);
    }
}

sub _log {
    my ($self, $msg) = @_;
    # don't annoy techops with pointless cron output
    return unless is_interactive;

    $self->logger->info($msg);
}
