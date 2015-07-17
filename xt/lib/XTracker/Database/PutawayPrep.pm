package XTracker::Database::PutawayPrep;

=head1 NAME

XTracker::Database::PutawayPrep - Utility class for the Putaway Prep process, part of 'Goods In'


=head1 WARNING - THIS CLASS IS DEPRECATED

PLEASE DON'T ADD ANY MORE METHODS HERE!

We intend to refactor and move most, if not all of these methods into DBIC classes
like PutawayPrepContainer and PutawayPrepGroup.

If you can spot a way to move methods out of this class as part of another story
please consider doing so.

Thank you


=head1 DESCRIPTION

Used by the handler for the Putaway Preparation page: L<XTracker::Stock::GoodsIn::PutawayPrepContainer>
and the container class L<XTracker::Schema::ResultSet::Public::PutawayPrepContainer>.
It treats B<group_id> as B<PGID>.

All methods die upon error (instead of returning false);
these errors are caught by the handler and displayed to the user.

Please, note word "PGID" should not be mentioned in the interface for this class:
neither in method names nor in method signatures. Use "group_id" instead.
This is needed because there is at least one other similar class that works with
"recode group": L<XTracker::Database::PutawayPrep::RecodeBased>.

=head1 SYNOPSIS

    use XTracker::Database::PutawayPrep;

    my $pp = XTracker::Database::PutawayPrep->new;
    $pp->is_group_id_suitable({ group_id => $pgid });

=head2 Error message policy

I<die> statements here that contain messages expected to be visible to end-users
as part of normal operation have had a newline appended to them, to suppress
the file/line number stuff that I<die> normally appends.

Those that are only likely to appear because of a system problem or bug in
the code have been left without a newline, so that as much context as possible
is presented in the error message, to aid trouble-shooting.

=head1 METHODS

=cut

use NAP::policy "tt", qw/class/;

use MooseX::Params::Validate; # pos_validated_list, validated_list
use Readonly;

use NAP::XT::Exception;
use XTracker::Database::StockProcess qw/get_putaway_type/;
use XTracker::Database::FlowStatus qw/:stock_process/;
use XTracker::Constants::FromDB qw(
    :stock_process_status
    :stock_process_type
    :storage_type
    :putaway_prep_container_status
    :container_status
    :putaway_prep_group_status
    :putaway_type
);
use XTracker::Database::Container qw (
    :utils
    :naming
    :validation
);
use XT::Domain::PRLs;

with 'XTracker::Role::WithSchema';

# These combinations are valid for putaway prep,
# but some of them may never actually occur.
my $valid_stock_process_types = {
    $PUTAWAY_TYPE__GOODS_IN => [
        $STOCK_PROCESS_TYPE__MAIN,
        $STOCK_PROCESS_TYPE__DEAD,
        $STOCK_PROCESS_TYPE__RTV_FIXED,
        $STOCK_PROCESS_TYPE__FASTTRACK,
        $STOCK_PROCESS_TYPE__SURPLUS,
    ],
    # NOTE: This 'Stock Transfer' is a type of Return
    $PUTAWAY_TYPE__STOCK_TRANSFER => [
        $STOCK_PROCESS_TYPE__MAIN,
        $STOCK_PROCESS_TYPE__DEAD,
        $STOCK_PROCESS_TYPE__RTV_FIXED,
        $STOCK_PROCESS_TYPE__FASTTRACK,
        $STOCK_PROCESS_TYPE__SURPLUS,
    ],
    $PUTAWAY_TYPE__RETURNS => [
        $STOCK_PROCESS_TYPE__MAIN,
        $STOCK_PROCESS_TYPE__DEAD,
        $STOCK_PROCESS_TYPE__QUARANTINE_FIXED,
        $STOCK_PROCESS_TYPE__RTV_FIXED,
        $STOCK_PROCESS_TYPE__FASTTRACK,
        $STOCK_PROCESS_TYPE__SURPLUS,
    ],
    $PUTAWAY_TYPE__SAMPLE => [
        $STOCK_PROCESS_TYPE__MAIN,
        $STOCK_PROCESS_TYPE__DEAD,
        $STOCK_PROCESS_TYPE__RTV_FIXED,
        $STOCK_PROCESS_TYPE__FASTTRACK,
        $STOCK_PROCESS_TYPE__SURPLUS,
    ],
    $PUTAWAY_TYPE__PROCESSED_QUARANTINE => [
        $STOCK_PROCESS_TYPE__MAIN,
        $STOCK_PROCESS_TYPE__DEAD,
        $STOCK_PROCESS_TYPE__QUARANTINE_FIXED,
        $STOCK_PROCESS_TYPE__RTV_FIXED,
        $STOCK_PROCESS_TYPE__FASTTRACK,
        $STOCK_PROCESS_TYPE__SURPLUS,
    ],
};

=head2 container_group_field_name

B<Description>

Name of column in C<putaway_prep_group> table that holds ID that current class deals with.

=cut

sub container_group_field_name { 'group_id' }

=head2 name

B<Description>

Name of entity that methods from current class accept as "group_id".

=cut

sub name { 'PGID' }

=head2 extract_group_number

B<Description>

Convert group's ID into value suitable to use for database queries. Basically it
just removes prefix that set type of group.

=cut

sub extract_group_number {
    my ($self, $group_id) = @_;

    $group_id =~ s/^p\-?//;

    return $group_id;
}

=head2 get_canonical_group_id

B<Description>

Present passed ID as canonical Process group ID (PGID).

=cut

sub get_canonical_group_id {
    my ($self, $group_id) = @_;

    # page sure that we have bare ID
    $group_id = $self->extract_group_number($group_id);

    return "p$group_id";
}

=head2 is_group_id_valid

B<Description>

Class method that checks if passed string is valid PGID from format point of view

B<Parameters>

C<$pgid> : Process group ID

B<Returns>

TRUE if passed value is PGID

FALSE otherwise

=cut

sub is_group_id_valid {
    my ($class, $pgid) = @_;

    # case when undefined PGID was passed
    $pgid //= '';

    return $pgid =~ /^(p\-?)?\d+$/i;
}

=head2 get_or_create_putaway_prep_group

B<Description>

For passed Group ID (either PGID or Recode group ID) finds or creates new instance
record in C<putaway_prep_group> table.

Result record is in status "In progress".

B<Parameters>

=over

=item group_id

PGID or Recode group ID.

=back

B<Return>

C<Public::PutawayPrepGroup> DBIC object.

=cut

sub get_or_create_putaway_prep_group {
    my ($self, $group_id) = validated_list(
        \@_,
        group_id        => { isa => 'Str' },
    );

    my $pp_group_rs = $self->schema->resultset('Public::PutawayPrepGroup');

    # Find group
    my $pp_group = $pp_group_rs->find_active_group({
        group_id      => $group_id,
        id_field_name => $self->container_group_field_name,
    }) || $pp_group_rs->create({
        $self->container_group_field_name => $group_id,
        status_id                         => $PUTAWAY_PREP_GROUP_STATUS__IN_PROGRESS,
    });

    return $pp_group;
}


=head2 is_group_id_suitable_with_container

B<Description>

Check if the storage type of products in the PGID is compatible with the container.

B<Synopsis>

    $putaway_prep_container->is_group_id_suitable_with_container({
        group_id     => $pgid,
        container_id => $container_id
    });

B<Parameters>

=over

=item group_id

Process Group ID that contains some items.
As used throughout the Goods In process, stock_process table, etc.

=item container_id

Container ID to check

=back

B<Returns>

Returns true if the storage type of products in the PGID is compatible with the container.

B<Exceptions>

Throws an exception if products are not compatible, or the container ID is not recognised,
or the container is not available to XT.

=cut

my %valid_container_states = map { $_ => 1 } (
    $PUBLIC_CONTAINER_STATUS__AVAILABLE,
);

sub is_group_id_suitable_with_container {
    my ($self, %params) = validated_hash(
        \@_,
        group_id     => { isa => 'Str' },
        container_id => { isa => 'NAP::DC::Barcode::Container' },
    );
    my $args = \%params;
    my $container_id = $args->{container_id};
    my $group_id = $self->extract_group_number( $args->{group_id} );

    $self->check_container_id({ container_id => $container_id });

    my $storage_type_id = $self->get_storage_type_id_for($group_id);

    $self->schema->resultset('Public::PutawayPrepContainer')
        ->check_container_id_is_compatible_with_storage_type({
            container_id    => $container_id,
            storage_type_id => $storage_type_id,
        });

    return 1;
}

=head2 check_container_id(:$container_id): 1

Check if provided container ID is valid one in non-putaway prep terms.

Return "1" in case of success, throws an exception otherwise.

=cut

sub check_container_id {
    my ($self, %params) = validated_hash(
        \@_,
        container_id    => { isa => 'NAP::DC::Barcode::Container' },
    );
    my $container_id = $params{container_id};

    my $container;
    try {
        $container = get_container_by_id($self->schema, $container_id);
    } catch {
        $self->error( sprintf( "Container '%s' is not valid", $container_id ) );
    };

    unless ( $valid_container_states{ $container->status_id } ) {
        my $container_status = $self
            ->schema->resultset('Public::ContainerStatus')->find($container->status_id);

        return $self->error(
            sprintf q!Container '%s' is not available for put away prep,!
            . q! it is currently being used for '%s'. Please scan another container!,
            $container_id, (ref $container_status ? $container_status->name : 'Unknown')
        );
    }

    return 1;
}

=head2 is_group_id_suitable

B<Description>

Check if a PGID is suitable for Putaway Prep.

B<Synopsis>

    $pp->is_gropu_id_suitable({ group_id => $pgid });

    OR

    $pp->is_group_id_suitable({ group_id => $pgid, container_id => $container_id });

B<Parameters>

=over

=item group_id

Process Group ID. As used throughout the Goods In process, stock_process table,
etc.

=item container_id (optional)

ID of container to which items from the PGID will be added.

This is only passed if there *is* already a container with at least one item in.
It's used to test the mix rules, to give advance warning to the operator that
the items will not be suitable for this container.

=back

B<Returns>

Returns true if the PGID is suitable for Putaway Prep.

B<Exceptions>

Throws an exception if the PGID is not recognised,
or the PGID is not at the correct stage of the Goods In process,
or the PGID does not contain any products,
or the PRL does not accept products of this storage type,
or if adding an item to the container will break mix rules.

=cut

sub is_group_id_suitable {
    my ($self, $pgid, $container_id) = validated_list(
        \@_,
        group_id     => { isa => 'Str' },
        container_id => { isa => 'NAP::DC::Barcode::Container', optional => 1 },
    );

    $pgid = $self->extract_group_number( $pgid );

    return $self->error("PGID/Recode group ID is invalid. Please scan a valid PGID/Recode group ID")
        unless $self->is_group_id_valid($pgid);

    my $group_rs = $self->schema
        ->resultset('Public::StockProcess')
        ->get_group( $pgid );

    # handle any DBIC errors, e.g. if provided PGID is out of integer range
    try {
        die unless $group_rs->count;
    } catch {
        $self->error("Unknown PGID/Recode group ID. Please scan a valid PGID/Recode group ID");
    };

    # filter out all groups that are not MAIN or DEAD type
    # and ensure groups have 'Bagged and Tagged' status
    # i.e. have passed the processing stage before this one
    $group_rs = $group_rs->search({
        # 'me.' is needed to allow safe chaining of resultsets
        'me.status_id' => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
    });

    $self->error("PGID '$pgid' cannot be put away as it has not completed 'Bag and Tag'."
        . " Please, ensure process 'Bag and Tag' is completed before resuming")
            unless $group_rs->count;

    my $quantity = 0;
    $quantity += $_->quantity foreach $self->schema
        ->resultset('Public::StockProcess')->get_group($pgid);
    $self->error( sprintf( "PGID '%s' does not contain any products", $pgid ) )
        unless $quantity;

    my $putaway_type = get_putaway_type( $self->schema->storage->dbh, $pgid )->{putaway_type};
    confess "Putaway type cannot be determined for PGID '$pgid'."
        ." Product data is is invalid, cannot continue" unless $putaway_type;
    my $stock_process_type = $group_rs->first->type;
    $self->error( sprintf(
        "PGID '%s' cannot be put away" .
            " as it has Putaway Type '%s' and Stock Process Type '%s'",
        $pgid,
        $self->schema->find(PutawayType => $putaway_type)->name,
        $stock_process_type->type,
    ) )
        unless
            grep { $_ == $stock_process_type->id }
            @{ $valid_stock_process_types->{$putaway_type} };

    # ensure pgid contains suitable products for the one of PRLs
    # i.e. their storage_type matches one of the storage types in config
    my $storage_type_for_pgid = $self->schema
        ->resultset('Product::StorageType')
        ->find($self->get_storage_type_id_for($pgid))->name;
    my $stock_status_for_pgid = $self->get_stock_status_row($pgid)->name;

    # check there is some PRL suitable for this PGID's storage type and throw an error if not
    my $pgid_prls = XT::Domain::PRLs::get_prls_for_storage_type_and_stock_status({
        storage_type => $storage_type_for_pgid,
        prl_configs  => XTracker::Config::Local::config_var('PRL', 'PRLs'),
        stock_status => $stock_status_for_pgid,
    });
    $self->error(sprintf("There is no PRL suitable for PGID '%s' (storage type '%s')",
        $self->get_canonical_group_id($pgid), $storage_type_for_pgid)) unless keys %$pgid_prls;

    if ($container_id) {
        # a container exists with item(s) in it.
        my $variants = $self->_get_variants_for($pgid);
        $self->error(
            sprintf(
                q!Could not find any products in PGID '%s'!,
                $self->get_canonical_group_id($pgid)
            )
        ) unless @$variants;

        # Get all variants for all PGIDs already in the container
        my $container = $self->schema->resultset('Public::PutawayPrepContainer')->find_in_progress({ container_id => $container_id });

        # If we have no container then no skus have yet been putaway. So return now
        return 1 unless $container;
        my %existing_pgids_variants =
            map { $_->pgid => $self->_get_variants_for($_->pgid) } $container->putaway_prep_inventories;
        # Get all variants for newly scanned PGID
        my @new_variants = @{ $self->_get_variants_for($pgid) };

        # A container cannot be allowed to contain two items that would end up
        # in different PRLs
        my $pgid_from_container = (keys %existing_pgids_variants)[0];
        my $storage_type_for_pgid_in_container = $self->schema
            ->resultset('Product::StorageType')
            ->find($self->get_storage_type_id_for( $pgid_from_container ))->name;
        my $stock_status_for_pgid_in_cintainer = $self->get_stock_status_row($pgid_from_container)->name;
        my $container_prls = XT::Domain::PRLs::get_prls_for_storage_type_and_stock_status({
            storage_type => $storage_type_for_pgid_in_container,
            prl_configs  => XTracker::Config::Local::config_var('PRL', 'PRLs'),
            stock_status => $stock_status_for_pgid_in_cintainer,
        });

        $self->error(sprintf("PGID cannot be scanned into container '%s'"
            ." because it contains items of type '%s' and stock status '%s',"
            ." this PGID contains items of type '%s' and stock status '%s',"
            ." hence must be sent to a different PRL."
            ." Please start a new container for this PGID",
            $container_id, $storage_type_for_pgid_in_container,
            $stock_status_for_pgid_in_cintainer, $storage_type_for_pgid,
            $stock_status_for_pgid
        )) if (keys %$pgid_prls)[0] ne (keys %$container_prls)[0];



        # Check if *any* SKUs are the same across two different PGIDs
        # (even if a potentially clashing SKU has not been scanned yet)
        # to give a super-advanced-spidey-sense warning of breaking mix rules
        my $sku_conflict_error_message =
            "PGID '%s' cannot be added to container '%s' because"
            . " it contains the same SKU with PGID/Recode group ID '%s'. Please"
            . ' start new container for this PGID';
        foreach my $existing_pgid (keys %existing_pgids_variants) {
            foreach my $existing_variant (@{ $existing_pgids_variants{$existing_pgid} }) {
                foreach my $new_variant (@new_variants) {
                    $self->error( sprintf( $sku_conflict_error_message,
                        $self->get_canonical_group_id($pgid), $container_id,
                        $self->get_canonical_group_id($existing_pgid) )
                    ) if $new_variant->sku eq $existing_variant->sku
                        and $pgid ne $existing_pgid;
                }
            }
        }

        # give advance warning to operator: see if adding a product
        # from this pgid to the container would break any mix rules
        try {
            $self->schema->resultset('Public::PutawayPrepContainer')->_update_mix_rules({
                variant_id   => $_->id,
                group_id     => $pgid,
                container_id => $container_id,
                putaway_prep => $self,
            }) for @$variants; # check each variant in the PGID

        } catch {
            if ($_ ~~ match_instance_of('NAP::DC::Exception::MixRules')) {
                # case when there was violation of client compatibility
                if ($_->conflict_type eq 'client') {

                    my $client = $_->conflicts_with->{client};

                    if ($client eq $NAP::DC::PRL::Tokens::dictionary{CLIENT}->{JC}) {
                        $client = 'Jimmy Choo';
                    } elsif ($client eq $NAP::DC::PRL::Tokens::dictionary{CLIENT}->{NAP}) {
                        $client = 'Net-a-Porter';
                    }

                    $self->error(sprintf "PGID '%s' can not be added to container '%s' because it"
                                 . " contains item belonging to '%s'. This PGID does not belong to '%s'. Please"
                                 . ' start new container for this PGID',
                                 $self->get_canonical_group_id($pgid), $container_id, $client, $client
                             );
                }
                # attempt to scan PGID containing the same SKU but different PGID
                elsif ($_->conflict_type eq 'pgid') {

                    $self->error(
                        sprintf(
                            $sku_conflict_error_message,
                            $self->get_canonical_group_id($pgid),
                            $container_id,
                            $_->conflicts_with->{pgid}
                        )
                    );
                }
                # attempt to scan PGID with same SKU but different stock status
                elsif ($_->conflict_type eq 'status') {

                    $self->error(sprintf "PGID '%s' cannot be added to container '%s' because"
                                 . " it contains the same SKU with stock status '%s'. Please"
                                 . ' start new container for this PGID',
                                 $self->get_canonical_group_id($pgid), $container_id, $_->conflicts_with->{status}
                             );
                }
                # attempt to scan PGID into container with items of different family
                elsif ($_->conflict_type eq 'family') {

                    $self->error(sprintf "PGID '%s' cannot be added to container '%s' because"
                                 . " it contains '%s'. Please"
                                 . ' start new container for this SKU',
                                 $self->get_canonical_group_id($pgid), $container_id, $_->conflicts_with->{family}
                             );
                }
                else {
                    die $_;
                }
            }
            # attempt to scan item that violate container weight restrictions
            elsif ($_ ~~ match_instance_of('NAP::DC::Exception::Overweight')) {

                # Do nothing here as we decided in DCA-2396 that we do not care about
                # weight problems at this stage. The overweight issue is going to be
                # caught at point when user actually scans SKU into container.

                # This is needed to prevent situation when user resumes container with
                # weight equals exactly weight limit, and system does not allow to start
                # any PGID. Hence container could not be completed.
            }
            else {
                die $_;
            }
        };
    }
    # else there is no container_id passed, so we don't need to check mix rules:
    #   we are only adding the first item, so mix rules cannot be broken

   return 1;
}

=head2 does_sku_belong_to_group_id

B<Description>

Check if a SKU belongs to one of the items in a Process Group.

B<Synopsis>

    $pp->does_sku_belong_to_group_id({ group_id => $pgid, sku => $sku });

B<Parameters>

=over

=item group_id

Process Group ID

=item sku

SKU of an item in the Process Group (or not)

=back

B<Returns>

Returns true if the SKU belongs to an item in the Process Group

B<Exceptions>

Throws an exception if the SKU is not recognised,
or the the SKU does not belong to an item in the Process Group.

=cut

sub does_sku_belong_to_group_id {
    my ($self, $pgid, $sku) = validated_list(
        \@_,
        group_id => { isa => 'Str' },
        sku      => { isa => 'Str' },
    );

    $pgid = $self->extract_group_number( $pgid );

    if ($sku =~ m/^(\d+)\-(\d+)?$/) {
        $sku = sprintf( "%d-%03d", $1, $2 );
    }
    else {
        $self->error( sprintf( "'%s' doesn't look like a SKU", $sku ) );
    }

    return 1 if grep {$sku eq $_} @{ $self->get_skus_for_group_id($pgid) };

    $self->error(
        sprintf(
            "SKU '%s' does not belong to PGID '%s'",
            $sku, $self->get_canonical_group_id($pgid)
        )
    );
}

=head2 get_skus_for_group_id

B<Description>

ARRAY ref containing a list of SKUs for items in the Process Group.

B<Synopsis>

    $pp->get_skus_for_group_id( $pgid );

B<Parameters>

=over

=item group_id

Process Group ID

=back

B<Returns>

Returns an arrayref containing a list of SKUs for items in the Process Group

B<Exceptions>

Throws an exception if the SKU is not recognised,
or the the SKU does not belong to an item in the Process Group.

=cut

sub get_skus_for_group_id {
    my $self = shift;
    my ($pgid) = pos_validated_list(
        \@_,
        { isa => 'Str' },
    );

    $pgid = $self->extract_group_number( $pgid );

    return [
        map { $_->sku }
            @{ $self->_get_variants_for($pgid) }
    ];
}

=head2 get_stock_type_name_from_group_id

B<Description>

Convenience function to get the stock type of products in a Process Group

Uses the first row in stock process, as they should all have the same type

B<Synopsis>

    $pp->get_stock_type_name_from_group_id( $pgid );

B<Parameters>

=over

=item C<$pgid>

Process Group ID containing items from which to get the stock type

=back

B<Returns>

Returns the name (not ID) of a stock type from the public.stock_process_type table.

=cut

sub get_stock_type_name_from_group_id {
    my $self = shift;
    my ($pgid) = pos_validated_list(
        \@_,
        { isa => 'Str' },
    );

    $pgid = $self->extract_group_number( $pgid );

    # look up Stock Process 'Type' using PGID
    my $type_id = $self->schema
        ->resultset('Public::StockProcess')
        ->search({ group_id => $pgid })
        ->first->type_id;
    my $type = $self->schema
        ->resultset('Public::StockProcessType')
        ->find($type_id)->type;
    return $type;
}

=head2 get_storage_type_id_for

B<Description>

Convenience function to get the stock type of products in a Process Group

B<Synopsis>

    $pp->get_storage_type_id_for( $pgid );

B<Parameters>

=over

=item C<$pgid>

Process Group ID containing items from which to get the storage type

=back

B<Returns>

Returns the ID of a storage type from the product.storage_type table.

=cut

sub get_storage_type_id_for {
    my $self = shift;
    my ($pgid) = pos_validated_list(
        \@_,
        { isa => 'Str' },
    );

    $pgid = $self->extract_group_number( $pgid );

    my $variant = $self->_get_variants_for($pgid)->[0];
    $self->{storage_type_id} = $variant->product->storage_type_id;

    confess sprintf(
        'missing storage type for product ID %i (PGID %s)',
        $variant->product_id, $pgid
    ) unless $self->{storage_type_id};

    return $self->{storage_type_id};
}

=head2 get_container_type_name_for

B<Description>

For passed C<$recode_id> returns name of container type suitable for putaway.

=cut

sub get_container_type_name_for {
    my ($self, $pgid) = @_;

    $pgid = $self->extract_group_number( $pgid );

    my $storage_type_id = $self->get_storage_type_id_for($pgid);

    my $container_type_name = compatible_type_for_goods_in({
        'storage_type_id' => $storage_type_id,
        'schema' => $self->schema,
    });

    return name_of_container_type($container_type_name);
}

=begin private

=head1 PRIVATE METHODS

=head2 _get_variants_for

For a given PGID, returns arrayref of Variant objects

NOTE: This method is deprecated.
Use XTracker::Schema::Result::Public::PutawayPrepGroup's version in future.

=cut

sub _get_variants_for {
    my $self = shift;
    my ($pgid) = pos_validated_list(
        \@_,
        { isa => 'Str' },
    );

    my @stock_process_rs = $self->schema
        ->resultset('Public::StockProcess')
        ->search({group_id => $pgid})
        ->all;
    my @variants = map { $_->variant if defined $_->variant }
        @stock_process_rs;

    return \@variants;
}

=head2 get_stock_status_row: $flow_status_row

For provided PGID return Flow status row object that represents
stock status.

=cut

sub get_stock_status_row {
    my $self = shift;
    my ($pgid) = pos_validated_list(
        \@_,
        { isa => 'Str' },
    );

    $pgid = $self->extract_group_number( $pgid );

    # look up Stock Process 'Type' using PGID
    my $type_id = $self->schema
        ->resultset('Public::StockProcess')
        ->search({ group_id => $pgid })
        ->first->type_id;

    # convert stock process type into stock status
    return $self->schema->resultset('Flow::Status')
        ->find( flow_status_from_stock_process_type( $type_id ) );
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
