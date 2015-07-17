package Test::XT::Flow::StockControl::Quarantine;

=head1 NAME

Test::XT::Flow::StockControl::Inventory::StockQuarantine - Quarantine products
via the inventory

=head1 DESCRIPTION

Traits to step through the quarantine process via inventory

=cut

use NAP::policy "tt", qw( test role );

use Carp qw(croak);
use XTracker::Database::StockProcess qw(get_quarantine_process_group );
use XTracker::Constants::FromDB qw( :flow_status );
use XTracker::Stock::GoodsIn::Putaway;

with 'Test::XT::Flow::AutoMethods';

=head1 PROCESS OVERVIEW

=head1 METHODS

=head2 flow_db__stockcontrol__quarantine_find_product

Pull a quarantinable product and variant from the DB. Returns a hash with the
following keys:

=over

=item C<variant_object> - L<XTracker::Schema::Result::Public::Variant>

=item C<product_object> - L<XTracker::Schema::Result::Public::Product>

=item C<channel_object> - L<XTracker::Schema::Result::Public::Channel>

=item C<location_object> - L<XTracker::Schema::Result::Public::Location>

=item C<location_from> - Location we're taking from (string)

=item C<variant_sku> - SKU of our target variant (string)

=item C<variant_quantity> - Number of main-stock items of variant in returned
location

=back

=cut

sub flow_db__stockcontrol__quarantine_find_product {
    my $self = shift;

    note "Finding an appropriate product";

    # Select a product from the database and ensure stock for it
    my( $channel, $products ) = Test::XTracker::Data->grab_products({
        how_many => 1
    });
    my $product = $products->[0];

    my $row = {
        variant_object   => $product->{'variant'},
        product_object   => $product->{'product'},
        channel_object   => $channel,
        variant_sku      => $product->{'sku'}
    };

    note "Setting a positive stock level";
    my $quantity = 12;

    my $location = Test::XTracker::Data->set_product_stock({
        variant_id   => $row->{'variant_object'}->id,
        channel_id   => $channel->id,
        stock_status => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        quantity     => $quantity
    });
    $row->{'location_object'}  = $location;
    $row->{'location_from'}    = $location->location;
    $row->{'variant_quantity'} = $quantity;

    note "Target product:";
    for my $key ( keys %{$row} ) {
        my $value = $row->{$key};
        if ( eval{ $value->can('id') } ) {
            $value = $value->id;
        }
        note "\t$key: [$value]";
    }

    return $row;
}

=head2 flow_mech__stockcontrol__inventory_stockquarantine

Retrieve the Inventory's Stock Quarantine page for a given product. You must
provide the product id as sole argument.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__stockcontrol__inventory_stockquarantine',
    page_description => 'Stock Quarantine Page',
    page_url         => '/StockControl/Inventory/StockQuarantine?product_id=',
    required_param   => 'Product ID'
);

=head2 flow_mech__stockcontrol__inventory_stockquarantine_submit

Quarantine a given product in a given location. Accepts a hash, with the
following keys:

=over

=item C<variant_id> - I<Req> Variant ID or, row object

=item C<location> - I<Req> Location string, or row object

=item C<quantity> - I<Opt> The number of the item to quarantine. Defaults to
all of the ones in the target location if not defined

=item C<type> - I<Req> C<L> for faulty, C<V> for non-faulty, as per the
underlying codes on the page for each type

The quarantine note will be set automatically (and randomly) to aid in finding
the item again.

=head3 Return values

This method returns something different depending on the C<type> specified, as
the type specified affects what happens next. B<THE FIRST ARGUMENT RETURNED IS
ALWAYS THE QUARANTINE NOTE. THE SECOND ARGUMENT SPECIFIED BELOW:>

B<Non-faulty>

If you specify non-faulty, the goods acquire a status of 'RTV Transfer Pending',
and you will get the process group ID back as an C<Int> - they'll show up next
in Put-Away (where you can find them using the process group ID).

B<Faulty>

If you specify faulty, you will need to further specify what kind of faulty the
goods are. You'll need to open the items up in the Quarantine Manager, which is
what the rest of the methods in this Role do. To do this, you'll need the ID
of the Quantity row the goods are in - the Quantity object itself is returned.

B<Transit>

If you specify transit, you will need to further specify what kind of faulty the
goods are. You'll need to open the items up in the Quarantine Manager, which is
what the rest of the methods in this Role do. To do this, you'll need the ID
of the Quantity row the goods are in - the Quantity object itself is returned.

=cut

sub flow_mech__stockcontrol__inventory_stockquarantine_submit {
    my ( $self, %args ) = @_;
    $self->assert_location(qr!^/StockControl/Inventory/StockQuarantine!);

    # Check the arguments
    for (qw( variant_id location )) {
        croak "You must provide a $_" unless $args{$_};
    }
    croak "Please provide a type of L, V or T" unless
        ( $args{'type'} && ( $args{'type'} eq 'L' || $args{'type'} eq 'V' || $args{'type'} eq 'T' ) );

    # Get the info we want if we've been passed in DB rows
    $args{'location'} = $args{'location'}->location if ref $args{'location'};
    $args{'variant_id'} = $args{'variant_id'}->id if ref $args{'variant_id'};

    # Lookup the magic field names we'll need to submit the form
    my $quarantine_page = $self->mech->as_data->{'nap_table'};

    my ($variant) =
        # Look for matching SKU and location
        grep {
            $_->{'SKU'}->{'input_value'} == $args{'variant_id'} &&
            $_->{'Location'}->{'value'} eq $args{'location'}
        # Data in the Quarantine Stock table
        } map {
            @{ $_->{'Quarantine Stock'} };
        # Data from each channel
        } values %{$quarantine_page};

    # Fill in the quantity if it's not already there
    ok( $variant, "Found a variant that matches in Inventory page" ) ||
        croak "Couldn't find your variant - bailing out";
    $args{'quantity'} = $variant->{'Quantity'}->{'input_value'}
        unless defined $args{'quantity'};

    # Create a 'unique' Quarantine Note so we can more easily find our created
    # row.
    my $quarantine_note = 'Test QNote: ' . int(rand(1_000_000_000));
    note "Quarantine note is [$quarantine_note]";

    # Submit the quarantine request
    $self->mech->submit_form(
        with_fields => {
            $variant->{'Notes'}->{'input_name'}   => $quarantine_note,
            $variant->{'Reason'}->{'select_name'} => $args{'type'},
            $variant->{'Quarantine'}->{'input_name'} => $args{'quantity'}
        }
    );
    $self->note_status();

    # Decide what we're going to return
    if ( $args{'type'} eq 'V' ) {
        return $quarantine_note,
            $self->_stockcontrol__find_process_group_id( $args{'variant_id'} );
    # Get the Quantity table ID if it was faulty
    } else {
#       The right way to do this. Hidden until we get Public::QuantityDetails
#        my $quantity_id =
#            $self->schema->resultset('Public::QuantityDetails')->search({
#                details => $quarantine_note
#            })->first->quantity;
#
#        note "Quantity Table row ID is [$quantity->id]";
#        return $quantity;
        my $qid_sql = $self->dbh->prepare('
            SELECT q.id FROM
                quantity q, quantity_details qd, location l
            WHERE
                l.id = q.location_id AND
                l.location = \'Quarantine\' AND
                q.variant_id = ? AND
                qd.quantity_id = q.id AND
                qd.details = ?
            ORDER BY q.id DESC
        ');
        $qid_sql->execute(
            $args{'variant_id'},
            $quarantine_note
        );
        my $quantity_id = $qid_sql->fetchrow_arrayref->[0];
        note "Quantity Table row ID is [$quantity_id]";
        return $quarantine_note,
            $self->schema->resultset('Public::Quantity')->find( $quantity_id );
    }

}

# Lookup the process group id. This currently works very naively - see inside
# the sub for more details on that...

sub _stockcontrol__find_process_group_id {
    my $self = shift;
    note "Looking up Process Group ID";

    # I have wasted enough time on trying to do this the right way so far.
    # Efforts are saved for posterity:
    # my $process_id_query = $self->dbh->prepare('
        # SELECT sp.group_id FROM delivery del
        # JOIN delivery_item di ON (di.delivery_id = del.id)
        # JOIN stock_process sp ON (
#        # sp.delivery_item_id = di.id AND sp.quantity <> 0
        # )
        # JOIN link_delivery_item__stock_order_item di_soi ON (di_soi.delivery_item_id = di.id)
        # JOIN stock_order_item soi ON (di_soi.stock_order_item_id = soi.id)
        # JOIN variant v ON (soi.variant_id = v.id)
        # WHERE v.id = ?
        # ORDER BY sp.group_id DESC
        # LIMIT 1
    # ');
    # $process_id_query->execute( $self->attr__stockcontrol__inventory_stockquarantine_variant_id );
    # my ( $process_group_id ) = $process_id_query->fetchrow_arrayref->[0];

    # This way is going to work under all but exceptional circumstances - fix
    # if you feel inclined...
    my $process_id_query = $self->dbh->prepare('
        select group_id from stock_process order by id desc limit 1
    ');
    $process_id_query->execute();
    my $process_group_id = $process_id_query->fetchrow_arrayref->[0];

    note "Process ID is [$process_group_id]";

    return $process_group_id;
}

=head2 flow_mech__stockcontrol__quarantine_processitem

If you quarantined goods as faulty, you now need to tell the system what you
want done with them. This method retrieves the page that allows you to do that.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__stockcontrol__quarantine_processitem',
    page_description => 'Quarantine Item Process Page',
    page_url         => '/StockControl/Quarantine/ProcessItem?id=',
    required_param   => 'Quantity Row ID'
);

=head2 flow_mech__stockcontrol__quarantine_processitem_submit

Your options are C<stock> for return to stock, C<rtv>
for RTV, and C<dead>, for Dead Stock. Provide these as a hash of how many you
want to put in each state:

 $flow->flow_mech__stockcontrol__quarantine_processitem_submit(
   dead   => 1,
   rtv    => 1,
   stock  => 2,
 );

Returns the Process Group ID.

=cut

sub flow_mech__stockcontrol__quarantine_processitem_submit {
    my ( $self, %args ) = @_;
    note "Submitting Quarantine Process Form";
    $self->mech->submit_form( with_fields => {
        map { $_ => $args{$_} || 0 } qw( stock rtv dead )
    }) && $self->note_status();
    return $self->_stockcontrol__find_process_group_id;
}

1;
