package Test::XTracker::Data::SearchOrderByDesigner;

use NAP::policy     qw( class test );

=head1 NAME

Test::XTracker::Data::SearchOrderByDesigner - create test data for Search Orders by Designer tests.

=head1 SYNOPSIS

    package Test::Foo;

    use Test::XTracker::Data::SearchOrderByDesigner;

    and to call one of the methods:
    Test::XTracker::Data::SearchOrderByDesigner->create_search_result_file( ... );

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::Designer;

use Test::XT::Data;

use XTracker::Config::Local     qw( order_search_by_designer_result_file_path );

use List::Util                  qw( shuffle );
use File::Find::Rule;
use File::Basename;

use IO::File;
use Text::CSV;


=head1 METHODS

=head2 create_search_result_file

    $file_name = __PACKAGE__->create_search_result_file( {
        # optional
        designer => $designer_rec,      # Designer record to create the Search for
        channel  => $channel_rec        # the Channel the Search will be for
        operator => $operator_rec,      # Operator record of who created the search
        state    => 'pending',          # the state the file should be created in,
                                        # 'pending' will be the default
        # if state is 'completed':
        number_of_records => 235,       # number of records in the file
    } );

Will create 'Search Orders by Designer' search results files only. It will not populate
them but just create an empty file with the filename created correctly. This is so you
can provide data for the Search Results list Table on the 'Customer Care->Order Search by Desginer'
page.

If no arguments passed then the default Operator if 'it.god' will be used and any Designer
will be chosen from the 'designer' table.

Use the 'state' argument to set the file should be created in:
    * 'pending'   - default, will create a file with 'PENDING' in the file-name to
                    simulate when a request to do a Search on a Designer is pending
    * 'searching' - will create a file with 'SEARCHING' in the file-name to simulate
                    when a search for a Designer is actually taking place
    * 'completed' - will create a file with 'COMPLETED' in the file-name to simulate
                    when a search has completed

If the 'state' is 'completed' then you need to pass 'number_of_records' to signify the
number of records in the file, which can be zero.

=cut

sub create_search_result_file {
    my ( $self, $args ) = @_;

    my $operator = $args->{operator} || $self->_get_default_user();

    my $designer = $args->{designer};
    unless ( $designer ) {
        # randomly get a Designer
        my @designers = $self->_schema->resultset('Public::Designer')
                                ->search( { id => { '!=' => 0 } } )
                                    ->all;
        ( $designer ) = shuffle( @designers );
    }

    my $result_dir = $self->_results_dir;

    my $file_name = $operator->create_orders_search_by_designer_file_name( {
        state    => $args->{state} || 'pending',
        designer => $designer,
        channel  => $args->{channel},
        operator => $operator,
        ( defined $args->{number_of_records} ? ( number_of_records => $args->{number_of_records} ) : () ),
    } );

    my $fh = IO::File->new( ">${result_dir}/${file_name}" )
                || croak "Could't create file '${file_name}' in '${result_dir}': " . $!;
    $fh->close();

    return $file_name;
}

=head2 create_search_result_files

    $file_name_array_ref = __PACKAGE__->create_search_result_files( $number_of_files, [
            # optional:
            # an array of arguments that you would pass
            # to the method 'create_search_result_file'
            {
                # see 'create_search_result_file' for details
            },
            ...
        ]
    );

Creates multiple Search Result Files by calling the 'create_search_result_file' method
as many times as specified by '$number_of_files', see this method for information on
what it does.

=cut

sub create_search_result_files {
    my ( $self, $number_of_files, $arr_of_args ) = @_;

    $number_of_files ||= 1;
    $arr_of_args     ||= [];

    my @file_names;
    foreach ( 1..$number_of_files ) {
        push @file_names, $self->create_search_result_file(
            ( shift @{ $arr_of_args } // {} ),
        );
    }

    return \@file_names;
}

=head2 parse_search_result_file_names

    $hash_ref  = __PACKAGE__->parse_search_result_file_names( $file_name );
            or
    $array_ref = __PACKAGE__->parse_search_result_file_names( $file_name_arr_ref );

Parse a Search Result File or an Array Ref. of Search Result files to get back the Operator
and Designer that the files are for.

This will use the ResultSet 'Public::Operator' Method called 'parse_orders_search_by_designer_file_name'
and return its results.

=cut

sub parse_search_result_file_names {
    my ( $self, $files ) = @_;

    my $passed_an_array = ( ref( $files ) eq 'ARRAY' ? 1 : 0 );
    # now make sure $files is an array
    $files = ( ref( $files ) eq 'ARRAY' ? $files : [ $files ] );

    my $operator_rs = $self->_schema->resultset('Public::Operator');

    my @retval;
    foreach my $file ( @{ $files } ) {
        my $details = $operator_rs->parse_orders_search_by_designer_file_name( $file );
        push @retval, $details;
    }

    if ( @retval ) {
        return \@retval     if ( $passed_an_array );
        return $retval[0];
    }

    return;
}

=head2 create_and_populate_search_result_file

    $file_name = __PACKAGE__->create_and_populate_search_result_file( {
        designer => $designer_rec,
        orders   => [ $order_rec, ... ],
        # optional
        channel  => $channel_rec,
        operator => $operator_rec,
    } );

Creates an Order Search By Designer Result file and populates it using the 'orders'
Array Ref. If no Operator is passed in then 'it.god' will be used by default.

Returns the file name of the results file.

=cut

sub create_and_populate_search_result_file {
    my ( $self, $args ) = @_;

    my $designer = $args->{designer};
    my $orders   = $args->{orders};
    my $channel  = $args->{channel};
    my $operator = $args->{operator} || $self->_get_default_user();

    # list of column headings and also the
    # sequence that they will appear in the file
    my @col_headers = (
        # public facing
        'order_nr',
        'customer_nr',
        # internal
        'order_id',
        'customer_id',

        'customer_category',
        'customer_eip_flag',
        'channel_id',
        'order_date',
        'order_total_value',
        'currency_id',

        # about the Shipment
        'shipment_id',
        'shipment_status',
        'shipment_type',
        'is_premier_shipment',
    );

    my $file_name = $self->create_search_result_file( {
        designer => $designer,
        channel  => $channel,
        operator => $operator,
        state    => 'completed',
        number_of_records => scalar( @{ $orders } ),
    } );

    my $result_dir = $self->_results_dir;

    my $csv_file = Text::CSV->new( {
        binary => 1,
        eol    => "\n",
        always_quote => 1,
    } );

    my $fh = IO::File->new( "${result_dir}/${file_name}", ">:encoding(utf8)" )
                || croak "Could't open file '${file_name}' in '${result_dir}': " . $!;

    # print the column headings as the first row of the file
    $csv_file->print( $fh, \@col_headers );

    foreach my $order ( @{ $orders } ) {
        my $customer = $order->customer;
        # get the first Shipment connected to the Order
        # due to testing it might not be 'Standard'
        my $shipment = $order->link_orders__shipments
                                ->search( {}, { order_by => 'shipment_id' } )
                                    ->first
                                        ->shipment;

        my $row = {
            order_nr              => $order->order_nr,
            customer_nr           => $order->customer->is_customer_number,
            order_id              => $order->id,
            customer_id           => $customer->id,
            customer_category     => $customer->category->category,
            customer_eip_flag     => $customer->is_an_eip,
            channel_id            => $order->channel_id,
            order_date            => $order->date,
            order_total_value     => ( $order->total_value + $order->store_credit ),
            currency_id           => $order->currency_id,
            shipment_id           => $shipment->id,
            shipment_status       => $shipment->shipment_status->status,
            shipment_type         => $shipment->shipment_type->type,
            is_premier_shipment   => $shipment->is_premier || 0,
        };

        $csv_file->print(
            $fh,
            [
                map { $row->{ $_ } } @col_headers
            ]
        );
    }

    $fh->close();

    return $file_name;
}

=head2 create_orders_with_products_for_the_same_designer_and_results_file

    ( $orders_array_ref, $file_name ) = __PACKAGE__->create_orders_with_products_for_the_same_designer_and_results_file( $how_many, {
        # same args as for:
        Test::XTracker::Data::Designer->create_orders_with_products_for_the_same_designer
    } );

This will create Orders for a Designer and then create a Search Results file populated for the Orders. It takes
the same arguments as 'create_orders_with_products_for_the_same_designer' but returns the File Name that's been
created and an Array Ref. of Orders.

=cut

sub create_orders_with_products_for_the_same_designer_and_results_file {
    my ( $self, @params ) = @_;

    my $orders = Test::XTracker::Data::Designer->create_orders_with_products_for_the_same_designer( @params );

    # get the first Order and deride the info
    # we need from it for the next method call
    my $order = $orders->[0];
    return      if ( !$order );

    my $designer = $order->get_standard_class_shipment()
                            ->shipment_items->first
                                ->variant
                                    ->product
                                        ->designer;
    my $channel  = $order->channel;

    my $file_name = $self->create_and_populate_search_result_file( {
        designer => $designer,
        channel  => $channel,
        orders   => $orders,
    } );

    return ( $orders, $file_name );
}

=head2 check_if_search_result_file_exists_for_search_criteria

    $string = __PACKAGE__->check_if_search_result_file_exists_for_search_criteria( {
        designer => $designer,
        operator => $operator,
        state    => 'pending', 'searching' or 'completed'
        # required for 'completed' state
        number_of_records => 35,
        # optional:
        channel  => $channel,
    } );

Given the Search Criteria will check to see if the expected search result file
has been created in the Search Results directory in the correct State.

Because the file-names have time-stamps on them then these will be ignored and a file
matching the Operator, Designer, Channel, State and Number of Records (if relevant to
the State) shall be searched for. Because the time-stamps are being ignored this method
expects only one file to be found that matches the search criteria, if more than one file
is found then this will cause a fatal error.

Remember to use the 'purge_search_result_dir' method in your tests to remove any files
that may be lying around.

Returns the file name if found else an empty string will be returned.

=cut

sub check_if_search_result_file_exists_for_search_criteria {
    my ( $self, $args ) = @_;

    my $file_name = $args->{operator}->create_orders_search_by_designer_file_name( {
        state    => $args->{state},
        designer => $args->{designer},
        channel  => $args->{channel},
        ( defined $args->{number_of_records} ? ( number_of_records => $args->{number_of_records} ) : () ),
    } );

    # get the parts of the file-name without the time-stamp in it
    my ( $op_id, $des_id, $chn_id, $timestamp, $state ) = split( /_/, $file_name );
    my $searchable_file_name = "${op_id}_${des_id}_${chn_id}_*_${state}*";

    my $path = $self->_results_dir();

    my @files = File::Find::Rule
                    ->file()
                        ->name( $searchable_file_name )
                            ->in( $path );

    if ( scalar( @files ) > 1 ) {
        croak "Found more than one File that matched '${searchable_file_name}': " . p( @files );
    }

    if ( my $found_file = $files[0] ) {
        # don't want to return the full path
        my ( $filename, $directories, $suffix ) = fileparse( $found_file );
        return ( $filename // '' ) . ( $suffix // '' );
    }
    return '';
}

=head2 read_search_results_file

    $array_ref = __PACKAGE__->read_search_results_file( $file_name );

Reads a Search Results file and returns the results in an Array Ref. of Hash Refs
keyed by the column headings at the top of the file.

=cut

sub read_search_results_file {
    my ( $self, $file_name ) = @_;

    # add the '.txt' extension if the file name doesn't have one
    $file_name .= '.txt'        if ( $file_name !~ /\.txt/ );

    my $full_file_name = $self->_results_dir() . "/${file_name}";

    # if no contents return an empty Array Ref.
    return []       if ( -z $full_file_name );

    my $csv_file = Text::CSV->new( {
        binary => 1,
        eol    => "\n",
        always_quote => 1,
    } );

    my $csv_fh = IO::File->new( $full_file_name, "<:encoding(utf8)" )
                || croak "Could't open file '${full_file_name}': " . $!;

    # first line has the Column Headings
    my $col_headings = $csv_file->getline( $csv_fh );
    $csv_file->column_names( @{ $col_headings } );

    my @rows;
    while ( my $row = $csv_file->getline_hr( $csv_fh ) ) {
        push @rows, $row;
    }

    $csv_fh->close();

    return \@rows;
}

=head2 purge_search_result_dir

    __PACKAGE__->purge_search_result_dir();

Removes all Files created in the 'search_order_by_designer_results_dir' directory.

=cut

sub purge_search_result_dir {
    my $self = shift;

    my $result_dir = $self->_results_dir;

    # check directory exists and isn't root (/)
    if ( -d $result_dir && $result_dir =~ m/\w/ ) {
        my $file_count = 0;
        ++$file_count && unlink $_  for File::Find::Rule
                                        ->file()
                                            ->name('*')
                                                ->in( $result_dir );
        note "${file_count} Search Result Files deleted from '${result_dir}'";
    }

    return;
}

#-------------------------------------------------------------------------------------

sub _results_dir {
    return order_search_by_designer_result_file_path();
}

sub _schema {
    return Test::XTracker::Data->get_schema();
}

# returns the 'it.god' user
sub _get_default_user {
    my $self = shift;
    return $self->_schema->resultset('Public::Operator')
                    ->search( { 'LOWER(username)' => 'it.god' } )
                        ->first;
}

