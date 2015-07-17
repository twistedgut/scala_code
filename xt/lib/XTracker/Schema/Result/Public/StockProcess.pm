use utf8;
package XTracker::Schema::Result::Public::StockProcess;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.stock_process");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "stock_process_id_seq",
  },
  "delivery_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "quantity",
  { data_type => "integer", is_nullable => 1 },
  "group_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "process_group_id_seq",
  },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "complete",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "container",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "putaway_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "delivery_item",
  "XTracker::Schema::Result::Public::DeliveryItem",
  { id => "delivery_item_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "log_putaway_discrepancies",
  "XTracker::Schema::Result::Public::LogPutawayDiscrepancy",
  { "foreign.stock_process_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "putaway_type",
  "XTracker::Schema::Result::Public::PutawayType",
  { id => "putaway_type_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "putaways",
  "XTracker::Schema::Result::Public::Putaway",
  { "foreign.stock_process_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "rtv_stock_process",
  "XTracker::Schema::Result::Public::RtvStockProcess",
  { "foreign.stock_process_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::Public::StockProcessStatus",
  { id => "status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "type",
  "XTracker::Schema::Result::Public::StockProcessType",
  { id => "type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gZQ7M3zOywvNFa76mgp9Ug


__PACKAGE__->has_many(
  "stock_process_group",
  "XTracker::Schema::Result::Public::StockProcess",
  { "foreign.group_id" => "self.group_id" },
  { on_delete => "NO ACTION", on_update => "NO ACTION", cascade_delete => 0 },
);

__PACKAGE__->many_to_many( 'locations', 'putaways' => 'location' );


use MooseX::Params::Validate qw/validated_list/;

# Make sure "container" is transformed into instance of
# NAP::DC::Barcode::Container on the way from database
# and stringified on the way back to DB
#
use NAP::DC::Barcode::Container;
__PACKAGE__->inflate_column('container', {
    inflate => sub { NAP::DC::Barcode::Container->new_from_id(shift) },
    deflate => sub { shift->as_id },
});

use Carp 'confess';
use XTracker::Config::Local     'config_var';
use XTracker::Constants         qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB qw(
                                    :delivery_action
                                    :rtv_action
                                    :stock_process_status
                                    :stock_process_type
                                    :flow_status
                                    :putaway_type
                                );
use XTracker::Document::RTVStockSheet;
use XTracker::Database::FlowStatus qw( :iws :stock_process :prl );
use XTracker::Database::RTV qw(
    insert_rtv_stock_process
    insert_update_delivery_item_fault
    get_rtv_print_location
);

=head2 _soft_variant_lookup($id_or_object)

This function contains the business logic to find the variant associated with
the current stock process.

However, for performance sometimes want to avoid actually getting that variant
out of the database and into a dbix::class object.

If I returned the object directly before the variant object, then I give the
caller the choice themselves, but the caller then needs to know about whether
the variant is in the voucher_variant field or just the variant field. I really
want that logic here.

Therefore, the function, accepts a string called $id_or_object. If set to "id"
it returns out variant_id without the constructing a variant dbix object,
otherwise it will construct and return the object to you.

=cut

sub _soft_variant_lookup {
    my ($self, $id_or_object) = @_;

    confess("please set \$id_or_object in call to _soft_variant_lookup")
        unless defined($id_or_object);

    # given an object with a voucher_variant_id
    # field and a variant_id field, return the
    # string 'voucher_variant' or 'variant' as
    # appropriate based on if voucher_variant_id
    # is defined or not.
    my $voucher_or_variant = sub {
        my $obj = shift;
        return 'voucher_variant' if $obj->voucher_variant_id;
        return 'variant';
    };

    # given an object and a method (variant or voucher_variant)
    # use the $id_or_object variable to add '_id' to the end of the method
    # name. This can result in any of the following combinations:
    # variant / variant_id or voucher_variant / voucher_variant_id
    # Executes the function afterwards and returns the result
    my $ret_func = sub {
        my ($obj, $method_name) = @_;

        $method_name .= '_id' if ($id_or_object eq 'id');
        return $obj->$method_name();
    };

    if (my $link_to_soi = $self->delivery_item
            ->link_delivery_item__stock_order_items
                ->first) {
        my $soi = $link_to_soi->stock_order_item;
        # If you're struggling, this chained funcs emulate this behaviour
        #
        # if (defined($soi->voucher_variant_id))
        #     return $soi->voucher_variant_id if $id_or_object eq 'id';
        #     return $soi->voucher_variant;
        # else
        #     return $soi->variant_id if $id_or_object eq 'id';
        #     return $soi->variant;
        return $ret_func->($soi, $voucher_or_variant->($soi));
    }
    elsif (my $link_to_ri = $self->delivery_item
               ->link_delivery_item__return_item) {
        return $ret_func->($link_to_ri->return_item, 'variant');
    }
    elsif (my $link_to_qp = $self->delivery_item
               ->link_delivery_item__quarantine_processes
                   ->first) {
        return $ret_func->($link_to_qp->quarantine_process, 'variant');
    }
    elsif (my $link_to_si = $self->delivery_item
               ->link_delivery_item__shipment_items
                   ->first) {
        my $si = $link_to_si->shipment_item;
        return $ret_func->($si, $voucher_or_variant->($si));
    }
}

=head2 variant

Return the variant DBIC object that this stock process links to.

=cut

sub variant {
    my $self = shift;
    return $self->_soft_variant_lookup('object');
}

=head2 cached_variant

Same as ->variant, but cache the expensive lookup.

Note: If you change anything around the row, the cache will be stale,
so don't use this one.

=cut

sub cached_variant {
    my $self = shift;
    return $self->{__variant_row} ||= $self->variant;
}

=head variant_id

Don't go accessing the variant table if you just want the id

=cut

sub variant_id {
    my $self = shift;
    return $self->_soft_variant_lookup('id');
}

=head cached_variant_id

Cached implementation of variant_id

=cut
sub cached_variant_id {
    my $self = shift;
    return $self->{__variant_id} ||= $self->variant_id;
}

sub split_stock_process {
    my ( $record, $type_id, $quantity, $process_group_id ) = @_;

    my $delivery_item = $record->delivery_item;

    # Subtract faulty group value
    $record->remove_from_quantity( $quantity );

    my $resultset = $record
                  ->result_source
                  ->schema
                  ->resultset('Public::StockProcess');

    my $create_args = {
        delivery_item_id    => $delivery_item->id,
        quantity            => $quantity,
        type_id             => $type_id,
        status_id           => $STOCK_PROCESS_STATUS__NEW,
    };

    # If a process_group_id is present add it to the new record
    if ( $process_group_id ) {
        $create_args->{group_id} = $process_group_id;
    }

    # Create a new stock process entry
    my $new_record = $resultset->create( $create_args );
    # this makes sure the group id is available to see
    $new_record->discard_changes();

    return $new_record;
}

=head2 add_to_quantity

Adds given argument to quantity

=cut

sub add_to_quantity {
    my ( $self, $quantity ) = @_;
    $self->update({quantity => \[ 'quantity + ?', [ quantity => $quantity ] ]});
    return $self->discard_changes;
}

=head2 remove_from_quantity

Removes given argument from quantity

=cut

sub remove_from_quantity {
    my ( $self, $quantity ) = @_;
    $self->update({quantity => \[ 'quantity - ?', [ quantity => $quantity ] ]});
    return $self->discard_changes;
}

=head2 complete_stock_process

Marks the stock_process object as complete

=cut

sub complete_stock_process {
    return $_[0]->update({complete => 1});
}

=head2 get_group

Return a stock_process resultset of the group this stock process is in

=cut

sub get_group {
    return $_[0]->result_source->resultset->get_group($_[0]->group_id);
}

=head2 putaway_complete

Returns 1 if putaway is complete

=cut

sub putaway_complete {
    return 1 if $_[0]->putaways->count;
    return;
}

=head2 get_voucher

Returns a C<XTracker::Schema::Result::Voucher::Product> object for this stock
process if it has one.

=cut

sub get_voucher {
    return $_[0]->get_group->get_voucher;
}

=head2 leftover

Returns how many items are left to put away

=cut

sub leftover {
    my ( $self ) = @_;
    my $total_putaway = $self->putaways->total_quantity;
    return $self->quantity - $total_putaway
        if $self->quantity > $total_putaway;
    return;
}

=head2 mark_as_putaway

Sets the status to putaway

=cut

sub mark_as_putaway {
    $_[0]->update({status_id=>$STOCK_PROCESS_STATUS__PUTAWAY});
}

=head2 mark_qcfaulty_voucher

Creates the necessary logs for marking a Voucher faulty via QC.

=cut

sub mark_qcfaulty_voucher {
    my $self    = shift;
    my $op_id   = shift;

    # only do this for voucher deliveries
    if ( !$self->delivery_item->delivery->is_voucher_delivery ) {
        die "Deliver ID: ".$self->delivery_item->delivery->id.", is not a Voucher Delivery";
    }

    # get voucher variant for stock process record
    my $variant = $self->delivery_item
                        ->link_delivery_item__stock_order_items
                            ->first
                                ->stock_order_item
                                    ->voucher_variant;

    # create RTV Logs for Variant
    $variant->create_related( 'log_rtv_stocks', {
                            rtv_action_id   => $RTV_ACTION__PUTAWAY__DASH__RTV_PROCESS,
                            quantity        => $self->quantity,
                            balance         => $self->quantity,
                            operator_id     => $op_id,
                            channel_id      => $variant->product->channel_id,
                        } );
    $variant->create_related( 'log_rtv_stocks', {
                            rtv_action_id   => $RTV_ACTION__PUTAWAY__DASH__DEAD,
                            quantity        => $self->quantity,
                            balance         => $self->quantity,
                            operator_id     => $op_id,
                            channel_id      => $variant->product->channel_id,
                        } );
    $variant->create_related( 'log_rtv_stocks', {
                            rtv_action_id   => $RTV_ACTION__MANUAL_ADJUSTMENT,
                            quantity        => 0 - $self->quantity,
                            balance         => 0,
                            operator_id     => $APPLICATION_OPERATOR_ID,
                            channel_id      => $variant->product->channel_id,
                            notes           => 'Shredded',
                        } );

    # finally update the status & complete flag on the Stock Process record
    $self->update( {
            status_id   => $STOCK_PROCESS_STATUS__DEAD,
            complete    => 1,
        } );

    return 1;
}


sub stock_status_for_putaway {
    my ($self) = @_;

    return flow_status_from_stock_process_type($self->type_id,$self->get_voucher);
}

sub is_handled_by_iws {
    my ($self, $phase) = @_;

    return unless $phase;

    return flow_status_handled_by_iws($self->stock_status_for_putaway);
}

=head2 is_handled_by_prl

Returns a true value if the stock process is put away by the prl.

=cut

sub is_handled_by_prl {
    return unless config_var(qw/PRL rollout_phase/);
    return flow_status_handled_by_prl($_[0]->stock_status_for_putaway);
}

=head2 channel

Returns the channel for this stock process, via delivery item,
stock order item, stock order, purchase order.

=cut

sub channel {
    my ($self) = @_;

    return $self->variant
                ->product
                ->get_product_channel
                ->channel;
}

=head2 is_new

Returns a true value if the stock process has a status of I<New>.

=cut

sub is_new {
    shift->status_id == $STOCK_PROCESS_STATUS__NEW;
}

=head2 is_approved

Returns a true value if the stock process has a status of I<Approved>.

=cut

sub is_approved {
    shift->status_id == $STOCK_PROCESS_STATUS__APPROVED;
}

=head2 is_bagged_and_tagged

Returns a true value if the stock process has a status of I<Bagged and Tagged>.

=cut

sub is_bagged_and_tagged {
    shift->status_id == $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED;
}

=head2 is_main

Returns true if the stock process's type is I<Main>.

=cut

sub is_main {
    shift->type_id == $STOCK_PROCESS_TYPE__MAIN;
}

=head2 is_dead

Returns true if the stock process's type is I<Dead>.

=cut

sub is_dead {
    shift->type_id == $STOCK_PROCESS_TYPE__DEAD;
}

=head2 is_surplus

Returns true if the stock process's type is I<Surplus>.

=cut

sub is_surplus {
    shift->type_id == $STOCK_PROCESS_TYPE__SURPLUS;
}

=head2 is_quarantine_fixed

Returns true if the stock process's type is I<Quarantine Fixed>.

=cut

sub is_quarantine_fixed {
    shift->type_id == $STOCK_PROCESS_TYPE__QUARANTINE_FIXED;
}

=head2 is_fasttrack

Returns true if the stock process's type is I<FastTrack>.

=cut

sub is_fasttrack {
    shift->type_id == $STOCK_PROCESS_TYPE__FASTTRACK;
}

=head2 is_faulty

Returns true if the stock process's type is I<Faulty>.

=cut

sub is_faulty {
    shift->type_id == $STOCK_PROCESS_TYPE__FAULTY;
}

=head2 pre_advice_sent_but_not_putaway

Returns a true value if this stock process's pre-advice has been sent but it
has not been putaway yet.

=cut

sub pre_advice_sent_but_not_putaway {
    my ( $self ) = @_;

    # We only deal with deliveries that are part of a purchase order
    my $soi = $self->delivery_item->stock_order_item;
    return unless $soi;

    # We don't want to deal with vouchers (would need to extend conditions)
    return unless $soi->variant_id;

    if ( $self->is_main
      || $self->is_dead
      || $self->is_surplus
      || $self->is_quarantine_fixed
      || $self->is_fasttrack
    ) {
        return 1 if !$self->putaway_complete && ( $self->is_approved || $_->is_bagged_and_tagged );
    }
    return;
}

=head2 is_returns: boolean

Returns a true value if this stock process's putaway type is 'Returns'

=cut

sub is_returns {
    my $self = shift;

    return ($self->putaway_type_id // '') eq $PUTAWAY_TYPE__RETURNS;
}

=head2 return_item

Get the return item for this stock process.

=cut

sub return_item {
    my $self = shift;
    my $delivery_item_row = $self->delivery_item or return undef;
    my $return_item_rs = $delivery_item_row
        ->link_delivery_item__return_item or return undef;

    return $return_item_rs
        ->related_resultset('return_item')
        ->slice(0,0)
        ->single;
}

=head2 return_item_id : $id | undef

Get the return item id for this stock process, or undef if there isn't one.

=cut

sub return_item_id {
    my $self = shift;
    my $return_item_row = $self->return_item or return undef;
    return $return_item_row->id;
}

=head2 send_to_main( $origin, $amq )

Update this item's type to B<Main> and its status to B<Bagged and Tagged>. Also
print a stock sheet and send a PreAdvice message to our WMS. See
L<XTracker::Document::RTVStockSheet> for valid fields for $origin.

=head3 NOTE

As this is something that we would normally call against a group (return items
being a special case where a group and a stock process have a one-to-one
mapping), this should probably live in the resultset or against a
pseudo-process-group object somewhere.

=cut

sub send_to_main {
    my ( $self, $origin, $amq ) = @_;
    return $self->_bag_and_tag_as_type({
        type_id => $STOCK_PROCESS_TYPE__MAIN,
        origin  => $origin,
        amq     => $amq,
    });
}

=head2 send_to_dead( $origin, $amq )

Like L<send_to_main>, but for B<Dead> items.

=cut

sub send_to_dead {
    my ( $self, $origin, $amq ) = @_;
    return $self->_bag_and_tag_as_type({
        type_id => $STOCK_PROCESS_TYPE__DEAD,
        origin  => $origin,
        amq     => $amq,
    });
}

=head2 send_to_rtv( \%args )

Like L<send_to_main>, but for B<RTV> items. Also does some RTV stuff.

Valid arguments are:

=over

=item origin

=item amq

=item fault_type_id

=item fault_description

=item uri_path

=back

=cut

sub send_to_rtv {
    my ( $self, $args ) = @_;
    return $self->_bag_and_tag_as_type({
        type_id => $STOCK_PROCESS_TYPE__RTV,
        %$args
    });
}

=head2 send_to_rtv_customer_repair( \%args )

Like L<send_to_main>, but for B<RTV Customer Repair> items.

=cut

sub send_to_rtv_customer_repair {
    my ( $self, $args ) = @_;
    return $self->_bag_and_tag_as_type({
        type_id => $STOCK_PROCESS_TYPE__RTV_CUSTOMER_REPAIR,
        %$args
    });
}

sub _bag_and_tag_as_type {
    my $self = shift;
    my ( $type_id, $fault_type_id, $fault_description, $uri_path, $stock_sheet_origin, $amq )
        = @{$_[0]}{qw/type_id fault_type_id fault_description uri_path origin amq/};

    my %type_map = (
        $STOCK_PROCESS_TYPE__MAIN                => 'main',
        $STOCK_PROCESS_TYPE__DEAD                => 'dead',
        $STOCK_PROCESS_TYPE__RTV_CUSTOMER_REPAIR => 'rtv',
        $STOCK_PROCESS_TYPE__RTV                 => 'rtv',
    );

    my $schema = $self->result_source->schema;
    $schema->txn_do(sub{
        $self->update({
            type_id => $type_id,
            status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
        });

        my $dbh = $schema->storage->dbh;
        # We do some extra stuff for bagging and tagging rtv items
        if ( $type_map{$type_id} eq 'rtv' ) {
            if ($fault_type_id || $fault_description) {
                insert_update_delivery_item_fault({
                    dbh                 => $dbh,
                    type                => 'delivery_item_id',
                    id                  => $self->delivery_item_id,
                    fault_type_id       => $fault_type_id || 0,
                    fault_description   => $fault_description,
                });
            }

            ## insert rtv_stock_process record
            insert_rtv_stock_process({
                dbh                 => $dbh,
                stock_process_id    => $self->id,
                originating_path    => $uri_path,
                notes               => undef,
            });
        }

        my $document = XTracker::Document::RTVStockSheet->new(
            group_id        => $self->group_id,
            document_type   => $type_map{$type_id},
            origin          => $stock_sheet_origin
        );

        my $print_location = get_rtv_print_location($schema,$self->channel->id);

        $document->print_at_location($print_location);

        $amq->transform_and_send('XT::DC::Messaging::Producer::WMS::PreAdvice', { sp => $self });
    });
    return $self;
}

=head2 stock_process_rec() : $stock_process_rec

Return a stock process record, suitable for putting away
$actual_quantity of the Variant into $location_row.

The stock $process_record_rec hashref include keys for the expected
"quantity" (from this StockProcess) and the actually scanned
"ext_quantity" (from $quantity).

=cut

sub stock_process_rec {
    my ($self, $actual_quantity, $location_row) = validated_list( \@_,
        actual_quantity => { isa => "Int" },
        location_row    => { isa => 'XTracker::Schema::Result::Public::Location' },
    );

    return {
        id                    => $self->id,
        variant_id            => $self->cached_variant->id,
        stock_process_type_id => $self->type_id,
        return_item_id        => $self->return_item_id,
        group_id              => $self->group_id,

        # Expected, as reported by StockProcess
        quantity              => $self->quantity,
        # Actually putaway, as scanned by the user and reported by the
        # Inventories
        ext_quantity          => $actual_quantity,

        location_id           => $location_row->id,
        location              => $location_row,
    };
}

=head2 get_client

Return the associated client

=cut
sub get_client {
    my ($self) = @_;
    return $self->variant()->get_client();
}

1;
