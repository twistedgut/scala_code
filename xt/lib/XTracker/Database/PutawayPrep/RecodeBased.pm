package XTracker::Database::PutawayPrep::RecodeBased;

=head1 NAME

XTracker::Database::PutawayPrep::RecodeBased - Utility class for the Putaway Prep process based on Recode group, part of 'Goods In'.

=head1 DESCRIPTION

Used only for putting away only those items which come from Recode group,
rather than from Process group (PGID).

It inherits and behaves in the same way as L<XTracker::Database::PutawayPrep>. Both
modules support same interface. For more information please refer to parent class's POD.

Please, note word "recode_id" should not be mentioned in the interface for this class:
neither in method names nor in method signatures. Use "group_id" instead.

=cut

use NAP::policy "tt", qw/class/;

use MooseX::Params::Validate;
use Readonly;

use NAP::XT::Exception;
use XTracker::Constants::FromDB qw(
    :stock_process_status
    :stock_process_type
    :storage_type
    :putaway_prep_container_status
    :container_status
    :putaway_type
);
use XTracker::Database::Container qw (
    :utils
    :naming
    :validation
);
use XTracker::Database::FlowStatus qw/:stock_process/;

extends 'XTracker::Database::PutawayPrep';

=head2 container_group_field_name

B<Description>

Name of column in C<putaway_prep_group> table that holds ID that current class deals with.

=cut

sub container_group_field_name { 'recode_id' }

=head2 name

B<Description>

Name of entity that methods from current class accept as "group_id".

=cut

sub name { 'RECODE_ID' }

=head2 extract_group_number

B<Description>

Convert recode group's ID into form suitable to use for database queries. Basically it
just removes prefix that set indicates that value is recode group.

=cut

sub extract_group_number {
    my ($self, $group_id) = @_;

    $group_id =~ s/^r\-?//;

    return $group_id;
}

=head2 get_canonical_group_id

B<Description>

Present passed ID as canonical Recode group ID.

=cut

sub get_canonical_group_id {
    my ($self, $group_id) = @_;

    return "r$group_id";
}

=head2 is_group_id_valid

B<Description>

Class method that checks if passed string is valid Recode group ID from format point of view

B<Parameters>

C<$recode_id> : Recode group ID

B<Returns>

TRUE if passed value is Recode ID

FALSE otherwise

=cut

sub is_group_id_valid {
    my ($class, $recode_id) = @_;

    # case when undefined ID was passed
    $recode_id //= '';

    return $recode_id =~ /^(r\-?)?\d+$/i;
}

=head2 is_group_id_suitable

B<Description>

Check if a Recode group ID is suitable for Putaway Prep.

B<Synopsis>

    $pp->is_gropu_id_suitable({ group_id => $recode_id });

    OR

    $pp->is_group_id_suitable({ group_id => $recode_id, container_id => $container_id });

B<Parameters>

=over

=item group_id

Recode Group ID. As used throughout the Goods In process, stock_process table,
etc.

=item container_id (optional)

ID of container to which items from the Recode group ID will be added.

This is only passed if there *is* already a container with at least one item in.
It's used to test the mix rules, to give advance warning to the operator that
the items will not be suitable for this container.

=back

B<Returns>

Returns true if the Recode group ID is suitable for Putaway Prep.

B<Exceptions>

Throws an exception if the Recode group ID is not recognised,
or the Recode group ID is not at the correct stage of the Goods In process,
or the Recode group ID does not contain any products,
or the PRL does not accept products of this storage type,
or if adding an item to the container will break mix rules.

=cut

sub is_group_id_suitable {
    my ($self, $recode_id, $container_id) = validated_list(
        \@_,
        group_id     => { isa => 'Str' },
        container_id => { isa => 'NAP::DC::Barcode::Container', optional => 1 },
    );

    return $self->error("PGID/Recode group ID is invalid. Please scan a valid PGID/Recode group ID")
        unless $self->is_group_id_valid($recode_id);

    $recode_id = $self->extract_group_number($recode_id);

    my $group_rs = $self->schema
        ->resultset('Public::StockRecode')
        ->search({
            id => $recode_id,
            # complete => 1, uncomment?
        });

    # handle any DBIC errors, e.g. if provided recode ID is out of range
    return $self->error("Unknown PGID/Recode group ID. Please scan a valid Recode group ID")
        unless try { $group_rs->count };

    $self->error(
        sprintf(
            "Recode group ID '%s' does not contain any products",
            $self->get_canonical_group_id($recode_id)
        )
    ) unless @{ $self->get_skus_for_group_id($recode_id) };


    # ensure pgid contains suitable products for the PRL
    # i.e. their storage_type matches the storage types in config
    my $storage_type = $self->schema
        ->resultset('Product::StorageType')
        ->find($self->get_storage_type_id_for($recode_id))->name;

    # check there is some PRL suitable for this PGID's storage type and throw an error if not
    my $prls = XT::Domain::PRLs::get_prls_for_storage_type_and_stock_status({
        storage_type => $storage_type,
        prl_configs  => XTracker::Config::Local::config_var('PRL', 'PRLs'),
        stock_status => $self->get_stock_status_row->name,
    });
    $self->error(
        sprintf(
            "There is no PRL suitable for Recode group ID '%s' (storage type '%s')",
            $self->get_canonical_group_id($recode_id), $storage_type
        )
    ) unless keys %$prls;

    if ($container_id) {
        # a container exists with item(s) in it.
        my $variant = $self->_get_variant_for($recode_id);
        return $self->error(
            sprintf(
                "Could not find any products for Recode group ID: '%s'",
                $self->get_canonical_group_id($recode_id)
            )
        ) unless $variant;

        # give advance warning to operator: see if adding a product
        # from this pgid to the container would break any mix rules
        my $err;
        try {
            $self->schema->resultset('Public::PutawayPrepContainer')->_update_mix_rules({
                variant_id   => $variant->id,
                group_id     => $recode_id,
                container_id => $container_id,
                putaway_prep => $self,
            });
            $err=0;
        # case when there was violation of client compatibility
        } catch {
            if ($_ ~~ match_instance_of('NAP::DC::Exception::MixRules')) {
                if ($_->conflict_type eq 'client') {

                    my $client = $_->conflicts_with->{client};

                    if ($client eq $NAP::DC::PRL::Tokens::dictionary{CLIENT}->{JC}) {
                        $client = 'Jimmy Choo';
                    } elsif ($client eq $NAP::DC::PRL::Tokens::dictionary{CLIENT}->{NAP}) {
                        $client = 'Net-a-Porter';
                    }

                    $err = $self->error(sprintf "Recode group ID '%s' can not be added to container '%s' because it"
                           . " contains item belonging to '%s'. This Recode group ID does not belong to '%s'. Please"
                           . ' start new container for this Recode group ID',
                                        $self->get_canonical_group_id($recode_id), $container_id, $client, $client
                                    );
                }
                # attempt to scan Recode containing the same SKU but from different Recode
                elsif ($_->conflict_type eq 'pgid') {

                    $err =  $self->error(sprintf "Recode group ID '%s' cannot be added to container '%s' because"
                                         . " it contains the same SKU with PGID/Recode group ID '%s'. Please"
                                         . ' start new container for this Recode group ID',
                                         $self->get_canonical_group_id($recode_id), $container_id,
                                         $_->conflicts_with->{pgid}
                                     );
                }
                # attempt to scan Recode with same SKU but different stock status
                elsif ($_->conflict_type eq 'status') {

                    $err = $self->error(sprintf "Recode group ID '%s' cannot be added to container '%s' because"
                                        . " it contains the same SKU with stock status '%s'. Please"
                                        . ' start new container for this Recode group ID',
                                        $self->get_canonical_group_id($recode_id), $container_id,
                                        $_->conflicts_with->{status}
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
                $err = 1;
            }
            else {
                die $_;
            }
        };
        return $err if $err;
    }

   return 1;
}

=head2 does_sku_belong_to_group_id

B<Description>

Check if a SKU belongs to one of the items in a Recode Group ID.

B<Synopsis>

    $pp->does_sku_belong_to_group_id({ group_id => $recode_id, sku => $sku });

B<Parameters>

=over

=item group_id

Recode group ID

=item sku

SKU of an item in the Recode group (or not)

=back

B<Returns>

Returns true if the SKU belongs to an item in the Recode group.

B<Exceptions>

Throws an exception if the SKU is not recognised,
or the the SKU does not belong to an item in the Recode Group.

=cut


sub does_sku_belong_to_group_id {
    my ($self, $recode_id, $sku) = validated_list(
        \@_,
        group_id=> { isa => 'Str' },
        sku     => { isa => 'Str' },
    );

    $recode_id = $self->extract_group_number($recode_id);

    if ($sku =~ m/^(\d+)\-(\d+)?$/) {
        $sku = sprintf( "%d-%03d", $1, $2 );
    }
    else {
        $self->error( sprintf( "'%s' doesn't look like a SKU", $sku ) );
    }

    return 1 if grep {$sku eq $_} @{ $self->get_skus_for_group_id($recode_id) };

    $self->error( sprintf( "SKU '%s' does not belong to Recode ID: '%s'", $sku, $recode_id ) );
}

=head2 get_skus_for_group_id

B<Description>

Get SKU that belongs to passed Recode group ID.

Though there is always one SKU, the return value is an array ref just to support
interface shared  with L<XTracker::Database::PutawayPrep>.

B<Parameters>

=over

=item group_id

Recode group ID

=back

B<Returns>

ARRAY ref of SKUs.

=cut

sub get_skus_for_group_id {
    my $self = shift;
    my ($recode_id) = pos_validated_list(
        \@_,
        { isa => 'Str' },
    );

    $recode_id = $self->extract_group_number($recode_id);

    return [ $self->_get_variant_for($recode_id)->sku ];
}

=head2 get_stock_type_name_from_group_id

B<Description>

Returns stock type of products in a Recode group, though it is always B<MAIN>.

This is very simple method but stands to support interface shared with
L<XTracker::Database::PutawayPrep>.

B<Returns>

Returns the name (not ID) of a stock type from the public.stock_process_type table.

=cut

sub get_stock_type_name_from_group_id {
    my $self = shift;

    # recode always have stock of "MAIN" stock type
    return $self->schema
        ->resultset('Public::StockProcessType')
        ->find($STOCK_PROCESS_TYPE__MAIN)->type;
}

=head2 get_storage_type_id_for

B<Description>

Convenience function to get the stock type of product in a Recode group

B<Parameters>

=over

=item C<$recode_id>

Recode group ID containing items from which to get the storage type.

=back

B<Returns>

Returns the ID of a storage type from the product.storage_type table.

=cut

sub get_storage_type_id_for {
    my $self = shift;
    my ($recode_id) = pos_validated_list(
        \@_,
        { isa => 'Str' },
    );

    $recode_id = $self->extract_group_number($recode_id);
    my $variant = $self->_get_variant_for($recode_id);

    confess sprintf('missing variant for recode ID: "%s"', $recode_id)
        unless $variant;

    my $storage_type_id = $variant->product->storage_type_id;

    confess sprintf('missing storage type for product ID "%s" (recode ID "%s")',
        $variant->product->id, $recode_id)
            unless $storage_type_id;

    return $storage_type_id;
}

=head2 get_container_type_name_for

B<Description>

For passed C<$recode_id> returns name of container type suitable for putaway.

=cut

sub get_container_type_name_for {
    my ($self, $recode_id) = @_;

    $recode_id = $self->extract_group_number($recode_id);
    my $storage_type_id = $self->get_storage_type_id_for($recode_id);

    my $container_type_name = compatible_type_for_goods_in({
        storage_type_id => $storage_type_id,
        schema          => $self->schema,
    });

    return name_of_container_type($container_type_name);
}

=begin private

=head1 PRIVATE METHODS

=head2 _get_variants_for

For a given Recode group ID, returns ARRAY ref of Variant DBIC objects.

=cut

sub _get_variant_for {
    my $self = shift;

    my ($recode_id) = pos_validated_list(
        \@_,
        { isa => 'Str' },
    );

    $recode_id = $self->extract_group_number($recode_id);

    my $recode_row = $self->schema->resultset('Public::StockRecode')->find($recode_id);

    return $recode_row ? $recode_row->variant : undef;
}

=head2 get_stock_status_row: $flow_status_row

For provided PGID return Flow status row object that represents
stock status.

=cut

sub get_stock_status_row {
    my $self = shift;

    # recode is always MAIN
    return $self->schema->resultset('Flow::Status')
        ->find( flow_status_from_stock_process_type( $STOCK_PROCESS_TYPE__MAIN ) );
}

=end private

=cut


1;
