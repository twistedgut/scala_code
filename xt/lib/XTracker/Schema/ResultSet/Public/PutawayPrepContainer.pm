package XTracker::Schema::ResultSet::Public::PutawayPrepContainer;

=head1 NAME

XTracker::Schema::ResultSet::Public::PutawayPrepContainer - Represents a container being used for putaway preparation

=head1 DESCRIPTION

Used by the handler for the Putaway Preparation page: XTracker::Stock::GoodsIn::PutawayPrepContainer

Constraints enforced: Each container ID should only ever have one row marked 'in progress' at any one time.

All methods throw a NAP::XT::Exception upon error (instead of returning false);
these errors are caught by the handler and displayed to the user.

'confess' is used only to catch programming errors that should never happen on live.

=head1 SYNOPSIS

    # returns a XTracker::Schema::Result::Public::PutawayPrepContainer:
    my $putaway_prep_container =
        $schema->resultset('Public::PutawayPrepContainer')->find_in_progress({
            container_id => $container_id
        }); # there can be only one

=head1 METHODS

=cut

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Carp 'confess';
use Try::Tiny;
use Smart::Match instance_of => { -as => 'match_instance_of' };
use MooseX::Params::Validate qw/validated_hash validated_list pos_validated_list/;
use DateTime;

use NAP::DC::MixRules;
use NAP::XT::Exception;
use NAP::DC::PRL::Tokens;
use NAP::DC::Barcode::Container;
use XTracker::Constants qw/:prl_type/; # Imports $PRL_TYPE__*
use XTracker::Constants::FromDB qw(
    :putaway_prep_container_status
    :container_status
    :business
    :storage_type
    :delivery_action
);

use XTracker::Database::Product qw/get_variant_by_sku/;
use XTracker::Database::Container qw(
    :validation
    :naming
    :utils
); # is_compatible, get_container_by_id
use XTracker::Database::PutawayPrep;
use XTracker::Database::PutawayPrep::RecodeBased;

use XTracker::Logfile qw(xt_logger);
use XT::Domain::PRLs;

my $logger = xt_logger(__PACKAGE__);

=head2 start

B<Description>

Register a container as being used for putaway preparation.

B<Synopsis>

    $putaway_prep_container->start({ container_id => $container_id, user_id => $user_id });

B<Parameters>

=over

=item container_id

Container ID to register

=item user_id

ID of operator

=back

B<Returns>

Returns the newly created PutawayPrepContainer row upon success.

B<Exceptions>

Throws an exception if the container is already being used for putaway prep.

=cut

sub start {
    my ($self, $container_id, $user_id) = validated_list( \@_,
        container_id => { isa => 'NAP::DC::Barcode::Container' },
        user_id      => { isa => 'Str' },
    );

    # fail if container is already in progress
    $self->error( sprintf( "Container '%s' is already in progress", $container_id ) )
        if $self->find_incomplete({ container_id => $container_id });

    # make sure that container with passed ID exists in XTracker
    $self->result_source->schema->resultset( 'Public::Container' )
        ->find_or_create( { id => $container_id } );

    # create a row in the putaway_prep table
    my $pp_container_row = $self->create({
        container_id           => $container_id,
        user_id                => $user_id,
        putaway_prep_status_id => $PUTAWAY_PREP_CONTAINER_STATUS__IN_PROGRESS,
    });

    return $pp_container_row;
}

=head2 add_sku

Adds a SKU from a PGID/Recode group ID to a container, increments
quantity if necessary.

B<Synopsis>

    $putaway_prep_container->add_sku({
        sku         => $sku,
        container_id=> $container_id,
        group_id    => $pgid,
        putaway_prep=> XTracker::Database::PutawayPrep->new({schema => $schema}),
    });

    OR

    $putaway_prep_container->add_sku({
        sku         => $sku,
        container_id=> $container_id,
        group_id    => $recode_id,
        putaway_prep=> XTracker::Database::PutawayPrep::RecodeBased->new({schema => $schema}),
    });

* sku - SKU of item to be added
* container_id - Container ID to which SKU should be added
* group_id - Could be Process group ID (PGID) or Recode group ID, this
  argument should correspond to value passed in B<putaway_prep>.
* putaway_prep - Instance of either L<XTracker::Database::PutawayPrep> or
  L<XTracker::Database::PutawayPrep::RecodeBased> class.

Returns true upon success.

Throws an exception if mix rules are broken, or the container
has not been registered for putaway prep with L</start>.

=cut

sub add_sku {
    my ($self, %params) = validated_hash(
        \@_,
        sku             => { isa => 'Str' },
        container_id    => { isa => 'NAP::DC::Barcode::Container' },
        group_id        => { isa => 'Str' },
        putaway_prep    => {
            isa => 'XTracker::Database::PutawayPrep',
        },
    );
    my $args = \%params;
    my ($group_id, $putaway_prep) = @params{qw/group_id putaway_prep/};
    $group_id = $putaway_prep->extract_group_number($group_id);

    my $variant_id = get_variant_by_sku(
        $self->result_source->schema->storage->dbh,
        $args->{sku},
    );
    $self->error( sprintf( "Cannot recognise SKU '%s'", $args->{sku} ) )
        unless $variant_id;

    my $err;
    # check MixRules and catch all known errors
    try {
        $self->_update_mix_rules({
            variant_id  => $variant_id,
            group_id    => $group_id,
            container_id=> $args->{container_id},
            putaway_prep=> $putaway_prep,
        });
        $err=0;
    }
    catch {
        # case when there was violation of client compatibility
        use experimental 'smartmatch';
        if ($_ ~~ match_instance_of('NAP::DC::Exception::MixRules')) {
            if ($_->conflict_type eq 'client') {

                # get human readable client's name
                my $client = $_->conflicts_with->{client};

                if ($client eq $NAP::DC::PRL::Tokens::dictionary{CLIENT}->{JC}) {
                    $client = 'Jimmy Choo';
                } elsif ($client eq $NAP::DC::PRL::Tokens::dictionary{CLIENT}->{NAP}) {
                    $client = 'Net-a-Porter';
                }

                $self->error(sprintf 'SKU %s cannot be added to container %s because it'
                             . ' contains item belonging to %s. This SKU does not belong to %s. Please'
                             . ' start new container for this SKU',
                             $args->{sku}, $args->{container_id}, $client, $client
                         );

            }
            # attempt to scan SKU into container containing the same SKU but different PGID
            elsif ($_->conflict_type eq 'pgid') {

                $self->error(sprintf 'SKU %s cannot be added to container %s because'
                             . ' the container %s contains the same SKU with PGID %s. Please'
                             . ' start new container for this SKU',
                             $args->{sku}, $args->{container_id}, $args->{container_id}, $_->conflicts_with->{pgid}
                         );

            }
            # attempt to scan SKU into container with same SKU but different stock status
            elsif ($_->conflict_type eq 'status') {

                $self->error(sprintf 'SKU %s cannot be added to container %s because'
                             . ' the container contains the same SKU with stock status %s. Please'
                             . ' start new container for this SKU',
                             $args->{sku}, $args->{container_id}, $_->conflicts_with->{status}
                         );

            }
            # attempt to scan SKU into container with items of different family
            elsif ($_->conflict_type eq 'family') {

                my $current_sku_family = $self->_get_variant_details($variant_id)->{family};

                $self->error(sprintf 'SKU %s cannot be added to container %s because'
                             . ' the container contains %s and the SKU is %s. Please'
                             . ' start new container for this SKU',
                             $args->{sku}, $args->{container_id}, $_->conflicts_with->{family}, $current_sku_family
                         );
            }
            else {
                die $_;
            }
        }
        elsif ($_ ~~ match_instance_of('NAP::DC::Exception::Overweight')) {

            $self->error(sprintf q|Container weight limit is %.2f %s. |
                         . q| Current contents weight is %.2f %s, so can't add item weighing %.2f %s|,
                         $_->limit, $_->unit,
                         $_->current, $_->unit,
                         $_->addition, $_->unit
                     );
        }
        else {
            die $_;
        }
    };

    # get "in progress" container
    my $putaway_prep_container = $self->find_in_progress({
        container_id => $args->{container_id},
    }) or $self->error( sprintf( "container %s has not been scanned for Putaway Prep", $args->{container_id} ) );

    # update container "modified" date
    $putaway_prep_container->update({ modified => DateTime->now });

    # is an item of this type already in the container?
    my $existing_item = $putaway_prep_container->search_related('putaway_prep_inventories')->search_with_variant({
        putaway_prep_container_id => $putaway_prep_container->id,
        pgid                      => $group_id,
        variant_id                => $variant_id,
    })->first;

    if ($existing_item) {
        # increment quantity
        $existing_item->update({ quantity => $existing_item->quantity + 1 });
    }
    else {

        my $putaway_prep_group = $putaway_prep->get_or_create_putaway_prep_group({
            group_id => $group_id
        });

        # add new item to container
        $existing_item = $self->result_source->schema->resultset('Public::PutawayPrepInventory')
            ->create({
                putaway_prep_container_id => $putaway_prep_container->id,
                pgid                      => $group_id,
                variant_id                => $variant_id,
                quantity                  => 1,
                putaway_prep_group_id     => $putaway_prep_group->id,
            });
    }

    return $existing_item;
}

=head2 finish

B<Description>

Mark a container as having completed putaway prep.

B<Synopsis>

    $putaway_prep_container->finish({ container_id => $container_id });

B<Parameters>

=over

=item container_id

ID of container to be marked complete.

=item container_fullness

Optional: String value that indicates container fullness. For possible values,
please refer to Xtracker configuration file
"PRLs > putaway_prep_container_specific_questions > container_fullness"
section.

=back

B<Returns>

Returns true upon success, false upon failure.

B<Exceptions>

Throws an exception if more than one container is found in progress -- this should never happen.

=cut

sub finish {
    my ($self, %params) = validated_hash(
        \@_,
        container_id       => { isa => 'NAP::DC::Barcode::Container' },
        container_fullness => { isa => 'Maybe[Str]', optional => 1 },
    );
    my ($container_id, $container_fullness) = @params{qw/container_id container_fullness/};

    # get result set for passed container
    my $putaway_prep_container = $self->find_in_progress({
        container_id => $container_id,
    }) or confess "Failed to find container $container_id in status IN PROGRESS - cannot finish it";

    # send SKU Update message for each SKU from container
    for my $papi ($putaway_prep_container->putaway_prep_inventories->all) {
        $papi->variant_with_voucher->send_sku_update_to_prls;
    }

    # send Advice message regarding to current container
    $putaway_prep_container->send_advice_to_prl({
        container_fullness => $container_fullness
    });

    # Record these items as being processed through the putaway prep phase.
    $putaway_prep_container->update_delivery_log($DELIVERY_ACTION__PUTAWAY_PREP);
    foreach my $return_item ($putaway_prep_container->get_return_items) {
        $return_item->putaway_prep_complete($putaway_prep_container->user_id);
    };

    return 1;
}

=head2 find_in_progress

Shortcut method to fetch a single DBIC Result, representing a container
that is 'in progress'.

Throws an exception if there is more than one 'in progress' row for the
specified container.

B<Synopsis>

    $putaway_prep_container->find_in_progress({ container_id => $container_id });

B<Parameters>

=over

=item container_id

ID of container to return

=back

B<Returns>

DBIC Result class representing a putaway prep container:
XTracker::Schema::Result::Public::PutawayPrepContainer

=cut

sub find_in_progress {
    my ($self, $container_id) = validated_list(
        \@_,
        container_id    => { isa => 'NAP::DC::Barcode::Container' },
    );
    my @results = $self->search({
        container_id => $container_id,
        putaway_prep_status_id => [
            $PUTAWAY_PREP_CONTAINER_STATUS__IN_PROGRESS,
        ],
    });
    $self->error("More than one container called $container_id in IN PROGRESS state. Cannot continue")
        if @results > 1;
    return $results[0];
}

=head2 find_in_progress_or_start($container_id, $user_id): $pp_container_row

Shortcut method that calls find_in_progress and (if that finds nothing) then
called start().

=cut

sub find_in_progress_or_start {
    my ($self, $container_id, $user_id) = validated_list( \@_,
        container_id => { isa => 'NAP::DC::Barcode::Container' },
        user_id      => { isa => 'Str' },
    );

    return $self->find_in_progress({
        container_id => $container_id,
    }) || $self->start({
        container_id => $container_id,
        user_id      => $user_id,
    });
}

=head2 find_in_transit( Barcode::Container :$container_id ) : $pprep_container_row | undef

    $putaway_prep_container_rs->find_in_transit({
        container_id => $container_id,
    });

Find PutawayPrepContainer with $container_id that is 'in transit'.

Throw an exception if there is more than one 'in transit' row for the
specified container.

=cut

sub find_in_transit {
    my ($self, $container_id) = validated_list(
        \@_,
        container_id    => { isa => 'NAP::DC::Barcode::Container' },
    );
    my @results = $self->search({
        container_id           => $container_id,
        putaway_prep_status_id => [
            $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT,
        ],
    });
    confess "More than one container called $container_id in IN TRANSIT state. Cannot continue"
        if @results > 1;
    return $results[0];
}

=head2 find_incomplete($container_id) : $putaway_prep_container_row | undef | die

Find and return the $putaway_prep_container_row with $container_id, or
undef it none was found. It must not be in a complete state.

The idea of this method is to get putaway prep container in all statuses
except "completed". That is in all statuses where there is at least one possible
action to be done on pp_container.

Die if there is more than one row for the specified container.

=cut

sub find_incomplete {
    my ($self, $container_id) = validated_list(
        \@_,
        container_id    => { isa => 'NAP::DC::Barcode::Container' },
    );
    my @results = $self->search({
        container_id => $container_id,
        putaway_prep_status_id => {
            -not_in => [
                $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE,
                $PUTAWAY_PREP_CONTAINER_STATUS__RESOLVED,
            ],
        },
    });
    confess "More than one container called $container_id in INCOMPLETE state. Cannot continue"
        if @results > 1;
    return $results[0];
}

=head2 filter_active

Filter resultset for 'active' containers, i.e. those not in an end state.

=cut

sub filter_active {
    my ($self) = @_;
    return $self->search({
        putaway_prep_status_id => {
            -not_in => [
                $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE,
                $PUTAWAY_PREP_CONTAINER_STATUS__RESOLVED,
            ],
        },
    });
}

=head2 check_container_id_is_compatible_with_storage_type(:$container_id, :$storage_type_id) : 1

Check that container could accept provided storage type.

Return "1" if it does, and throw an exception otherwise.

=cut

sub check_container_id_is_compatible_with_storage_type {
    my ($self, %params) = validated_hash(
        \@_,
        container_id     => { isa => 'NAP::DC::Barcode::Container' },
        storage_type_id => { isa => 'Str' },
    );
    my ($container_id, $storage_type_id) = @params{qw/container_id storage_type_id/};

    unless (
        is_compatible({
            container_id    => $container_id,
            storage_type_id => $storage_type_id,
            schema          => $self->result_source->schema,
        })
    ) {

        # need correspondent storage type record for user message
        my $compatible_storage_types = get_compatible_storage_types_for($container_id);
        return $self->error(
            sprintf q!Invalid container.!
                . q! Container '%s' is for storage type(s) '%s'.!
                . q! Please scan valid container!,
            $container_id, join(', ', @$compatible_storage_types)
        )
    }

    return 1;
}

=begin private

=head1 PRIVATE METHODS

=head2 _update_mix_rules

B<Description>

Check that NAP::DC::MixRules won't be broken if this item is added to the container.

B<Synopsis>

    $self-> _update_mix_rules({
        variant_id  => $variant_id,
        group_id    => $pgid,
        container_id=> $container_id,
        putaway_prep=> XTracker::Database::PutawayPrep->new({schema => $schema})
    });

    OR

    $self-> _update_mix_rules({
        variant_id  => $variant_id,
        group_id    => $recode_id,
        container_id=> $container_id,
        putaway_prep=> XTracker::Database::PutawayPrep::RecodeBased->new({schema => $schema})

    });

B<Parameters>

=over

=item variant_id

Variant ID for proposed item

=item group_id

Could be either Process group ID (PGID) or Recode group ID. It correlates with
B<putaway_prep> argument.

=item putaway_prep

Instance of either L<XTracker::Database::PutawayPrep> or
L<XTracker::Database::PutawayPrep::RecodeBased> class.

=item container_id

ID of container it's proposed the item will be added to

=back

B<Returns>

UNDEF if no rules were broken

B<Exceptions>

Throws a NAP::DC::Exception::foo exception if any mix rules were broken

=cut

sub _update_mix_rules {
    my ($self, %params) = validated_hash(
        \@_,
        variant_id      => { isa => 'Str' },
        group_id        => { isa => 'Str' },
        container_id    => { isa => 'NAP::DC::Barcode::Container' },
        putaway_prep    => { isa => 'XTracker::Database::PutawayPrep' },
    );
    my $args = \%params;

    # get list of items already in container
    my $pp_container = $self->find_in_progress({
        container_id => $args->{container_id},
    }) or confess "Container '$args->{container_id}' is not in progress, "
        ." cannot add SKU"; # should always find a container in progress
    my @items = $pp_container->search_related('putaway_prep_inventories');

    my $passed_variant_details = $self->_get_variant_details($args->{variant_id});

    my $container_max_weight = XT::Domain::PRLs::get_container_max_weight_for_storage_type({
        storage_type => $passed_variant_details->{storage_type},
        stock_status => $args->{putaway_prep}->get_stock_status_row($args->{group_id})->name,
    });

    my $container = NAP::DC::MixRules->new({
        weight_limit => $container_max_weight, # 0 = no weight limit
        weight_unit  => 'lb',
    });

    # inform mix rules class of the container's current contents
    foreach my $item (@items) {
        foreach (1 .. $item->quantity) {
            # not expected to throw an exception
            $container->contains({
                %{ $self->_get_variant_details($item->variant_with_voucher->id) },
                status => $item->putaway_prep_group->get_stock_process_type->type,
                # mix rules does not care if "pgid" is a Process group ID or Recode group ID,
                # for them it is a just a string. One point we need to use canonical group ID
                # (with correspondent prefix) so case with same IDs for recode and PGID
                # is handled correctly
                pgid => $item->putaway_prep_group->canonical_group_id,
            }); # existing item
        }
    }

    # tell the mix rules class we're adding an item
    # this may throw an exception to indicate failure
    # it must be caught in the calling class, e.g. handler

    $container->add({
        %$passed_variant_details,
        status => $args->{putaway_prep}->get_stock_type_name_from_group_id($args->{group_id}),
        # same here: mix rules treat recode group ID as PGID, for them it is just a string
        pgid   => $args->{putaway_prep}->get_canonical_group_id($args->{group_id}),
    }); # new item

    # if we reach here, then no rules were broken
    return;
}

=head2 _get_variant_details

Given a variant (DBIC row), looks up the various details around it
and returns them as a hash-ref suitable for sending to NAP::DC::MixRules.

See also XT::DC::Messaging::Producer::PRL::SKUUpdate->variant_details()

=cut

# TODO: This is almost exactly the same as
# XT::DC::Messaging::Producer::PRL::SKUUpdate::variant_details - refactor
{
my $default_storage_type_row;
sub _default_storage_type_row {
    my $self = shift;
    return $default_storage_type_row
        ||= $self->result_source->schema->resultset('Product::StorageType')->find(
            $PRODUCT_STORAGE_TYPE__FLAT
        );
}
}
sub _get_variant_details {
    my $self = shift;
    my ($variant_id) = pos_validated_list(
        \@_,
        { isa => 'Int' },
    );

    my $schema = $self->result_source->schema;
    my $variant = $schema->resultset('Public::Variant')->find($variant_id)
        || $schema->resultset('Voucher::Variant')->find($variant_id);

    # Works for both vouchers and products
    my $product = $variant->product;

    my $channel = $product->get_product_channel->channel;

    # These are the same for both products and vouchers:
    my $result = {
        sku     => $variant->sku,
        client  => $channel->prl_client,
        channel => $channel->business->config_section,
        colour  => $product->colour->colour,
        weight  => ($product->shipping_attribute->weight || 0),
        'storage_type' => (
            $product->storage_type
          ? $product->storage_type->name
          : $self->_default_storage_type_row->name
        ),
    };
    if ($product->is_voucher) {
        $result->{'family'}      = $PRL_TYPE__FAMILY__VOUCHER;
        $result->{'designer'}    = $product->designer;
        $result->{'description'} = "Gift Card";
        $result->{'size'}        = $variant->descriptive_value;
        $result->{'length_cm'}   = 0;
    } else {
        $result->{'family'}      = $PRL_TYPE__FAMILY__GARMENT;
        $result->{'designer'}    = $product->designer->designer;
        $result->{'description'} =
            substr( $product->product_attribute->description, 0, 255);
        $result->{'size'}        = $variant->designer_size->size;
        $result->{'length_cm'}   = $variant->get_measurements->{'Length'} || 0;
    }

    return $result;
}

=head2 error

Error wrapper. Use this to throw exceptions instead of die.

The idea is that error handling is abstracted through this interface.

=cut

sub error {
    my $self = shift;
    my ($message) = pos_validated_list(
        \@_,
        { isa => 'Str' },
    );

    NAP::XT::Exception->throw( { error => $message, } );
}

=end private

=cut

1;
