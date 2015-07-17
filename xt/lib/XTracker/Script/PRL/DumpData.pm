package XTracker::Script::PRL::DumpData;

use Moose;

use Text::CSV_XS;
use Try::Tiny;

extends 'XTracker::Script';

with 'XTracker::Script::Feature::SingleInstance',
     'XTracker::Script::Feature::Schema',
     'XTracker::Script::Feature::Verbose',

     # current class has utility to deal with CSV files,
     # (and accessor that holds directory name where CSV files are located
     # has name of "dump_directory")
     'XTracker::Script::Feature::CSV' => {
        csv_directory => 'dump_directory'
     };

use XTracker::DBEncode qw[ decode_db ];
use XTracker::Constants::FromDB qw( :flow_status );
use XTracker::Constants qw/:prl_type/; # Imports $PRL_TYPE__*

=head1 NAME

XTracker::Script::PRL::DumpData

=head1 DESCRIPTION

Provides methods that dump data to be transformed from XTtracker to
PRL application.

Dump data is in form of CSV files.

=head1 SYNOPSIS

    my $dumper = XTracker::Script::PRL::DumpData->new({
        filename_location   => 'locations.csv',
        filename_products   => 'products.csv',
        filename_quantities => 'quantities.csv',
    });

    $dumper->invoke();

or

    my $dumper = XTracker::Script::PRL::DumpData->new();

    $dumper->dump_directory('/tmp/temp');
    $dumper->filename_location('pavel.csv');
    $dumper->dump_locations;

or

    my $dumper = XTracker::Script::PRL::DumpData->new();

    $dumper->verbose(0);
    $dumper->dump_directory('/tmp/temp');
    $dumper->filename_location('pavel.csv');
    $dumper->statuses([qw/list of statuses/]);
    $dumper->excluded_locations([qw/list of lo0cations to be excluded from results/]);

    $dumper->dump_locations;

=head1 ATTRIBUTES

=head2 filename_location

B<Description>

Name of file with exported locations.

=cut

has 'filename_location'   => (is => 'rw', default => 'location.csv');

=head2 filename_quantities

B<Description>

Name of file with data about quantities.

=cut

has 'filename_quantities' => (is => 'rw', default => 'quantities.csv');

=head2 filename_products

B<Description>

Name of file with products data.

=cut

has 'filename_products'   => (is => 'rw', default => 'products.csv');

=head2 filename_location_sql

B<Description>

Name of file with sql to run to update locations in XT after migration.

=cut

has 'filename_location_sql'   => (is => 'rw', default => 'location_migration.sql');

=head2 filename_quantities_sql

B<Description>

Name of file with sql to run to update quantities in XT after migration.

=cut

has 'filename_quantities_sql'   => (is => 'rw', default => 'quantity_migration.sql');

=head2 prl_location_name

B<Description>

Value of location.location for the PRL we're migrating stock into.

=cut

has 'prl_location_name'   => (is => 'rw', default => 'Full PRL');

=head2 prl_location_id

B<Description>

Value of location.id for the PRL we're migrating stock into.

=cut

has 'prl_location_id'   => (
    is      => 'ro',
    lazy    => 1,
    builder => '_set_prl_location_id',
);

sub _set_prl_location_id {
    my $self = shift;
    my $location = $self->schema->resultset('Public::Location')->search({
        location => $self->prl_location_name,
    })->first;
    die "no location matching ".$self->prl_location_name unless $location;
    return $location->id;
}

=head2 statuses

B<Description>

Array ref with quantity statuses which are going to be dumped.

If undefined, all quantity rows will be dumped regardless of status.

=cut

has 'statuses' => (
    is => 'rw',
    default => sub { [
        $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS
    ] },
);

=head2 excluded_locations

B<Description>

Array ref with locations to be excluded from migration.

Default is all "special" and PRL locations - i.e. anything not starting with 0

(Normal locations look like e.g. 021A-0003A)

=cut

has 'excluded_locations' => (
    is => 'rw',
    default => sub {
        my $self = shift;
        my @excluded_locations = $self->schema->resultset('Public::Location')->search({
            location => \"NOT LIKE '0\%'",
        })->get_column('location')->all;
        return \@excluded_locations;
    },
);

=head1 METHODS

=head2 invoke

B<Description>

This is a main entry point to script.
It dumps locations, products and quantities information.

=cut

sub invoke {
    my ($self, $args) = @_;

    $self->inform("Setting up...\n");

    # each action is independent
    try {
        $self->dump_locations;
    } catch {
        $self->inform("\n\nFailed to extract locations! Got error: '$_' \n\n");
    };

    try {
        $self->dump_products;
    } catch {
        $self->inform("\n\nFailed to extract products! Got error: '$_' \n\n");
    };

    try {
        $self->dump_quantities;
    } catch {
        $self->inform("\n\nFailed to extract quantities! Got error: '$_'\n\n");
    };

    $self->inform("\nDone!\n");

    return 0;
}

=head2 dump_locations

B<Description>

Dump all locations into file name specified in B<filename_location>. Result
excludes locations listed in B<excluded_locations>.

=cut

sub dump_locations {
    my ($self) = @_;

    # this array sets list of columns in output file as well as their order
    my @columns  = qw(name allowed_status);

    # try to open output files
    my $fh     = $self->open_file( $self->filename_location );
    my $sql_fh = $self->open_file( $self->filename_location_sql );

    # add header to output file
    $self->csv->print( $fh, [ @columns ] );

    $self->inform("\nGetting location data...\n");

    my $location_rs = $self->schema->resultset('Public::Location')->search(
        {
            'location'  => { '-not_in' => $self->excluded_locations },
        },
        {
            'join'     => { 'location_allowed_statuses' => 'status' },
            'order_by' => 'location',
        },
    );

    $self->init_progress($location_rs->count);

    my $i;

    while ( my $row = $location_rs->next ) {
        $self->update_progress(++$i);

        my %line;

        # FIXME NOTE this is probably not right and some investigation is needed,
        # probably it is better to use 'allowed_status' accessor
        $line{'allowed_status'} = join ';',
             map { $_->status->name }
             $row->location_allowed_statuses;

        #Get location
        $line{'name'} = $row->location;

        $self->csv->print( $fh, [ @line{@columns} ] );

        print $sql_fh "delete from location_allowed_status where location_id = ".$row->id
            ." and status_id in ("
            ."$FLOW_STATUS__MAIN_STOCK__STOCK_STATUS, $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS".
            ");\n";
    }

    # close output files
    $self->close_file($fh);
    $self->close_file($sql_fh);

    $self->inform(
        "\nLocations are dumped, please, check ",
        $self->dump_directory, '/', $self->filename_location,
        " file\n"
    );
}

=head2 dump_products

B<Description>

Dumps all products and vouchers into file specified in B<filename_products>.

=cut

sub dump_products {
    my ($self) = @_;

    # define columns and their order in result file
    my @columns = qw(sku storage_type name description photo_link channel designer
                     colour length weight client size family);
    # try to open output file
    my $fh = $self->open_file($self->filename_products);

    # add header to result file
    $self->csv->print( $fh, \@columns );

    $self->inform("\nGetting product data...\n");

    my $sth = $self->dbh->prepare( <<SQL
        SELECT
           p.id,
           (v.product_id::text || '-'::text) || sku_padding(v.size_id)::text AS sku,
           coalesce(st.name,'Flat') AS storage_type,
           pa.description           AS description,
           c.name                   AS channel,
           d.designer               AS designer,
           col.colour               AS colour,
           vm.value                 AS length,
           sa.weight                AS weight,
           pa.name                  AS name,
           s.size                   AS size
        FROM product p
           LEFT JOIN product_attribute pa    ON pa.product_id = p.id
           LEFT JOIN product.storage_type st ON st.id         = p.storage_type_id
           LEFT JOIN channel c               ON c.id          = get_product_channel_id(p.id)
           LEFT JOIN designer d              ON d.id          = p.designer_id
           LEFT JOIN colour col              ON col.id        = p.colour_id
           LEFT JOIN variant v               ON v.product_id  = p.id
           LEFT JOIN variant_measurement vm  ON ( v.id = vm.variant_id AND vm.measurement_id = '3')
           LEFT JOIN shipping_attribute sa   ON sa.product_id = p.id
           LEFT JOIN size s                  ON v.designer_size_id = s.id
        WHERE
           c.name IS NOT NULL
SQL
);
    $sth->execute();

    $self->init_progress();

    my ($i, %printed_skus);

    while( my $row = $sth->fetchrow_hashref() ) {

        $self->update_progress(++$i);

        next if $printed_skus{ $row->{sku} };

        $row->{photo_link} = sprintf
            'http://cache.net-a-porter.com/images/products/%s/%s_in_l.jpg', $row->{id}, $row->{id};

        $row->{client} = ( $row->{channel} eq 'JIMMYCHOO.COM' ) ? 'CHO' : 'NAP';
        $row->{family} = $PRL_TYPE__FAMILY__GARMENT;

        # use decode_db because things like designer name ended up double-encoded otherwise
        $self->csv->print( $fh, [ map {decode_db($_) } @$row{@columns} ] );
        $printed_skus{ $row->{sku} } = 1;
    }


    #Vouchers only
    $self->inform("\nStarted to dump vouchers.\n");

    my $product_rs = $self->schema->resultset( 'Voucher::Product' )->search(
        {
            'is_physical' => { '=', 'true' },
        },
        {
            join     => 'channel',
            order_by => 'id ASC',
        },
    );

    $i=0;

    $self->init_progress($product_rs->count);

    while ( my $row = $product_rs->next ) {

        $self->update_progress(++$i);

        my %line;
        $line{sku}          = $row->id.'-999';
        $line{storage_type} = 'Flat';
        $line{description}  = $row->name;
        $line{name}         = $row->channel->name;
        $line{size}         = '-';
        $line{photo_link}   = sprintf( 'http://cache.net-a-porter.com/images/products/%s/%s_in_l.jpg', $row->id, $row->id );
        $line{client}       = ( $row->channel->name eq 'JIMMYCHOO.COM' ) ? 'CHO' : 'NAP';
        $line{family}       = $PRL_TYPE__FAMILY__VOUCHER;

        $self->csv->print( $fh, [ @line{ @columns } ] );
    }

    # close output file
    $self->close_file($fh);

    $self->inform(
        "\nQuantities are dumped, please, check ",
        $self->dump_directory, '/', $self->filename_quantities,
        " file\n"
    );
}

=head2 dump_quantities

B<Description>

Dumps data related to quantities into file specified in B<filename_quantities>.

Restrict by status if $self->statuses is set.

=cut

sub dump_quantities {
    my ($self) = @_;

    my @columns = qw(sku location quantity channel allowed_status);

    my $fh     = $self->open_file( $self->filename_quantities );
    my $sql_fh = $self->open_file( $self->filename_quantities_sql );

    $self->csv->print( $fh, \@columns );

    $self->inform("\nGathering location quantities...\n");

    my $search_conds = {
            'location'  => { '-not_in' => $self->excluded_locations },
    };
    if ($self->statuses) {
        $search_conds->{'status_id'} = { '-in'     => $self->statuses };
    };
    my $quantity_rs = $self->schema->resultset( 'Public::Quantity' )->search(
        $search_conds,
        {
            'join' => 'location',
        },
    );

    $self->init_progress($quantity_rs->count);
    my $i;

    my %unique_quantities;
    while ( my $row = $quantity_rs->next ) {

        $self->update_progress(++$i);

        next unless defined $row->product_variant;

        # These fields + location_id have to be unique
        my $unique_identifier = $row->variant_id."-".$row->channel_id."-".$row->status_id;

        my %line;
        $line{sku}          = $row->product_variant->sku;
        $line{location}     = $row->location->location;
        $line{quantity}     = $row->quantity;
        $line{channel}      = $row->channel->name;
        $line{allowed_status} = $row->status->name;

        $self->csv->print( $fh, [ @line{ @columns } ] );

        if ($unique_quantities{$unique_identifier}) {
            # We've already updated a quantity row for this variant+channel+status
            # to use the new location, so we'll add the quantity from this one, and
            # then delete this row.
            print $sql_fh "update quantity set quantity = quantity + ".$row->quantity
                ." where id = ".$unique_quantities{$unique_identifier}.";\n";
            print $sql_fh "delete from quantity"
                ." where id = ".$row->id.";\n";
        } else {
            # It's the first time we've seen this variant+channel+status combination,
            # so we should be able to update the existing row to point at the PRL
            # location.
            print $sql_fh "update quantity set location_id=".$self->prl_location_id
                ." where id = ".$row->id.";\n";

            $unique_quantities{$unique_identifier} = $row->id;
        }
    }


    $self->inform("\nGathering voucher quantities...\n");

    $i = 0;

    $quantity_rs = $self->schema->resultset( 'Public::Quantity' )->search(
        $search_conds,
        {
            join => [ 'voucher_variant', 'location', 'channel' ],
        },

    );


    $self->init_progress($quantity_rs->count);

    while ( my $row = $quantity_rs->next ) {

        $self->update_progress(++$i);

        # These fields + location_id have to be unique
        my $unique_identifier = $row->variant_id."-".$row->channel_id."-".$row->status_id;

        my %line;

        $line{sku}      = $row->voucher_variant->voucher_product_id.'-'.'999';
        $line{location} = $row->location->location;
        $line{quantity} = $row->quantity;
        $line{channel}  = $row->channel->name;
        $line{allowed_status} = 'Main Stock';

        $self->csv->print( $fh, [ @line{ @columns } ] );

        if ($unique_quantities{$unique_identifier}) {
            print $sql_fh "update quantity set quantity = quantity + ".$row->quantity
                ." where id = ".$unique_quantities{$unique_identifier}.";\n";
            print $sql_fh "delete from quantity"
                ." where id = ".$row->id.";\n";
        } else {
            print $sql_fh "update quantity set location_id=".$self->prl_location_id
                ." where id = ".$row->id.";\n";
            $unique_quantities{$unique_identifier} = $row->id;
        }

    }

    $self->close_file($fh);
    $self->close_file($sql_fh);

    $self->inform(
        "\nQuantities are dumped, please, check ",
        $self->dump_directory, '/', $self->filename_quantities,
        " file\n"
    );
}

=head2 init_progress

B<Description>

For passed total initiates progress bar.

=cut

sub init_progress {
    my ($self, $total) = @_;

    $total ||= '';

    $self->inform("Found $total records\n", ' 'x22);
}

=head2 update_progress

B<Description>

Update progress bar with passed current position, so it reflects
current state.

=cut

sub update_progress {
    my ($self, $current_position) = @_;

    $self->inform("\r"x22, 'Processing: ', sprintf '%10d', $current_position);
}

__PACKAGE__->meta->make_immutable;

1;

