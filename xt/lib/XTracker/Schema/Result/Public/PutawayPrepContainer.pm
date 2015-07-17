use utf8;
package XTracker::Schema::Result::Public::PutawayPrepContainer;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.putaway_prep_container");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "putaway_prep_id_seq",
  },
  "container_id",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 255 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "putaway_prep_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "modified",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "destination",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 50 },
  "failure_reason",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "container",
  "XTracker::Schema::Result::Public::Container",
  { id => "container_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "destination",
  "XTracker::Schema::Result::Public::Location",
  { location => "destination" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "user_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "putaway_prep_inventories",
  "XTracker::Schema::Result::Public::PutawayPrepInventory",
  { "foreign.putaway_prep_container_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "putaway_prep_status",
  "XTracker::Schema::Result::Public::PutawayPrepContainerStatus",
  { id => "putaway_prep_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:XLD/zGTScoYLJZcFPQ1LyA

# Make sure "container" is transformed into instance of
# NAP::DC::Barcode::Container on the way from database
# and stringified on the way back to DB
#
use NAP::DC::Barcode::Container;
__PACKAGE__->inflate_column('container_id', {
    inflate => sub { NAP::DC::Barcode::Container->new_from_id(shift) },
    deflate => sub { shift->as_id },
});

use Moose;
with 'XTracker::Role::WithPRLs';
with 'XTracker::Role::WithAMQMessageFactory';

use feature 'switch'; # given/when
use boolean; # true/false

use MooseX::Params::Validate qw/pos_validated_list validated_list/;
use List::Util qw/first sum/;
use List::MoreUtils qw/uniq/;

use XTracker::Config::Local qw/config_var/;
use XTracker::Constants qw/
    :prl_type
    :prl_location_name
    $APPLICATION_OPERATOR_ID
/;
use XTracker::Constants::FromDB qw(
    :putaway_prep_container_status
    :business
    :stock_process_type
    :shipment_status
    :shipment_hold_reason
);
use XTracker::Logfile qw/xt_logger/;
use XTracker::Database::Product qw/get_variant_by_sku/;
use Try::Tiny;

use XT::Domain::PRLs;
use NAP::DC::Barcode::Container;

__PACKAGE__->many_to_many(
    "putaway_prep_groups",      # name of relationship I'm creating
    "putaway_prep_inventories", # the relationship I have to the link table
    "putaway_prep_group",       # the relationship the link table has to the thing I want
);

=head2 send_advice_to_prl

B<Description>

Sends C<Advice> message to PRL. Advice messages includes all necessary data
regarding to container sent from Putaway preparation in XT to Putaway in PRL.

All data required for C<Advice> is fetched based on C<PutawayPrepContainer>
record.

The PRL where advice message is going to be sent is determined based on
storage types of items in container and configuration for each PRL, part
that describes PRL acceptable storage types.

Please note, if according to storage types of container items and PRL config,
advice messages is going to be sent to more than one PRL, an exception
is thrown.

In case of successful sending of advice message, correspondent record
in putaway_prep_container table is updated with PRL destination PRL
(PRL name as it stands in configuration file).

This method honours the PRL rollout phase, so if that is not set in XTracker
config, no messages are sent.

B<parameters>

=over

=item container_fullness

Optional: String value that indicates container fullness. For possible values,
please refer to Xtracker configuration file
"PRLs > putaway_prep_container_specific_questions > container_fullness"
section.

=back

B<Returns>

1 - if message successfully sent,

UNDEF - otherwise.

If any exceptions happen in L<Net::Stomp::Producer>, they are propagated
further up.

B<Note>

Current implementation assumes that:

=over

=item

All containers have single compartment.

=item

Container completeness is not specified.

=item

Compartment configuration is not used.

=item

Expiration date is one year ahead of message creation date.

=back

B<SEE ALSO>

L<XT::DC::Messaging::Producer::PRL::Advice>

L<XT::DC::Messaging::Spec::PRL>

=cut

sub send_advice_to_prl {
    my ($self, $args) = @_;
    my ($container_fullness) = @$args{qw/container_fullness/};

    # do not send message if XT knows nothing about PRL
    return unless $self->prl_rollout_phase;

    # compose advice message content
    my %advice_data = (
        container_id => $self->container_id,
    );

    # if "container fullness" was provided - pass it to message body
    $advice_data{container_fullness} = $container_fullness if defined $container_fullness;

    # hash with putaway prep group objects, which items are going to be sent
    # within current advice message
    my %affected_pp_groups;
    # get all data regarding to each inventory item traveling in container
    my $PRL_FALSE = $NAP::DC::PRL::Tokens::dictionary{BOOLEAN}->{FALSE};
    my @inventory_details;
    foreach my $papi ($self->putaway_prep_inventories->all){
        my $variant = $papi->variant_with_voucher;
        my $stock_process_type_id = $papi->putaway_prep_group->get_stock_process_type_id;

        my $stock_status =
            $stock_process_type_id eq $STOCK_PROCESS_TYPE__MAIN
                ? $NAP::DC::PRL::Tokens::dictionary{STOCK_STATUS}->{MAIN}
            : $stock_process_type_id eq $STOCK_PROCESS_TYPE__DEAD
                ? $NAP::DC::PRL::Tokens::dictionary{STOCK_STATUS}->{DEAD}
            : $NAP::DC::PRL::Tokens::dictionary{STOCK_STATUS}->{MAIN};

        my %inv = (
            client => (
                $variant->product->get_product_channel->channel->business->id == $BUSINESS__JC
                    ? $PRL_TYPE__CLIENT__JC
                    : $PRL_TYPE__CLIENT__NAP
            ),
            sku           => $variant->sku,
            quantity      => $papi->quantity,
            returned_flag => $PRL_FALSE,
            pgid          => $papi->putaway_prep_group->canonical_group_id,
            stock_status  => $stock_status,
            returned_flag => $PRL_FALSE,
            expiration_date => DateTime->now->add(days=>365)->strftime('%FT%T%z'),
        );
        push @inventory_details, \%inv;

        # keep record of affected putaway prep groups
        $affected_pp_groups{ $papi->putaway_prep_group_id } = $papi->putaway_prep_group;
   }

    # currently we treat all containers as if they have single compartment
    $advice_data{compartments} = [{
        compartment_id    => 1,
        inventory_details => \@inventory_details,
    }];


    my $prl = XT::Domain::PRLs::get_prl_from_name({
        prl_name => $self->get_the_acceptable_prl,
    });

    $self->result_source->schema->txn_do( sub {

        # change container's status to 'in transit', if it wasn't already
        my $updated_row_count = $self->result_source->resultset->search({
            id                     => $self->id,
            putaway_prep_status_id => { '!=' => $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT},
        })->update({
            putaway_prep_status_id => $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT,
        });

        if ($updated_row_count == 0) { # Note: When no rows are updated we get 0E0,
                                       # which == 0 but evaluates to true. Really.
            # If nothing was updated that means we have already sent the
            # advice for this container, so we shouldn't really be here.
            $self->result_source->schema->txn_rollback();
            xt_logger->warn(sprintf("Not sending advice for putaway prep container [%s] because status is already IN TRANSIT", $self->id));
            return;
        }

        # send the advice message
        my $amq = $self->msg_factory;
        $amq->transform_and_send( 'XT::DC::Messaging::Producer::PRL::Advice' => {
            advice       => \%advice_data,
            destinations => $prl->amq_queue,
        });

        # save where Advice message was sent and update modified field
        $self->update({
            destination            => $prl->location->location,
            modified               => $self->result_source->schema->db_now,
        });

        # make sure each affected putaway prep group is aware that the advice
        # was sent
        $_->notice_advice_message({ container_id => $self->container_id })
            foreach values %affected_pp_groups;
    });

    return 1;
}

=head2 container_data_for_putaway_admin

Returns a hashref of container information as we want it for the
putaway admin page.

=cut

sub container_data_for_putaway_admin {
    my ($self) = @_;

    my $container_data = {
        id             => $self->container_id,
        operator       => $self->operator->name,
        status_id      => $self->putaway_prep_status_id,
        destination    => $self->destination,
        last_scan_time => $self->modified,
        failure_reason => $self->failure_reason,
        # we care only about faults detected based on response from PRL
        container_fault => ($self->get_container_fault_from_prl||''),
    };

    return $container_data;

}

# Convenience method. Remove this after renaming the column.
sub status_id { return shift->putaway_prep_status_id; }

=head2 get_prl_specific_questions

B<Description>

Based on container content, returns config data related to PRL specific question
(asked just before marking container as complete).

B<Return>

Hash reference with keys to be question's names and values - question setup.

E.g. key could be C<container_fullness>.

For more information regarding format of returned data structure refer to
C<putaway_prep_container_specific_questions> section PRL part of XTracker config.

=cut

sub get_prl_specific_questions {
    my ($self) = @_;

    # cannot determine destination PRL without any inventory:
    return {} unless $self->putaway_prep_inventories->count;

    my $acceptable_prl = $self->get_the_acceptable_prl;

    my $prls = config_var('PRL', 'PRLs');

    return $prls->{$acceptable_prl}->{putaway_prep_container_specific_questions};
}

=head2 check_answers_for_prl_specific_questions

For provided hashref with answers to PRL specific questions returns hashref with
incorrect questions.

Input structure:

    {
        <PRL_specific_question_name_1> => <value>,
        ...
        <PRL_specific_question_name_N> => <value>,
    }

Output structure:

    {
        <incorrectly_answered_PRL_specific_question_name_1> => 1,
        ...
        <incorrectly_answered_PRL_specific_question_name_M> => 1,
    }

=cut

sub check_answers_for_prl_specific_questions {
    my ($self, $proposed_answers) = @_;

    my %errors;
    my $prl_questions = $self->get_prl_specific_questions() || {};

    foreach my $question_key (keys %$proposed_answers) {

        if (
            exists ($prl_questions->{$question_key})
                and
            not (
                $proposed_answers->{$question_key}
                    and
                grep {$_->{value} eq $proposed_answers->{$question_key}}
                    values %{ $prl_questions->{$question_key}{answers} }
            )
        ) {
            $errors{$question_key} = 1;
        }

    }

    return \%errors;
}

=head2 get_the_acceptable_prl

For current container instance return the B<name> of PRL (as it stands in XTracker
configuration file) where it should be sent.

If for some reason it appears that container going to be sent to more then one PRL
- die! This is incorrect.

=cut

# Returns combination of storage types and stock statuses that are presented
# in current container.
# The result is hash ref:
#   Storage type => Stock status => 1
#
sub _get_storage_types_and_stock_statuses {
    my $self = shift;

    my $storage_types_for_this_container = {};
    foreach my $pp_inventory ($self->putaway_prep_inventories->all) {
        my $variant = $pp_inventory->variant_with_voucher;

        $storage_types_for_this_container
            ->{ $variant->product->storage_type->name }
            ->{ $pp_inventory->putaway_prep_group->get_stock_status_row->name }
                = 1;
    }

    return $storage_types_for_this_container;
}

sub get_the_acceptable_prl {
    my ($self) = @_;

    my $storage_types_for_this_container = $self->_get_storage_types_and_stock_statuses;

    my $acceptable_prls = XT::Domain::PRLs::get_prls_for_storage_types_and_stock_statuses({
        prl_configs                        => config_var('PRL', 'PRLs'),
        storage_type_and_stock_status_hash => $storage_types_for_this_container,
    });

    # advice can be sent only to a single PRL, otherwise an error has occurred
    if (1 != keys %$acceptable_prls) {
        die sprintf 'Cannot determine acceptable PRL for container (ID: %s). '
            . 'Based on storage types of items from container: %s, '
            . 'current container is not to be sent to single PRL but to %s!',
            $self->container_id, join( ', ', sort keys %$storage_types_for_this_container),
            join(', ', sort keys %$acceptable_prls);
    }

    return (keys %$acceptable_prls)[0];
}

=head2 get_container_content_statistics

B<Description>

Returns general statistics about current container content.

B<Return>

Arrayref of hashref:

[
    {
        group_id => Canonical value of group ID (could be PGID or Recode ID),
        skus => {
            <SKU_1> => quantity of this SKU_1 in current container,
            ...
            <SKU_n> => quantity of this SKU_n in current container,
        }
    },
    ...
]

Result is sorted by group ID.

=cut

sub get_container_content_statistics {
    my ($self) = @_;

    my %container_content;
    foreach my $item ($self->putaway_prep_inventories->all) {

        # get canonical value for currently processed group ID
        my $group_id = $item->putaway_prep_group->canonical_group_id;

        $container_content{ $group_id }{ $item->variant_with_voucher->sku } += $item->quantity;
    }

    my @container_content =
        map { +{group_id => $_, skus => $container_content{$_}} }
        keys %container_content;

    # return sorted results
    return [
        map { $_->[0] }
        sort { $a->[1] cmp $b->[1] }
        # extend ID's numeric part with leading zeros, so IDs have same length
        map {
            my $a=$_->{group_id};
            $a=~s/(\d+)$/sprintf('%08d',$1)/e;
            [$_, $a]
        }
        @container_content
    ];
}

=head2 get_statistics_for_related_groups

Returns array ref of hash refs with information about PGID/RGIDs related to stock
current container instance holds.

For more information about data structure please refer to
L<XTracker::Schema::ResultSet::Public::PutawayPrepInventory/get_group_statistics_for_inventories>.

=cut

sub get_statistics_for_related_groups {
    my ($self) = @_;

    my $statistics = $self->result_source->schema->resultset('Public::PutawayPrepInventory')
        ->get_group_statistics_for_inventories([
            $self->putaway_prep_inventories->all
        ]) || {};

    return [
        map {$_->[0]}
        sort { $a->[1] cmp $b->[1] }
        map {
            my $a=$_->{pgid};
            $a=~s/(\d+)$/sprintf('%08d',$1)/e;
            [$_, $a]
        }
        values %$statistics
    ];
}

=head2 get_container_fault() : $fault_hashref | ""

Return string which determines type of current container failure
(if it exists). Failure in terms of put away prep.

At the moment it supports all faults from C<get_container_fault_from_prl>
plus "NO_ADVICE_RESPONSE" and "NO_ADVICE_CONTAINER_IN_PROGRESS".

If no known error was determined - returns UNDEF.

=cut

sub get_container_fault {
    my ($self) = @_;
    my $class = ref($self);

    my $container_fault = $self->get_container_fault_from_prl;
    return $container_fault if $container_fault;

    # in case if we did not get any container faults based on advice response,
    # check other possibilities
    if ($self->putaway_prep_status_id eq $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT) {
        # no advice response?
        $container_fault = 'NO_ADVICE_RESPONSE';

    } elsif ($self->putaway_prep_status_id eq $PUTAWAY_PREP_CONTAINER_STATUS__IN_PROGRESS){
        # container was not marked as "Putaway prep completed"?
        $container_fault = $self->does_contain_only_cancelled_group
            ? 'NO_ADVICE_CANCELLED_GROUP_CONTAINER_IN_PROGRESS'
            : $self->does_contain_only_migration_group
            ? 'NO_ADVICE_MIGRATION_GROUP_CONTAINER_IN_PROGRESS'
            : 'NO_ADVICE_CONTAINER_IN_PROGRESS';
    }

    return $container_fault;
}

=head2 get_container_fault_from_prl

Return string which determines type of current container failure
(if it exists). Failure in terms of put away prep.

It shows only those errors that happened on PRL side - those which
are sent back as "failure reason" in advice_response message.

Return "BAD_CONTAINER", "BAD_SKU", "BAD_MIX", "OVERWEIGHT",
or "UNKNOWN" if failure reason is not recognised,
UNDEF if container is not in Failed status.

=cut

sub get_container_fault_from_prl {
    my ($self) = @_;

    # no fault is possible until PRL us told so
    return
        unless $self->putaway_prep_status_id eq $PUTAWAY_PREP_CONTAINER_STATUS__FAILURE;

    my $failure_reason = $self->failure_reason;
    my $fault;

    # At the moment failure reason comes as raw text from PRL, so we need to have
    # this logic here to determine the type of failure.
    # Perhaps when we start using NAP::DC::PRL constants for carrying information about
    # failure - this text analysis will go
    if ($failure_reason =~ /The PRL believes it already has the container and is using it/) {
        $fault = 'BAD_CONTAINER';
    } elsif ($failure_reason =~ /PRL has not received a container_empty since giving XT/) {
        $fault = 'BAD_CONTAINER';
    } elsif ($failure_reason =~ /SKU.+in Advice not recognised/) {
        $fault = 'BAD_SKU';
    } elsif ($failure_reason =~ /Container weight limit is/) {
        $fault = 'OVERWEIGHT';
    } elsif ($failure_reason =~ /Rules were broken in Advice message|Invalid mix detected/i) {
        $fault = 'BAD_MIX'
    }

    # following cases are not supported by PRL yet
    elsif ($failure_reason =~ /overweight|Max tote weight violation/i) {
        $fault = 'OVERWEIGHT';
    }

    # report that current "failure reason" for AdviceResponse is unrecognisable
    else {
        $fault = 'UNKNOWN';
    }

    return $fault;
}

=head2 get_advice_response_date

Return date of getting last advice response message. If advice response was not
received yet - returns undef.

=cut

sub get_advice_response_date {
    my ($self) = @_;

    return
        ( $self->is_failure || $self->is_finished )
        ? $self->modified
        : undef;
}

=head is_failure

Is the pp container status "failure"?

=cut

sub is_failure {
    my ($self) = @_;

    return $self->putaway_prep_status_id eq $PUTAWAY_PREP_CONTAINER_STATUS__FAILURE;
}

=head is_complete

Is the pp container status "complete"?

=cut

sub is_complete {
    my ($self) = @_;

    return $self->putaway_prep_status_id eq $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE;
}

=head is_resolved

Is the pp container status "resolved"?

=cut

sub is_resolved {
    my ($self) = @_;

    return $self->putaway_prep_status_id eq $PUTAWAY_PREP_CONTAINER_STATUS__RESOLVED;
}

=head is_finished

Is the pp container in an end status (i.e. "complete" or "resolved"

=cut

sub is_finished {
    my ($self) = @_;

    return $self->is_complete || $self->is_resolved;
}

=head is_in_progress

Is the pp container status "in progress"?

=cut

sub is_in_progress {
    my ($self) = @_;

    return $self->putaway_prep_status_id eq $PUTAWAY_PREP_CONTAINER_STATUS__IN_PROGRESS;
}

=head is_in_transit

Is the pp container status "in progress"?

=cut

sub is_in_transit {
    my ($self) = @_;

    return $self->putaway_prep_status_id eq $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT;
}

=head advice_response_fail($reason) :

Mark the Container as failed

=cut

sub advice_response_fail {
    my ($self, $reason) = @_;
    $self->update({
        putaway_prep_status_id => $PUTAWAY_PREP_CONTAINER_STATUS__FAILURE,
        failure_reason         => $reason,
        modified               => $self->result_source->schema->db_now,
    });
}

=head2 advice_response_success($message_factory) : | die

Process a successful advice_response message by closing the Container
and attempt to close all contained PP Groups.

Each container has several pp_inventories, each of which contain all
or part of one or more pp_groups. A pp_group in turn contains either a
series of stock_process rows, bound by their group_id (a process group
id, a single stock_recode, or a group id from cancelled in Packing
Exception).

Stock Processes:

In order to most closely mirror current XT implementation, we'll
create a Public::Putaway for each pp_inventory that references a
stock_process that we receive. When we receive the final pp_inventory
for a stock_process pp_group, we will then use XT complete_putaway
function, which 'flushes' the putaways in to sellable stock, and
closes the stock_process rows that link to the pp_group/pgid. This
flushing is the same mechanism we use when forcibly closing these
things out.

Stock Recodes:

We take no action on stock_recodes until we judge they've been
entirely putaway, at which point we update the stock in XT and on the
website. This means that for a stock_recode split across two
containers, essentially no action is taken on receipt of the first
one.

=cut

sub advice_response_success {
    my ($self, $message_factory) = @_;
    my $log = xt_logger(__PACKAGE__);
    my $schema = $self->result_source->schema;

    my $location_row = $self->destination;

    $log->info( sprintf("DCA-2625: pprep_container(id => %s, container_id => %s)->advice_response_success(location_id => %s)", $self->id, $self->container_id, $location_row->id) );

    # Update the individual quantities in a transaction.
    #
    # Don't call complete_putaway inside the transaction, as that'll
    # also be updating the web-db, and we don't want to have updated
    # web stock with no marker in the DB. Also it's easy to recover
    # from the web-db part failing, by the operator resolving a
    # putaway in XT, which reattempts the putaway process, but at a
    # group level.
    $schema->txn_do( sub {
        $self->complete( $location_row );
    } );

    my $putaway_prep_group_rs = $self->putaway_prep_groups(undef, {distinct => 1});
    for my $pp_group_row ( $putaway_prep_group_rs->all ) {
        $log->debug('pp group '.$pp_group_row->id);
        $pp_group_row->attempt_complete_putaway({
            message_factory => $message_factory,
            location_row    => $location_row,
        });
    }

    # Take shipments off hold if they contain stock which has just been migrated.
    #   They will be re-allocated.
    $self->try_to_take_shipments_off_hold;
}

=head2 try_to_take_shipments_off_hold

Take associated shipments off hold if:

    * their putaway prep group is a migration type,
    * there is no stock left in the Full PRL for any variants in the putaway prep group
    * there are no other outstanding putaway prep containers
    * they were put on hold because of "stock discrepancy"

=cut

sub try_to_take_shipments_off_hold {
    my $self = shift;
    # See also XTracker::Schema::Result::Public::Quantity->try_to_reallocate

    my @groups = $self->putaway_prep_groups;
    my @unique_groups = values %{{ map { $_->id => $_ } @groups }};
    xt_logger->debug(sub { "There are ".scalar(@unique_groups)." groups for container ".$self->id });
    foreach my $group (@unique_groups) {
        # Collect data
        my @inventories = $group->putaway_prep_inventories;
        my @variants = map { $_->variant_with_voucher } @inventories; # may have duplicates
        my @unique_variants = values %{{ map { $_->id => $_ } @variants }};
        my @shipment_items = map { $_->shipment_items } @variants;
        my @shipments = map { $_->shipment } @shipment_items;
        my @unique_shipments = values %{{ map { $_->id => $_ } @shipments }};

        xt_logger->debug(sub { "Number of shipments: ".scalar(@shipments) });
        next unless scalar(@shipments);

        # Must map to a Migration Group ID (MGID)
        xt_logger->debug(sub { "Is group ".$group->id." a migration group? ".($group->is_migration_group ? "yes" : "no") });
        next unless $group->is_migration_group;

        # Must not be any more stock in Full PRL for these SKUs
        my $is_stock_remaining = false;
        my $full_prl_location = $self->result_source->schema
            ->resultset('Public::Location')->find_by_prl($PRL_LOCATION_NAME__FULL);
        foreach my $variant (@unique_variants) {
            if ($variant->get_quantity_in_location($full_prl_location)) {
                $is_stock_remaining = true;
                last;
            }
        }
        xt_logger->debug(sub { "Is any stock remaining? ".($is_stock_remaining ? "yes" : "no") });
        next if $is_stock_remaining;

        # Must not be any outstanding advices for these SKUs
        # i.e. Other putaway_prep_containers that have not been completely put away yet, that contain SKUs in the same group.
        #   There's no stock left in Full PRL (see above), meaning this must be the last container.
        # See also Quantity->try_to_reallocate
        my @unique_container_ids = uniq map { $_->container_id } $group->putaway_prep_containers->filter_active;
        xt_logger->debug(sub { "Outstanding containers in this group: ".join(", ", @unique_container_ids) });
        next if scalar(@unique_container_ids) > 1; # if there are any *other* containers

        foreach my $shipment (@unique_shipments) {
            xt_logger->debug(sub { sprintf("Is shipment %s on hold? %s", $shipment->id, ($shipment->is_on_hold ? "yes" : "no")) });
            next unless $shipment->is_on_hold;

            xt_logger->debug(sub { sprintf("Is hold reason 'Failed Allocation'? %s",
                ($shipment->is_on_hold_for_reason($SHIPMENT_HOLD_REASON__FAILED_ALLOCATION) ? "yes" : "no")) });
            next unless $shipment->is_on_hold_for_reason($SHIPMENT_HOLD_REASON__FAILED_ALLOCATION);

            xt_logger->debug("Releasing shipment from hold.");
            $shipment->release_from_hold({
                operator_id => $APPLICATION_OPERATOR_ID,
            }); # Shipments coming off hold will automatically get allocated again
        }
    }
}

sub complete {
    my ($self, $location_row) = @_;

    my $log = xt_logger(__PACKAGE__);
    $log->info( sprintf("DCA-2625: pprep_container(id => %s, container_id => %s)->complete(location_id => %s), set putaway_prep_status_id to COMPLETE", $self->id, $self->container_id, $location_row->id) );

    $self->update({
        putaway_prep_status_id => $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE,
        modified               => $self->result_source->schema->db_now,
    });

    for my $inventory ( $self->putaway_prep_inventories ) {
        $log->info( sprintf("DCA-2625:     call pprep_inventory(%s)->start_putaway", $inventory->id) );
        $inventory->start_putaway({ location => $location_row });
    }

    return;
}

=head2 resolve

Mark current faulty container as one that was resolved.

Container should be empty.

=cut

sub resolve {
    my ($self) = @_;

    if ( $self->putaway_prep_inventories->all ) {
        die "Cannot resolve container, it still has stuff!";
    }

    $self->update({
        putaway_prep_status_id => $PUTAWAY_PREP_CONTAINER_STATUS__RESOLVED,
        modified               => $self->result_source->schema->db_now,
    }) if $self->in_storage;

    $self->container->send_container_empty_to_prls();
}

=head2 resolve_container_as_empty

Force current container to be resolved even if it still has stock in it.
Its content is removed and container is marked as resolved.

Accepts additional parameter of "user_id", so if passed the action is recorded in
Xtracker logs.

=cut

sub resolve_container_as_empty {
    my ($self, $args) = @_;

    my ($user_id) = @$args{qw/user_id/};

    if ($user_id) {
        xt_logger(__PACKAGE__)->info(sprintf
            'User %s has indicated container %s as empty',
            $user_id, $self->container_id
        );
    }

    # Record what the associated pp groups were before we delete them
    my @putaway_prep_group_rows = $self->putaway_prep_groups(undef, {distinct => 1})->all;

    # If we had already sent an advice for this container then we'll have a destination
    # location set in the db, but if not we need to choose it now based on what was in there.
    my $location_row = $self->destination;
    unless ($location_row) {
        $location_row = XT::Domain::PRLs::get_location_from_prl_name({
            prl_name => $self->get_the_acceptable_prl,
        });
    }

    $self->putaway_prep_inventories->delete;

    $self->resolve;

    if ((scalar @putaway_prep_group_rows) && (!$location_row)) {
        # This really shouldn't be the case, but if it is it's better to log an error than just die
        xt_logger->error(sprintf("Cannot complete putaways for putaway prep container [%s], failed to find suitable PRL location", $self->id));
        return;
    }

    # Complete associated stock_processes for the deleted pp groups if possible
    for my $putaway_prep_group_row ( @putaway_prep_group_rows ) {
        $putaway_prep_group_row->attempt_complete_putaway({
            message_factory => $self->msg_factory,
            location_row    => $location_row,
        });
    }

}

=head2 get_content_difference(putaway_prep_container): hasref

Return difference between contents of current container and passed one. Result respects
not only presence of SKUs but their quantities.

Returns hashref:

    {
        <SKU_1> => <QUANTITY>
        ...
        <SKU_n> => <QUANTITY>
    }

=cut

sub get_content_difference {
    my ($self, $container) = @_;

    # for provided container returns its content statistics as hashref:
    #   <SKU> => <QUANTITY>
    #
    my $get_statistics = sub {
        my $statistics = $_[0]->get_container_content_statistics;
        my %results;
        foreach my $skus (map {$_->{skus}} @$statistics){
            $results{$_} += $skus->{$_} foreach keys %$skus;
        }
        return \%results;
    };

    my ($minuend, $subtrahend) = ($get_statistics->($self), $get_statistics->($container));

    # get SKUs that are presented in current container but are missing in passed one
    foreach (keys %$subtrahend) {
        next unless $minuend->{$_};

        if ($minuend->{$_} > $subtrahend->{$_}) {
            $minuend->{$_} -= $subtrahend->{$_};
        } else {
            delete $minuend->{$_};
        }
    }

    return $minuend;
}

=head2 remove_sku($sku_string): boolean

Remove passed SKU from current container, decrements quantity if necessary.

B<Synopsis>

    $putaway_prep_container->remove_sku($sku);

B<Exceptions>

Throws an exception if the SKU is not recognised, or the SKU is not in the container.

=cut

sub remove_sku {
    my $self = shift;
    my ($sku) = pos_validated_list(\@_,
        { isa => 'Str' },
    );

    my $variant_id = get_variant_by_sku(
        $self->result_source->schema->storage->dbh, $sku
    );
    NAP::XT::Exception->throw({
        error => sprintf("Cannot recognise SKU '%s'", $sku)
    }) unless $variant_id;


    # is an item of this type already in the container?
    my $existing_item = $self->search_related('putaway_prep_inventories')
        ->search_with_variant({
            variant_id => $variant_id,
        })
        ->first;

    if ($existing_item) {
        if ($existing_item->quantity == 1) {
            $existing_item->delete;
        } else {
            # decrement quantity
            $existing_item->update({ quantity => $existing_item->quantity - 1 });
        }
    } else {
        NAP::XT::Exception->throw({
            error => sprintf(
                "Cannot remove SKU '%s', it is not in container %s",
                $sku, $self->container_id
            )
        });
    }

    if (
        $self->putaway_prep_status_id == $PUTAWAY_PREP_CONTAINER_STATUS__IN_PROGRESS
            and
        not $self->putaway_prep_inventories->count
    ) {

        # if putaway prep container is in status where putaway prep was just started
        # and has no associated inventoried - remove it from database
        $self->delete;

    } else {

        # update container modified date
        $self->update({ modified => $self->result_source->schema->db_now });
    }

    return 1;
}

=head2 update_delivery_log

Updates the delivery log to say the items are now in Putaway Prep status.

=cut

sub update_delivery_log {
    my ($self, $delivery_action_id) = @_;

    # This diagram is what the relationship looks like.
    #
    # putaway_prep_container
    #      |-> putaway_prep_inventory
    #           |     |-> putaway_prep_group
    #           |               |-> stock_process
    #           |                      |-> delivery_item
    #           |                             |      |-> delivery_id
    #          stock_order_item               |
    #                |-> link_delivery_item_stock_order
    #
    #

    my $schema = $self->result_source->schema;
    my $logger = xt_logger(__PACKAGE__);
    my $types_to_log = [
        $STOCK_PROCESS_TYPE__MAIN,
        $STOCK_PROCESS_TYPE__FASTTRACK,
        $STOCK_PROCESS_TYPE__SURPLUS
    ];

    my @delivery_per_variant_in_container = $schema->resultset('Public::PutawayPrepInventory')->search({
        'me.putaway_prep_container_id' => $self->id,
        -or => [
            { 'stock_order_item.variant_id' => { -ident => 'me.variant_id' } },
            { 'stock_order_item.voucher_variant_id' => { -ident => 'me.voucher_variant_id' } },
        ],
        'stock_processes.type_id' => { '-in' => $types_to_log }
    }, {
        join => {
            'putaway_prep_group' => {
                'stock_processes' => {
                    'delivery_item' => {
                        'link_delivery_item__stock_order_items' => 'stock_order_item'
                    }
                }
            },
       },
       select => [ 'delivery_item.delivery_id', 'stock_processes.type_id', { sum => 'me.quantity' } ],
       as => [ 'delivery_id', 'type_id', 'quantity' ],
       group_by => [ 'delivery_item.delivery_id', 'stock_processes.type_id' ],
       result_class => 'DBIx::Class::ResultClass::HashRefInflator'
    });

    if (@delivery_per_variant_in_container == 0) {
        # no matches? That's okay. It's just not part of the stock process
        return;
    }

    my $inserts = [];

    foreach my $cont_var_deliv (@delivery_per_variant_in_container) {

        push(@$inserts, {
           delivery_id        => $cont_var_deliv->{delivery_id},
           type_id            => $cont_var_deliv->{type_id},
           delivery_action_id => $delivery_action_id,
           quantity           => $cont_var_deliv->{quantity},
           operator_id        => $self->user_id
        });
    }

    try {
        $schema->resultset('Public::LogDelivery')->populate($inserts);
    } catch {
        $logger->warn("Failed to correctly record putaway prep in delivery log: $_");
    };
}

=head2 does_contain_only_cancelled_group: bool

Returns TRUE if stock in current container relates only to "Cancelled group",
other - FALSE.

=cut

sub does_contain_only_cancelled_group {
    my ($self) = @_;

    return !
        first
        { ! $_->is_cancelled_group }
        $self->putaway_prep_groups->all;
}

=head2 does_contain_only_cancelled_group: bool

Returns TRUE if stock in current container relates only to "Migration group",
otherwise - FALSE.

=cut

sub does_contain_only_migration_group {
    my ($self) = @_;

    return !
        first
        { ! $_->is_migration_group }
        $self->putaway_prep_groups->all;
}


=head2 is_abandoned_from_problem_resolution: Bool

Indicate whether current container was abandoned at Putaway problem resolution page.

=cut

sub is_abandoned_from_problem_resolution {
    my $self = shift;

    return !!
        first {$_->is_failure}
        map { $_->putaway_prep_containers->all }
        $self->putaway_prep_groups->all;
}

=head2 does_contain_sku($sku): bool

Return TRUE if current container has provided SKU,
otherwise FALSE.

=cut

sub does_contain_sku {
    my ($self, $sku) = @_;

    $sku //= '';

    return !!
        first {$sku eq $_->variant_with_voucher->sku}
        $self->putaway_prep_inventories->all;
}

=head2 move_stock_from_location_to_prl(:$location_row, :$operator_row) : 1

Perform transition of related stock from specified location to PRL.

=cut

sub move_stock_from_location_to_prl {
    my ($self, $location, $operator) = validated_list(
        \@_,
        location => { isa => 'XTracker::Schema::Result::Public::Location' },
        operator => { isa => 'XTracker::Schema::Result::Public::Operator' },
    );

    foreach my $pp_inventory ($self->putaway_prep_inventories->all) {
        $pp_inventory->move_stock_from_location_to_prl({
            location => $location,
            operator => $operator,
        });
    }

    return 1;
}

=head2 can_accept_variant(:$variant_row) : 1|0

Checks if provided variant could be placed into current container.

=cut

sub can_accept_variant {
    my ($self, $variant_row, $stock_status_row) = validated_list(\@_,
        variant_row => { isa => 'XTracker::Schema::Result::Public::Variant|XTracker::Schema::Result::Voucher::Variant' },
        # TODO pass stock type for variant
        stock_status_row => {isa => 'XTracker::Schema::Result::Flow::Status'},
    );

    my $storage_types_for_this_container = $self->_get_storage_types_and_stock_statuses;

    $storage_types_for_this_container
        ->{ $variant_row->product->storage_type->name }
        ->{ $stock_status_row->name } = 1;

    my $acceptable_prls = XT::Domain::PRLs::get_prls_for_storage_types_and_stock_statuses({
        prl_configs                        => config_var('PRL', 'PRLs'),
        storage_type_and_stock_status_hash => $storage_types_for_this_container,
    });

    return scalar( keys %$acceptable_prls) == 1 ? 1 : 0;
}

=head2 how_many_items_of(:$variant_row): $number

Get the number of passed variant in currently held in container.

=cut

sub how_many_items_of {
    my ($self, $variant_row) = validated_list(\@_,
        variant_row => { isa => 'XTracker::Schema::Result::Public::Variant|XTracker::Schema::Result::Voucher::Variant' },
    );

    my $sum =
        sum
        map { $_->quantity }
        grep { $_->variant_with_voucher->sku eq $variant_row->sku }
        $self->putaway_prep_inventories->all;

    return $sum || 0;
}

=head2 variants: [$varinat_row|$voucher_variant_row, ...]

Returns variant DBIC rows related to content of this container. If there are more
than one instance of particular variant - correspondent object is returned as many
times.

=cut

sub variants {
    my $self = shift;

    return
        [
            map
            {
                my $ppi = $_;
                (
                    grep {$_}
                    map { $ppi->variant_with_voucher }
                    1..$_->quantity
                )
            }
            $self->putaway_prep_inventories->all
        ];
}

=head2 does_contain_compatible_content: 0 | 1

Indicate if container have content which storage type contradict container's type.
This could happen when items storage type is changed after it was placed into current
container.

=cut

sub does_contain_compatible_content {
    my $self = shift;

    my @storage_types =
        uniq
        map
            { $_->variant_with_voucher->product->storage_type_id }
            $self->putaway_prep_inventories->all;

    my $container_id = $self->container_id;

    my $failure;
    my $pp_container_rs = $self->result_source->schema->resultset('Public::PutawayPrepContainer');
    my $return_value = 1;

    foreach my $storage_type_id (@storage_types) {
        try {
            $pp_container_rs->check_container_id_is_compatible_with_storage_type({
                container_id    => $container_id,
                storage_type_id => $storage_type_id,
            });
        } catch {
            $return_value = 0;
        };
    }

    return $return_value;
}

=head2 get_return_items: @return_item_rows

If the container contains any returned items that are being put away, then
this method returns a list of those items.

If the container isn't being used for returns, then the method returns an
empty list.

=cut

sub get_return_items {
    my $self = shift;

    return map { $_->get_return_items } $self->putaway_prep_inventories();
}

=head2 get_count_of_sku($sku) : $count

Return the number of items of a given sku that are in the container.

=cut

sub get_count_of_sku {
    my ($self, $sku) = @_;

    my $count = sum(
        map  { $_->quantity }
        grep { $_->variant->sku eq $sku }
        $self->putaway_prep_inventories,
    );

    return $count;
}

=head2 send_container_empty_to_full_prl

Send container_empty message to Full PRL.

We call this from the advice_response handler for migration containers,
so that the tote can be used again in future when it comes out of DCD.

=cut

sub send_container_empty_to_full_prl {
    my $self  = shift;

    my $full_prl = XT::Domain::PRLs::get_prl_from_name({
        prl_name => 'Full',
    });
    my $full_prl_destination = $full_prl->amq_queue;
    $self->container->send_container_empty_to_prls({
        'destinations' => [$full_prl_destination],
    });

}

=head2 copy_stock_adjust_log_from( $source_pp_container_row ) : undef | 1

Copy stock adjust message log records from provided source container
to current one.

At this moment it is needed only for migration containers.
Those messages are used to generate migration report.

All stock adjust messages log records touched by this method
have extra field in message body: "modified_by_corrections_at_putaway".

Method assumes that each stock adjust messages sent to XT has
"delta_quantity" -1. As it is how migration process uses stock_adjust
messages.

Return UNDEF if copying log records is inappropriate, 1 - otherwise.

=cut

sub copy_stock_adjust_log_from {
    my $self = shift;
    my ($source_container_row) = pos_validated_list(\@_,
        { isa => 'XTracker::Schema::Result::Public::PutawayPrepContainer' },
    );

    # this matters only for migration containers, container with
    # other stock do not have stock adjust message log
    return unless $self->does_contain_only_migration_group;

    my $stock_adjust_messages_rs = $self->result_source->schema
        ->resultset('Public::ActivemqMessage')
        ->filter_migration_stock_adjust;

    my @message_rows = $stock_adjust_messages_rs->search({
        entity_id => [ map { $_->variant->sku  } $self->putaway_prep_inventories ],
        content => {
            -like => sprintf(
                q{%%"migration_container_id":"%s"%%},
                $source_container_row->container_id,
            ),
        }
    });

    my %processed_skus;

    # go through all stock adjust message log records for source
    # container and duplicate those which relate to stock in current
    # container (assuming that each record has 'delta_quantity' -1)
    foreach my $msg_row (@message_rows) {

        my $sku = $msg_row->entity_id;

        # make sure current SKU for current message record was not processed
        next if $processed_skus{$sku};

        # make sure current container has SKU from processing message
        my $number_of_sku_in_self = $self->get_count_of_sku( $msg_row->entity_id )
            or next;

        $msg_row->duplicate_message({
            message_content => { migration_container_id => ''.$self->container_id},
        }) foreach 1 .. $number_of_sku_in_self;

        $processed_skus{$sku} = 1;
    }

    return 1;
}

1;
