package XTracker::Script::Extract::ESP;

use NAP::policy "tt", 'class';
extends 'XT::Common::Script';

with map { "XTracker::Script::Feature::$_" } qw(
    SingleInstance
    Schema
    Logger
);

sub log4perl_category { return 'Extract_ESP' }

use DateTime;
use DateTime::Format::Pg;

use File::Spec::Functions               qw( catdir catfile );
use File::Copy                          qw( move );

use Text::CSV;

use XTracker::Config::Local             qw( config_var );
use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw(
                                            :shipment_class
                                            :shipment_status
                                        );
use XT::Data::Types;


=head1 NAME

    XTracker::Script::Extract::ESP

=head1 SYNOPSIS

    XTracker::Script::Extract::ESP->invoke();

=head1 DESCRIPTION

This will extract all of the Dispatched Orders (Shipments) from 'yesterday' excluding Jimmy Choo and write
a file per Sales Channel for our Email Service Provider - Responsys.

Examples of the filenames:
    ORDERS_NAP_INTL_YYYYMMDD_HHMMSS.txt
    ORDERS_OUT_AM_YYYYMMDD_HHMMSS.txt
    ORDERS_MRP_INTL_YYYYMMDD_HHMMSS.txt

=cut

=head1 ATTRIBUTES

=cut

has verbose => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has dryrun => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

# list of field headings to use in the file
has field_headings => (
    is      => 'ro',
    isa     => 'ArrayRef',
    init_arg=> undef,
    default => sub {
            return [ qw(
                    CHANNEL
                    CUSTOMERNUM
                    ORDERNUM
                    ORDERDATE
                    ORDERVALUE
                    ORDERCURRENCY
                    DISPATCHDATE
                    SHIPPINGCITY
                    SHIPPINGSTATE
                    SHIPPINGPOSTALCODE
                    SHIPPINGCOUNTRY
                    DATE
                ) ];
        },
    traits  => ['Array'],
    handles => {
            get_all_headings => 'elements',
        },
);

has start_date  => (
    is      => 'ro',
    isa     => 'XT::Data::Types::DateStamp',
    coerce  => 1,
    init_arg=> 'fromdate',
    builder => '_build_start_date',
);

has end_date    => (
    is      => 'ro',
    isa     => 'XT::Data::Types::DateStamp',
    init_arg=> undef,
    lazy_build  => 1,
);

has path_to_extract_to  => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    init_arg=> 'path',
    default => sub {
            return catdir( config_var( 'SystemPaths', 'esp_incoming_dir' ) );
        },
    # trigger will get called only when the attribute is set such
    # as in the constructor but not when the default is used
    trigger => sub {
            my ( $self, $new_value )    = @_;
            $self->using_default_path(0);
            $self->log_info( "NOT Using the Default Output Path, instead will use: ${new_value}" );
        },
);

# flag that is used to tell whether
# the default path is being used
has using_default_path  => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
    init_arg=> undef,
);

# this is the provider's directory which is 'Responsys'
has path_to_move_to => (
    is      => 'ro',
    isa     => 'Str',
    init_arg=> undef,
    default => sub {
            return catdir(
                        config_var( 'SystemPaths', 'esp_base_dir' ),
                        config_var( 'ESP_Responsys', 'waiting_subdir' )
                    );
        },
);

# This contains the main Query ResultSet.
# Orders aren't actually Dispatched Shipments are,
# to the outside world Shipments & Orders are
# interchangeable but internally in xTracker they
# aren't hence the accurate name of the below attribute
has dispatched_shipments_rs => (
    is          => 'rw',
    isa         => 'XTracker::Schema::ResultSet::Public::Shipment',
    init_arg    => undef,
    lazy_build  => 1,
);

# list of Sales Channels that should only be Extracted
has channels_to_include => (
    is      => 'ro',
    isa     => 'ArrayRef',
    init_arg=> undef,
    lazy_build => 1,
    traits  => ['Array'],
    handles => {
            get_all_channels => 'elements',
        },
);


has file_handles => (
    is      => 'ro',
    isa     => 'HashRef',
    init_arg=> undef,
    default => sub { return {} },
);

has text_csv => (
    is      => 'ro',
    isa     => 'Text::CSV',
    init_arg=> undef,
    lazy_build => 1,
);

has time_now => (
    is      => 'ro',
    isa     => 'DateTime',
    init_arg=> undef,
    lazy    => 1,
    default => sub { return $_[0]->schema->db_now; },
);

has currencies => (
    is      => 'ro',
    isa     => 'HashRef',
    init_arg=> undef,
    lazy_build => 1,
);

has countries => (
    is      => 'ro',
    isa     => 'HashRef',
    init_arg=> undef,
    lazy_build => 1,
);


=head1 METHODS

=cut

sub _build_start_date {
    my $self    = shift;

    # Yesterday
    return $self->time_now->clone
                    ->subtract( days => 1 )
                        ->truncate( to => 'day' );
}

sub _build_end_date {
    my $self    = shift;

    return $self->start_date
                    ->clone
                        ->add( days => 1 );
}

sub _build_channels_to_include {
    my $self    = shift;

    my @channels    = $self->schema
                                ->resultset('Public::Channel')
                                    ->search(
                                        {
                                            # this excludes Jimmy Choo
                                            'business.fulfilment_only'  => 0,
                                        },
                                        {
                                            join    => 'business',
                                        }
                                    )->all;
    return [ @channels ];
}

sub _build_text_csv {
    my $self    = shift;

    Text::CSV->new( {
                    sep_char    => qq{\t},
                    eol         => qq{\n},
                    quote_char  => q{},
                    binary      => 1,
                } )
            or $self->log_croak( "Error getting 'Text::CSV' object: " . Text::CSV->error_diag );
}

sub _build_currencies {
    my $self    = shift;

    my %currencies  = map { $_->id => $_->currency }
                            $self->schema->resultset('Public::Currency')->all;
    return \%currencies;
}

sub _build_countries {
    my $self    = shift;

    my %countries   = map { uc( $_->country ) => $_->code }
                            $self->schema->resultset('Public::Country')->all;
    return \%countries;
}

# this is the main query for the Script
sub _build_dispatched_shipments_rs {
    my $self    = shift;


    # get valid Sales Channel Ids to include in the query
    my @channel_ids = map { $_->id } $self->get_all_channels;

    return $self->schema
                    ->resultset('Public::Shipment')
                        ->search(
                            {
                                'me.shipment_class_id'                      => $SHIPMENT_CLASS__STANDARD,
                                'shipment_status_logs.shipment_status_id'   => $SHIPMENT_STATUS__DISPATCHED,
                                'shipment_status_logs.date'                 => {
                                                                                -between=> [
                                                                                            $self->_in_pg_format( $self->start_date ),
                                                                                            $self->_in_pg_format( $self->end_date )
                                                                                        ],
                                                                               },
                                'orders.channel_id'                         => { 'IN' => \@channel_ids },
                            },
                            {
                                join        => [
                                                'shipment_status_logs',
                                                {
                                                    link_orders__shipments  => {
                                                            orders  => 'customer',
                                                        },
                                                },
                                                'shipment_address',
                                            ],
                                '+select'   => [
                                                { to_char => [ { date_trunc => "'second',shipment_status_logs.date" }, "'YYYY-MM-DD HH24:MI:SS'" ] },
                                                { date_trunc => "'second',orders.date" },
                                                qw(
                                                    orders.order_nr
                                                    customer.is_customer_number
                                                    orders.channel_id
                                                    orders.currency_id
                                                    shipment_address.towncity
                                                    shipment_address.county
                                                    shipment_address.postcode
                                                    shipment_address.country
                                                ) ],
                                '+as'       => [ qw(
                                                dispatch_date
                                                order_date
                                                order_number
                                                customer_number
                                                channel_id
                                                currency_id
                                                shipment_city
                                                shipment_state
                                                shipment_pcode
                                                shipment_country
                                            ) ],
                                order_by    => 'shipment_status_logs.date',
                            }
                        );
}

=over 4

=item B<invoke>

Script entry point

=back

=cut

sub invoke {
    my ( $self )        = @_;

    my $counter = 0;

    $self->log_info("Script Started");

    # get the resultset for the main query
    my $shipments_to_extract    = $self->dispatched_shipments_rs;

    # no point in doing this for every row
    my $file_date_str   = $self->time_now->strftime("%F %T");

    my $datetime_parser = $self->schema->storage->datetime_parser();

    while ( my $shipment = $shipments_to_extract->next ) {
        try {
            # get a file handle to write to for the Sales Channel
            my $fh  = $self->get_file_handle( $shipment->get_column('channel_id') );

            my $order_date_string = $datetime_parser->parse_datetime(
                $shipment->get_column('order_date')
            )->strftime("%F %T");

            # populate the fields that will be written to the file
            my %row = (
                    CHANNEL             => $shipment->get_column('channel_id'),
                    CUSTOMERNUM         => $shipment->get_column('customer_number'),
                    ORDERNUM            => $shipment->get_column('order_number'),
                    ORDERDATE           => $order_date_string,
                    ORDERVALUE          => sprintf( '%0.3f', _shipment_value( $shipment ) ),
                    ORDERCURRENCY       => $self->currencies->{ $shipment->get_column('currency_id') },
                    DISPATCHDATE        => $shipment->get_column('dispatch_date'),
                    SHIPPINGCITY        => $shipment->get_column('shipment_city'),
                    SHIPPINGSTATE       => $shipment->get_column('shipment_state'),
                    SHIPPINGPOSTALCODE  => $shipment->get_column('shipment_pcode'),
                    SHIPPINGCOUNTRY     => $self->countries->{ uc( $shipment->get_column('shipment_country') ) },
                    DATE                => $file_date_str,
                );

            if ( !$self->dryrun ) {
                # write to the file if not in 'dryrun' mode
                $self->text_csv->print( $fh, [ map { $row{ $_ } } $self->get_all_headings ] );
            }

            if ( $self->verbose ) {
                $self->log_info(
                                    "Channel Id: $row{CHANNEL}, "
                                    . "Order Extracted: $row{ORDERNUM}, "
                                    . "for Customer: $row{CUSTOMERNUM}, "
                                    . "Shipment Id: " . $shipment->id
                               );
            }

            $counter++;
        }
        catch {
            $self->log_error( "Error Encountered : " . "\n" . $_ );
        };
    }

    $self->close_and_move_files;

    $self->log_info( "Orders Extracted: ${counter}" );

    return;
}

# gets a file handle for a given Sales Channel from the 'file_handles' attribute
# if there isn't one for the Sales Channel then a file is opened.
sub get_file_handle {
    my ( $self, $channel_id )   = @_;

    return      if ( $self->dryrun );

    my $fh;

    if ( !exists( $self->file_handles->{ $channel_id } ) ) {
        my $channel     = $self->schema->resultset('Public::Channel')->find( $channel_id );

        my $filename    = 'ORDERS_'
                          . uc( $channel->website_name )
                          . '_' . $self->time_now->ymd('')
                          . '_' . $self->time_now->hms('')
                          . '.txt';

        my $full_path   = catfile( $self->path_to_extract_to, $filename );
        $self->log_info( "Opening file for Writing: ${full_path}" );

        open $fh, '>:encoding(UTF-8)', $full_path
            or $self->log_croak( "Can't open file to write to: " . $full_path );

        # now output the Headers to the newly opened file
        $self->text_csv->print( $fh, $self->field_headings );

        $self->file_handles->{ $channel_id }    = {
                                filename    => $filename,
                                full_path   => $full_path,
                                fh          => $fh,
                            };
    }
    else {
        $fh = $self->file_handles->{ $channel_id }{fh};
    }

    return $fh;
}

# this closes all of the files from the attribute 'file_handles'
# and then moves the files to the Provider directory unless a different
# output path has been specified in the 'path' argument at construction
sub close_and_move_files {
    my $self    = shift;

    foreach my $file ( values %{ $self->file_handles } ) {
        close $file->{fh};
        $self->log_info( "Closed file: " . $file->{full_path} );

        # if the default path is being used to write
        # to then move the file to the Provider directory
        if ( $self->using_default_path ) {
            my $move_to = catfile( $self->path_to_move_to, $file->{filename} );

            $self->log_info( "Moving File: " . $file->{full_path} . " to ${move_to}" );

            move( $file->{full_path}, $move_to )
                                or $self->log_error( "Couldn't move file, from: " . $file->{full_path} . " to ${move_to}: $!" );
        }
    }

    return;
}

# converts Dates into Pg format for
# 'timestamp with time zone' fields
sub _in_pg_format {
    my $self    = shift;
    my $date    = shift;

    # the custom 'XT::Data::Types::DateStamp' doesn't support the methods required
    # by 'DateTime::Format::Pg' to do the conversion so first get a DateTime object
    my $datetime    = DateTime->from_epoch(
                                    epoch       => $date->epoch,
                                    time_zone   => $date->time_zone
                                );

    return $self->schema->storage->datetime_parser->format_timestamp_with_time_zone( $datetime );
}

# get the Shipment value, including Shipping Charge
# for all Shipment Items excluding Cancelled items
sub _shipment_value {
    my ( $shipment )    = @_;

    my $items   = $shipment->non_cancelled_items
                        ->search( {},
                            {
                                select  => [
                                            { sum => 'unit_price' },
                                            { sum => 'tax' },
                                            { sum => 'duty' },
                                        ],
                                as      => [ qw( unit_price tax duty ) ],
                            }
                        )->first;

    return $shipment->shipping_charge       if ( !$items );

    return $shipment->shipping_charge
           + $items->get_column('unit_price')
           + $items->get_column('tax')
           + $items->get_column('duty')
    ;
}

1;
