package XTracker::Schema::ResultSet::Public::StockProcess;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

__PACKAGE__->load_components(qw{Helper::ResultSet::SetOperations});

use Carp;

use NAP::XT::Exception::Stock::IncorrectStatusForPGIDAction;

use XTracker::Constants::FromDB qw(
    :delivery_action
    :stock_process_status
    :stock_process_type
);

use XTracker::Database::StockProcess qw( :iws );
use XTracker::Config::Local qw( config_var );

=head1 NAME

XTracker::Schema::ResultSet::Public::StockProcess

=head1 METHODS

=head1 METHODS

=head2 all_ordered : @stock_process_rows

Return list of all rows ordered by variant id, id.

=cut

sub all_ordered {
    my $self = shift;
    my @rows = sort {
           $a->cached_variant->id <=> $b->cached_variant->id
        || $a->id <=> $b->id
    } $self->all;
    return @rows;
}

=head2 log_putaway

Log an entry for putaway for this delivery. Is a wrapper around
C<Public::Delivery->log>. The sub will die if the group_ids of the
stock_processes don't match unless one is specified.

 $rs->get_group($group_id)->log_putaway({
    type_id => $type_id,
    operator => $operator_id,
    #optional
    notes => $notes,
 });

=cut

sub log_putaway {
    my ( $self, $args ) = @_;

    die "The group ids of the resultset don't match"
        unless $self->_group_ids_match();

    croak "type_id $args->{type_id} is not an accepted value"
        unless defined $args->{type_id}
           and grep { $_ == $args->{type_id} } (
            $STOCK_PROCESS_TYPE__FASTTRACK,
            $STOCK_PROCESS_TYPE__MAIN,
            $STOCK_PROCESS_TYPE__SURPLUS, );

    $args->{delivery_action_id} = $DELIVERY_ACTION__PUTAWAY;
    $args->{quantity} = $self->total_quantity;
    return $self->related_resultset('delivery_item')
                ->related_resultset('delivery')
                ->first
                ->_log($args);
}

=head2 print_pgid_barcode

Print the PGID barcode label for the process group ID of the resultset
we are called on. This will die if the group_ids of the stock_processes
don't match.

Called as follows:

 $rs->get_group($group_id)->print_pgid_barcode($printer,$copies);

=cut

sub print_pgid_barcode {
    my ( $self, $printer, $copies ) = @_;

    die "The group ids of the resultset don't match"
        unless $self->_group_ids_match();

    # Get the data we need for the label
    my $label_data;
    my $sp = $self->first;
    my $pgid = $sp->group_id;
    my $pgid_prefix = config_var('IWS', 'rollout_phase') == 0 ? '' : 'p-';
    $label_data->{group_id} = $pgid_prefix . $pgid;
    $label_data->{sku} = $sp->variant->sku;

    # Create the label and print it
    my $label;
    my $l_template = XTracker::XTemplate->template();
    $l_template->process( 'print/returns_label.tt', { template_type => 'none', %$label_data }, \$label );

    # Write label to file
    my $fh = File::Temp->new(
        TEMPLATE => XTracker::PrintFunctions::path_for_print_document({
            document_type => 'label',
            id => 'XXXXXXXX',
            extension => '', # template for File::Temp must have no extension
        })
    );
    my $filename = $fh->filename;
    print $fh $label;
    close $fh;

    # Print file
    $printer = XTracker::PrinterMatrix->new->get_printer_by_name($printer) unless ref($printer);
    XT::LP->print({printer => $printer->{lp_name}, filename => $filename, copies => $copies, });
}

=head2 get_voucher

Returns a C<XTracker::Schema::Result::Voucher::Product> object for this stock
process group if it has one.

=cut

sub get_voucher {
    return $_[0]->related_resultset('delivery_item')
                ->related_resultset('delivery')
                ->related_resultset('link_delivery__stock_order')
                ->related_resultset('stock_order')
                ->related_resultset('voucher_product')
                ->first;
}

=head2 get_group

Return a resultset of stock_processes with the given group_id

=cut

sub get_group {
    my ( $self, $group_id ) = @_;
    croak 'No group_id specified' unless defined $group_id;
    $group_id =~ s/^p-//i;
    my $me = $self->current_source_alias;
    return $self->search({"$me.group_id"=>$group_id});
}

=head2 main

Only include stock processes whose type is B<Main>.

=cut

sub main { shift->get_by_type( $STOCK_PROCESS_TYPE__MAIN ); }

=head2 faulty

Only include stock processes whose type is B<Faulty>.

=cut

sub faulty { shift->get_by_type($STOCK_PROCESS_TYPE__FAULTY); }

=head2 get_by_type( $type_id )

Only include the given C<$type_id> in this resultset.

=cut

sub get_by_type {
    my ( $self, $type_id ) = @_;
    my $me = $self->current_source_alias;
    return $self->search({"$me.type_id" => $type_id});
}

=head2 pending_putaway

Returns items pending putaway. Is a wrapper around C<pending_items>.

=cut

sub pending_putaway {
    return $_[0]->pending_items($STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED);
}

=head2 pending_items

Returns pending items. Needs to be chained to get_group, or will die if the
group ids of the items in the rs don't match.

=cut

sub pending_items {
    my ( $self, $status_id, $type_id ) = @_;
    die "The group ids of the resultset don't match"
        unless $self->_group_ids_match();

    # pending_items for putaway gets all type_ids except for 'All' and
    # 'Unknown', which aren't used - so until this sub is extended to work for
    # other parts of the system a type_id does not need to be specified
    my $me = $self->current_source_alias;

    my $param = { "$me.quantity" => { q{>} => 0 },
                  "$me.status_id" => $status_id, };

    $param->{"$me.type_id"} = $type_id if $type_id;

    return $self->search($param);
}

=head2 total_quantity

Get the sum of the quantity column of rows on the given resultset.

=cut

sub total_quantity {
    return $_[0]->get_column('quantity')->sum;
}

=head2 is_complete

Returns true if all the stock processes are complete. Useful to see if a group
is complete.

=cut

sub is_complete {
    return $_[0]->get_column('complete')->func('BOOL_AND');
}

# Given a resultset this sub will check all of the row items' group ids match
sub _group_ids_match {
    return 1;
#    warn $_[0]->result_source->resultset->search({group_id=>{-between=>[634365,634370]}})->get_column('group_id')->func('DISTINCT');
#    warn $_[0]->get_column('group_id')->func('DISTINCT');
#    return scalar $_[0]->get_column('group_id')->func('DISTINCT')->all == 1;
}

=head2 putaway_process_groups

Returns a hashref with data for the Goods In -> Putaway page.

=cut

sub putaway_process_groups {
    my ($self, $phase) = @_;

    return $self->get_process_groups( $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED, 'putaway', $phase );
}

=head2 putaway_process_groups

Returns a hashref with data for the Goods In -> PutawayPrep page.

=cut

sub putaway_prep_process_groups {
    my ($self, $phase) = @_;

    return $self->get_process_groups( $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED, 'putaway_prep', $phase );
}

=head2 get_process_groups

Returns a hashref with stock_process data for the given status_id. Replaces
part of XTracker::Database::StockProcess::get_process_group.

=cut

sub get_process_groups {
    my ( $self, $status_id, $context ) = @_;
    my $dbh = $self->result_source->storage->dbh;

    my $qry = <<END_OF_QUERY;
    SELECT  sp.group_id,
            del.id AS delivery_id,
            del.on_hold,
            SUM( sp.quantity ) AS quantity,
            TO_CHAR( del.date, 'DD-MM-YYYY' ) AS date,
            spt.type,
            spt.id AS sp_type_id,
            ch.name AS sales_channel,

            -- PRODUCT FIELDS
            p.id AS product_id,
            d.designer,
            pc.live,
            TO_CHAR( pc.upload_date, 'DD-MM-YYYY' ) AS upload_date,
            CASE WHEN pc.upload_date < current_timestamp - interval '3 days'
                THEN 1
                ELSE 0
            END AS priority,

            -- VOUCHER FIELDS
            v.id AS voucher_id

    FROM delivery del
    JOIN delivery_item di       ON (di.delivery_id      = del.id)
    JOIN stock_process sp       ON (sp.delivery_item_id = di.id)
    JOIN stock_process_type spt ON (sp.type_id          = spt.id)

    JOIN link_delivery__stock_order ldso ON (del.id                = ldso.delivery_id)
    JOIN stock_order so                  ON (ldso.stock_order_id   = so.id)
    JOIN super_purchase_order po         ON ( so.purchase_order_id = po.id )
    JOIN channel ch                      ON ( po.channel_id        = ch.id )

    -- PRODUCT JOINS
    LEFT JOIN product p          ON (so.product_id = p.id)
    LEFT JOIN product_channel pc ON (p.id          = pc.product_id)
    LEFT JOIN designer d         ON (p.designer_id = d.id)

    -- VOUCHER JOINS
    LEFT JOIN voucher.product v ON (so.voucher_product_id = v.id)

        WHERE sp.complete = false
        AND sp.quantity <> 0
        AND sp.status_id = ?
    GROUP BY sp.group_id, del.id, del.on_hold, p.id, d.designer, del.date,
            spt.type, sp_type_id, pc.upload_date, pc.live, ch.name, v.id
END_OF_QUERY
    my $sth = $dbh->prepare($qry);
    $sth->execute( $status_id );

    my $data;

    while ( my $row = $sth->fetchrow_hashref ) {
        $data->{ delete $row->{sales_channel} }{ $row->{group_id} } = $row
            if XTracker::Database::StockProcess::include_process_group($row->{sp_type_id}, $context, $row->{group_id}, $self->result_source->schema);
    }

    return $data;
}

=head2 generate_new_group_id

Returns a newly generated group_id.

=cut

sub generate_new_group_id {
    return $_[0]->result_source->schema->storage->dbh
        ->selectrow_arrayref(q{select nextval('process_group_id_seq')})->[0];
}


=head2 stock_process_data_for_group_ids

Returns a hashref of stock process data keyed on group_id, given an
arrayref of group ids.

Prefetches related delivery, stock order and return information too.

Designed specifically to fetch the data required for the putaway admin
handler (XTracker::Stock::GoodsIn::PutawayAdmin), which passes in the group
ids linked to active putaway_prep_inventory rows.

=cut

sub stock_process_data_for_group_ids {
    my ( $self, $group_ids ) = @_;

    # Look up all possibly related stock_processes, joining their useful links
    # to either stock_order_item or return_order_item, and capturing delivery
    # information
    my $stock_process_rs = $self
        ->search({
            'group_id' => { IN => $group_ids }
        }, {
            prefetch => {
                delivery_item => 'delivery'
            }
        });

    # We want them as a hashref because we're read-only and don't need any of
    # their magical methods
    $stock_process_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');

    # Map stock processes by group_id, calculate things we're interested in for each one
    my $stock_processes;
    foreach my $sp ($stock_process_rs->all) {
        $stock_processes->{$sp->{'group_id'}}->{'stock_process_rows'} //= [];
        push @{$stock_processes->{$sp->{'group_id'}}->{'stock_process_rows'}}, $sp;
        $stock_processes->{$sp->{'group_id'}}->{'quantity'} += $sp->{'quantity'};
    }

    return $stock_processes;

}

sub get_putaway_type_id_for_group_id {
    my ($self, $group_id) = @_;

    my $row = $self->search({
        group_id        => $group_id,
        putaway_type_id => { "!=" => undef },
    })->first or return undef;

    return $row->putaway_type_id;
}

sub set_putaway_type_id_for_group_id {
    my ($self, $group_id, $putaway_type_id) = @_;
    $self->search({
        group_id => $group_id,
    })->update({
        putaway_type_id => $putaway_type_id,
    });
}

sub approved_but_not_completed {
    my ( $self ) = @_;
    my $me = $self->current_source_alias;

    return $self->search(
        {
            "$me.status_id" => { -in => [
                $STOCK_PROCESS_STATUS__APPROVED,
                $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
                $STOCK_PROCESS_STATUS__PUTAWAY,
            ] },
            quantity => { '>' => 0 },
            complete => 0,
        },
    );
}

sub pgids {
    my ( $self ) = @_;
    my $me = $self->current_source_alias;

    return $self->search(
        {},
        {
            columns => ["$me.group_id"],
            distinct => 1,
        },
    );
}

=head2 bag_and_tag( $group_id ) : $stock_processes_updated_count

Bag and tag stock processes belonging to the given C<$group_id>.

=cut

sub bag_and_tag {
    my ( $self, $group_id ) = @_;

    my $group_rs = $self->get_group($group_id);

    my $updated_count;
    $self->result_source->schema->txn_do(sub{
        # Firstly, let's lock the rows to prevent concurrent updates. Make sure
        # we provide an explicit order by to prevent deadlocks.
        $group_rs->search({}, {order_by => 'id', for => 'update'})->all;

        # Then we can do our status check
        # We have to check for non-zero quantity as these don't get processed
        # at QC, so we're left with zero quantity stock processes that are in
        # an 'incorect' state (New). We should also look at using the
        # 'complete' flag here... this doesn't happen currently, but hopefully
        # one day we'll make use of it properly.
        my $is_all_approved = !$group_rs->search({
            quantity  => { q{>} => 0 },
            status_id => { q{!=} => $STOCK_PROCESS_STATUS__APPROVED },
        })->count;

        NAP::XT::Exception::Stock::IncorrectStatusForPGIDAction->throw(
            { group_id => $group_id, action => 'Bag and Tag', }
        ) unless $is_all_approved;

        $updated_count = $group_rs
            ->update({status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED});

        $group_rs->related_resultset('delivery_item')
            ->search_related('delivery', undef, { rows => 1})
            ->single
            ->log_bag_and_tag({
                type_id  => $group_rs->get_column('type_id')->first,
                quantity => $group_rs->get_column('quantity')->sum,
            });
    });
    return $updated_count;
}

1;
