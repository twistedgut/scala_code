package XT::DC::Messaging::Plugins::PRL::StockAdjust;

use NAP::policy "tt", 'class';
use Data::Dumper;

use XTracker::Config::Local qw/config_var/;
use XTracker::Constants::FromDB qw(
 :flow_status
 :putaway_prep_container_status
);
use XTracker::Constants qw/:prl_type $APPLICATION_OPERATOR_ID/;
use XTracker::Database::PutawayPrep::MigrationGroup;
use XTracker::Error;

=head1 NAME

XT::DC::Messaging::Consumer::Plugins::PRL::StockAdjust - Handle stock_adjust from PRL

=head1 DESCRIPTION

Handle stock_adjust from PRL

=head1 METHODS

=head2 message_type

Returns the name of the message

=cut

sub message_type { 'stock_adjust' }

=head2 handler

Receives the class name, context, and pre-validated payload.

=cut

sub handler {
    my ( $self, $c, $message ) = @_;

    $c->log->debug('Received ' . $self->message_type . ' with: ' . Dumper( $message ) );

    my $schema = $c->model('Schema');

    # Note: This logged data will be used in a report.
    # For logged messages of other types, see NAP::Messaging::Runner
    $schema->resultset('Public::ActivemqMessage')->log_message({
        message_type => $self->message_type,
        entity       => $message->{'sku'},
        entity_type  => 'migration sku',
        queue        => undef, # queue not available for incoming messages
        content      => $message,
    }) if $message->{'reason'} eq 'MIGRATION'; # From 'stock_adjust_reason' table in PRL

    my $args;

    # Ignore messages where update_wms is false
    return if $message->{'update_wms'} eq $PRL_TYPE__BOOLEAN__FALSE;

    # Find the name of this PRL's location from config
    my $location_name = XT::Domain::PRLs::get_location_from_amq_identifier({
        amq_identifier => $message->{'prl'},
    });
    die "No PRL found matching ".$message->{'prl'} unless (defined $location_name);

    # Set up the data we need to use to do the adjustment
    $args->{location} = $schema->resultset('Public::Location')->get_location({
        'location' => $location_name,
    });

    # We don't check the 'reason' field here because we're treating it as
    # purely a bit of text to log, and if the wording changes it shouldn't
    # make any difference to behaviour. So we check the value of the
    # 'stock_correction' field only.
    if ($message->{'stock_correction'} eq $PRL_TYPE__BOOLEAN__FALSE) {
        $args->{'moving_to_transit'} = 1;
    }

    $args->{status} = $schema->resultset('Flow::Status')->search({
        'name' => $message->{'stock_status'}
    })->first;
    die "No matching stock status found for ".$message->{'stock_status'} unless ($args->{status});

    $args->{quantity_change} = $message->{'delta_quantity'};
    $args->{sku} = $message->{'sku'};
    $args->{reason} = $message->{'reason'};
    $args->{reason} .= " - ".$message->{'notes'} if (length $message->{'notes'});
    $args->{transit_status_id} = $FLOW_STATUS__IN_TRANSIT_FROM_PRL__STOCK_STATUS;

    # We can't guarantee the user will exist in the DB, because the username
    # sent in the message comes from LDAP/AD, but in most cases we should
    # find a match. If we don't, then adjust_quantity_and_log will use its
    # default operator id.
    if ($message->{'user'}) {
        my $operator = $schema->resultset('Public::Operator')->search({
            'username' => $message->{'user'},
        })->slice(0, 0)->single;
        if ($operator) {
            $args->{operator_id} = $operator->id;
        }
    }

    # The actual work is done in adjust_quantity_and_log
    my $quantity = $schema->resultset('Public::Quantity')->adjust_quantity_and_log($args);

    if ($message->{migration_container_id}) {
        handle_migration_message($schema, $message, $args->{operator_id});
    }
}

=head2 handle_migration_message $schema, $stock_adjust_message

Special processing for stock_adjust messages that are sent when migrating stock.
Currently, we are specifically talking about migrating stock from FWPRL to DCD.

=cut

sub handle_migration_message {
    my ($schema, $message, $user_id) = @_;

    my $pp_container_row =
        putaway_prep_for_migration($schema, $message, $user_id);

    if ( $message->{migrate_container} eq $PRL_TYPE__BOOLEAN__TRUE ) {
        # send advice_message
        $pp_container_row->send_advice_to_prl({
            container_fullness => $message->{migration_container_fullness} || undef,
        });
    }
}

=head2 putaway_prep_for_migration

Extract data from the migration stock_adjust message and populate the
putaway_prep tables.

A lot of this code is lightly adapted from
XTracker::Stock::GoodsIn::PutawayPrepPackingException::_do_add_sku_to_container

=cut

sub putaway_prep_for_migration {
    my ($schema, $message, $user_id) = @_;

    my $putaway_prep_helper =
        XTracker::Database::PutawayPrep::MigrationGroup->new({
            schema => $schema,
    });

    my $container_id = NAP::DC::Barcode::Container->new_from_id_or_barcode(
        $message->{migration_container_id}
    );

    $user_id //= $APPLICATION_OPERATOR_ID;

    my $pp_container_rs = $schema->resultset('Public::PutawayPrepContainer');
    my $pp_container_row = $pp_container_rs->find_in_progress_or_start({
        container_id => $container_id,
        user_id      => $user_id,
    });

    my $group_id = $pp_container_row->putaway_prep_groups->count
        ? $pp_container_row->putaway_prep_groups->first->canonical_group_id
        : $putaway_prep_helper->generate_new_group_id;

    try {
        # Note: For migration stock_adjusts  the delta quantity is
        # always negative. So take the absolute value.
        for (1 .. abs $message->{delta_quantity}) {
            $pp_container_rs->add_sku({
                group_id     => $group_id,
                sku          => $message->{sku},
                container_id => $container_id,
                putaway_prep => $putaway_prep_helper,
            });
        }
    } catch {
        xt_warn(
            sprintf(
                q|Cannot process SKU '%s'. Reason: %s.|,
                $message->{sku}, $_
            )
        );
    };

    return $pp_container_row;
}

1;
