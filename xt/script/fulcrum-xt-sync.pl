#!/opt/xt/xt-perl/bin/perl
use strict;
use warnings;

use DBI;
use Getopt::Long;

my $verbose;
my $show;

############################################################
# CONFIGURATION                                            #
############################################################

my $config = {

    connections                     => {
        fulcrum                     => {
            username                => 'postgres',
            password                => '',
            database                => 'xt_central',
            host                    => 'fulcrum-cando.dave',
        },
        xtracker                    => {
            username                => 'postgres',
            password                => '',
            database                => 'xtdc3',
            host                    => 'xtdc3-cando.dave', 
        },
    },

    tables                          => {

        classification              => {
            source                  => {
                connection          => 'fulcrum',
                filter              => 'parent_id is null',
                table               => 'reporting',
                columns             => {
                    primary         => 'id',
                    match           => 'name',
                    input           => [ qw( name ) ],
                },
            },
            column_mapping          => {
                name                => 'classification',
            },
            destination             => {
                connection          => 'xtracker',
                table               => 'classification',
                columns             => {
                    primary         => 'id',
                    match           => 'classification',
                    output          => [ qw( classification ) ],
                },
            },
        },

        colour                      => {
            source                  => {
                connection          => 'fulcrum',
                table               => 'product.colour',
                columns             => {
                    primary         => 'id',
                    match           => 'name',
                    input           => [ qw( name ) ],
                },
            },
            column_mapping          => {
                name                => 'colour',
            },
            destination             => {
                connection          => 'xtracker',
                table               => 'colour',
                columns             => {
                    primary         => 'id',
                    match           => 'colour',
                    output          => [ qw( colour ) ]
                },
            },
        },

        colour_filter               => {
            source                  => {
                connection          => 'fulcrum',
                table               => 'product.colour_filter',
                columns             => {
                    primary         => 'id',
                    match           => 'name',
                    input           => [ qw( name ) ],
                },
            },
            column_mapping          => {
                name                => 'colour_filter',
            },
            destination             => {
                connection          => 'xtracker',
                table               => 'colour_filter',
                columns             => {
                    primary         => 'id',
                    match           => 'colour_filter',
                    output          => [ qw( colour_filter ) ]
                },
            },
        },

        division                    => {
            source                  => {
                connection          => 'fulcrum',
                table               => 'division',
                columns             => {
                    primary         => 'id',
                    match           => 'name',
                    input           => [ qw( name ) ],
                },
            },
            column_mapping          => {
                name                => 'division',
            },
            destination             => {
                connection          => 'xtracker',
                table               => 'division',
                columns             => {
                    primary         => 'id',
                    match           => 'division',
                    output          => [ qw( division ) ],
                },
            },
        },

        hs_code                     => {
            source                  => {
                connection          => 'fulcrum',
                table               => 'hs_code',
                columns             => {
                    primary         => 'id',
                    match           => 'name',
                    input           => [ qw( name active ) ],
                },
            },
            column_mapping          => {
                name                => 'hs_code',
            },
            destination             => {
                connection          => 'xtracker',
                table               => 'hs_code',
                columns             => {
                    primary         => 'id',
                    match           => 'hs_code',
                    output          => [ qw( hs_code active ) ],
                },
            },
        },

        payment_deposit             => {
            source                  => {
                connection          => 'fulcrum',
                table               => 'buying.payment_deposit',
                columns             => {
                    primary         => 'id',
                    match           => 'percentage',
                    input           => [ qw( percentage ) ],
                },
            },
            column_mapping          => {
                percentage          => 'deposit_percentage',
            },
            destination             => {
                connection          => 'xtracker',
                table               => 'payment_deposit',
                columns             => {
                    primary         => 'id',
                    match           => 'deposit_percentage',
                    output          => [ qw( deposit_percentage ) ],
                },
            },
        },

        payment_settlement_discount => {
            source                  => {
                connection          => 'fulcrum',
                table               => 'buying.payment_settlement_discount',
                columns             => {
                    primary         => 'id',
                    match           => 'percentage',
                    input           => [ qw( percentage ) ],
                },
            },
            column_mapping          => {
                percentage          => 'discount_percentage',
            },
            destination             => {
                connection          => 'xtracker',
                table               => 'payment_settlement_discount',
                columns             => {
                    primary         => 'id',
                    match           => 'discount_percentage',
                    output          => [ qw( discount_percentage ) ],
                },
            },
        },

        payment_term                => {
            source                  => {
                connection          => 'fulcrum',
                table               => 'product.payment_term',
                columns             => {
                    primary         => 'id',
                    match           => 'name',
                    input           => [ qw( name ) ],
                },
            },
            column_mapping          => {
                name                => 'payment_term',
            },
            destination             => {
                connection          => 'xtracker',
                table               => 'payment_term',
                columns             => {
                    primary         => 'id',
                    match           => 'payment_term',
                    output          => [ qw( payment_term ) ],
                },
            },
        },

        product_department          => {
            source                  => {
                connection          => 'fulcrum',
                table               => 'product_department',
                columns             => {
                    primary         => 'id',
                    match           => 'name',
                    input           => [ qw( name ) ],
                },
            },
            column_mapping          => {
                name                => 'department',
            },
            destination             => {
                connection          => 'xtracker',
                table               => 'product_department',
                columns             => {
                    primary         => 'id',
                    match           => 'department',
                    output          => [ qw( department ) ],
                },
            },
        },

        product_type                => {
            source                  => {
                connection          => 'fulcrum',
                table               => 'reporting',
                filter              => 'parent_id is null',
                columns             => {
                    primary         => 'id',
                    match           => 'name',
                    input           => [ qw( name ) ],
                },
            },
            column_mapping          => {
                name                => 'product_type',
            },
            destination             => {
                connection          => 'xtracker',
                table               => 'product_type',
                columns             => {
                    primary         => 'id',
                    match           => 'product_type',
                    output          => [ qw( product_type ) ],
                },
            },
        },

        season                      => {
            source                  => {
                connection          => 'fulcrum',
                table               => 'season',
                columns             => {
                    primary         => 'id',
                    match           => 'name',
                    input           => [ qw( name season_year season_code active ) ],
                },
            },
            column_mapping          => {
                name                => 'season',
            },
            destination             => {
                connection          => 'xtracker',
                table               => 'season',
                columns             => {
                    primary         => 'id',
                    match           => 'season',
                    output          => [ qw( season season_year season_code active ) ],
                },
            },
        },

        season_act                  => {
            source                  => {
                connection          => 'fulcrum',
                table               => 'season_act',
                columns             => {
                    primary         => 'id',
                    match           => 'name',
                    input           => [ qw( name ) ],
                },
            },
            column_mapping          => {
                name                => 'act',
            },
            destination             => {
                connection          => 'xtracker',
                table               => 'season_act',
                columns             => {
                    primary         => 'id',
                    match           => 'act',
                    output          => [ qw( act ) ],
                },
            },
        },

        size                        => {
            source                  => {
                connection          => 'fulcrum',
                table               => 'size',
                columns             => {
                    primary         => 'id',
                    match           => 'size',
                    input           => [ qw( size ) ],
                },
            },
            destination             => {
                connection          => 'xtracker',
                table               => 'size',
                columns             => {
                    primary         => 'id',
                    match           => 'size',
                    output          => [ qw( size ) ],
                },
            },
        },

        size_scheme                 => {
            source                  => {
                connection          => 'fulcrum',
                table               => 'size_scheme',
                columns             => {
                    primary         => 'id',
                    match           => 'name',
                    input           => [ qw( name short_name ) ],
                },
            },
            destination             => {
                connection          => 'xtracker',
                table               => 'size_scheme',
                columns             => {
                    primary         => 'id',
                    match           => 'name',
                    output          => [ qw( name short_name ) ],
                },
            },
        },

        size_scheme_variant_size    => {
            dependencies            => [ qw( size size_scheme ) ],
            source                  => {
                connection          => 'fulcrum',
                table               => 'size_scheme_variant_size',
                transform           => {
                    input           => sub {
                        my ( $t, $d ) = @_;

                        $d->{'size_scheme'}   = table_lookup( 'size_scheme', 'source', 'id', $d->{'size_scheme_id'},   'name' );
                        $d->{'size'}          = table_lookup( 'size',        'source', 'id', $d->{'size_id'},          'size' );
                        $d->{'designer_size'} = table_lookup( 'size',        'source', 'id', $d->{'designer_size_id'}, 'size' );

                    },
                },
                columns             => {
                    primary         => 'id',
                    match           => [ qw( size_scheme size designer_size position ) ],
                    input           => [ qw( size_scheme size designer_size position ) ],
                },
            },
            destination             => {
                connection          => 'xtracker',
                table               => 'size_scheme_variant_size',
                transform           => {
                    input           => sub {
                        my ( $t, $d ) = @_;

                        $d->{'size_scheme'}   = table_lookup( 'size_scheme', 'destination', 'id', $d->{'size_scheme_id'},   'name' );
                        $d->{'size'}          = table_lookup( 'size',        'destination', 'id', $d->{'size_id'},          'size' );
                        $d->{'designer_size'} = table_lookup( 'size',        'destination', 'id', $d->{'designer_size_id'}, 'size' );

                    },
                    output          => sub {
                        my ( $t, $d ) = @_;

                        $d->{'size_scheme_id'}   = table_lookup( 'size_scheme', 'destination', 'name', $d->{'size_scheme'},   'id' );
                        $d->{'size_id'}          = table_lookup( 'size',        'destination', 'size', $d->{'size'},          'id' );
                        $d->{'designer_size_id'} = table_lookup( 'size',        'destination', 'size', $d->{'designer_size'}, 'id' );

                    },
                },
                columns             => {
                    primary         => 'id',
                    match           => [ qw( size_scheme size designer_size position ) ],
                    output          => [ qw( size_scheme_id size_id designer_size_id position ) ],
                },
            },
        },

        sub_type                    => {
            source                  => {
                connection          => 'fulcrum',
                table               => 'reporting',
                filter              => 'parent_id is null',
                columns             => {
                    primary         => 'id',
                    match           => 'name',
                    input           => [ qw( name ) ],
                },
            },
            column_mapping          => {
                name                => 'sub_type',
            },
            destination             => {
                connection          => 'xtracker',
                table               => 'sub_type',
                columns             => {
                    primary         => 'id',
                    match           => 'sub_type',
                    output          => [ qw( sub_type ) ],
                },
            },
        },

        product_attribute           => {
            source                  => {
                connection          => 'fulcrum',
                table               => 'product.navigation',
                filter              => 'level in (1,2,3) and channel_id = 9',
                distinct_rows       => 1,
                columns             => {
                    primary         => 'id',
                    match           => [ qw( name level channel_id ) ],
                    input           => [ qw( name level channel_id ) ],
                },
            },
            column_mapping          => { 
                level               => 'attribute_type_id',
            },
            destination             => {
                connection          => 'xtracker',
                table               => 'product.attribute',
                columns             => {
                    primary         => 'id',
                    match           => [ qw( name attribute_type_id channel_id ) ],
                    output          => [ qw( name attribute_type_id channel_id ) ],
                },
            },
        },

        designer                    => {
            source                  => {
                connection          => 'fulcrum',
                table               => 'designer',
                columns             => {
                    primary         => 'id',
                    match           => 'name',
                    input           => [ qw( name url_key ) ],
                },
            },
            column_mapping          => {
                name                => 'designer',
            },
            destination             => {
                connection          => 'xtracker',
                table               => 'designer',
                columns             => {
                    primary         => 'id',
                    match           => 'designer',
                    output          => [ qw( designer url_key ) ],
                },
            },
        },

        shipment_window_type        => {
            source                  => {
                connection          => 'fulcrum',
                table               => 'buying.shipment_window_type',
                columns             => {
                    primary         => 'id',
                    match           => 'name',
                },
            },
            column_mapping          => {
                name                => 'type',
            },
            destination             => {
                connection          => 'xtracker',
                table               => 'shipment_window_type',
                columns             => {
                    primary         => 'id',
                    match           => 'type',
                    output          => [ qw( type ) ],
                },
            },
        },

        supplier                    => {
            source                  => {
                connection          => 'fulcrum',
                table               => 'designer',
                columns             => {
                    primary         => 'id',
                    match           => 'supplier_code',
                    input           => [ qw( supplier_name supplier_code ) ],
                },
            },
            column_mapping          => {
                supplier_name       => 'description',
                supplier_code       => 'code',
            },
            destination             => {
                connection          => 'xtracker',
                table               => 'supplier',
                columns             => {
                    primary         => 'id',
                    match           => 'code',
                    output          => [ qw( code description ) ]
                },
            },
        },

    },

};

############################################################
# SUBS                                                     #
############################################################

my $cache = {};
my %done;

sub db_connection {
    my ( $name ) = @_;

    unless ( exists $cache->{$name} ) {

        my $connection = $config->{connections}->{$name};

        print "Connecting to database '$connection->{database}\@$connection->{host}' with username '$connection->{'username'}' as '$name'\n"
            if $verbose;

        $cache->{$name} = DBI->connect(
            "dbi:Pg:dbname=$connection->{database};host=$connection->{host}",
            $connection->{'username'},
            $connection->{'password'}
        );

    }

    return $cache->{$name};

}

sub db_select {
    my ( $dbh, $table, $filter, $distinct, @columns ) = @_;

    die "db_select: Missing database handle.\n" unless $dbh;
    die "db_select: Missing table name.\n" unless $table;

    my $column_list = join( ', ', @columns ) || '*';

    my $sql = "SELECT" . ( $distinct ? ' DISTINCT' : '' ) . " $column_list FROM $table" . ( $filter ? " WHERE $filter" : '' );
    print "SQL: $sql\n"
        if $verbose;

    return $dbh->selectall_arrayref( $sql, { Slice => {} } );

}

sub db_insert {
    my ( $dbh, $table, $data ) = @_;

    die "db_insert: Missing database handle.\n" unless $dbh;
    die "db_insert: Missing table name.\n" unless $table;
    die "db_insert: Missing data.\n" unless $data && ref( $data ) eq 'HASH';

    my $column_names  = join ', ', sort keys %$data;
    my $place_holders = join ', ', map { '?' } keys %$data;
    my @column_values = map { $data->{$_} } sort keys %$data;

    my $sql = "INSERT INTO $table ($column_names) VALUES ($place_holders)";

    print "SQL: $sql [" . join( ':', @column_values) . "]\n"
        if $verbose || $show;

    $dbh->do( $sql, undef, @column_values )
        unless $show;

}

sub db_delete {
    my ( $dbh, $table, $column, $value ) = @_;

    die "db_delete: Missing database handle.\n" unless $dbh;
    die "db_delete: Missing table name.\n" unless $table;
    die "db_delete: Missing column name.\n" unless $column;
    die "db_delete: Missing value\n" unless $value;

    my $sql = "DELETE FROM $table WHERE $column = ?";

    print "SQL: $sql [$value]"
        if $verbose || $show;

    $dbh->do( $sql, undef, $value )
        unless $show;

}

sub expand_to_array {
    my ( $data ) = @_;

    return ref( $data ) eq 'ARRAY'
        ? $data
        : [ $data ];

}

sub match_columns {
    my ( $table, $source_row, $destination_row ) = @_;

    $table->{'source'}->{'columns'}->{'match'}      = expand_to_array( $table->{'source'}->{'columns'}->{'match'} );
    $table->{'destination'}->{'columns'}->{'match'} = expand_to_array( $table->{'destination'}->{'columns'}->{'match'} );

    my @source_columns      = @{ $table->{'source'}->{'columns'}->{'match'} };
    my @destination_columns = @{ $table->{'destination'}->{'columns'}->{'match'} };

    if ( @source_columns == @destination_columns ) {

        my $match = 1;

        foreach my $index ( 0 .. $#source_columns ) {

            die "Missing source row in match '$source_columns[$index]' for table '$table->{source}->{table}'\n"
                unless exists( $source_row->{ $source_columns[$index] } );

            die "Missing destination row in match '$destination_columns[$index]' for table '$table->{destination}->{table}'\n"
                unless exists( $destination_row->{ $destination_columns[$index] } );

            my $m1 = $source_row->{ $source_columns[$index] }           || '';
            my $m2 = $destination_row->{ $destination_columns[$index] } || '';

            unless ( exists $table->{'case-sensitive'} && defined $table->{'case-sensitive'} && $table->{'case-sensitive'} == 1 ) {
                $m1 = uc $m1;
                $m2 = uc $m2;
            }

            unless ( $m1 eq $m2 ) {

                $match = 0;
                last;

            }

        }

        return $match;

    } else {

        die "Match columns mismatch for '$table->{source}->{table}'/'$table->{destination}->{table}'\n";

    }

}

sub db_table_apply {
    my ( $table, $delete ) = @_;

    my $source = $table->{'source'};
    my $destination = $table->{'destination'};

    my $table1 = db_select(
        $source->{'connection'},
        $source->{'table'},
        $source->{'filter'},
        $source->{'distinct_rows'},
        $source->{'distinct_rows'} ? @{ $source->{'columns'}->{'input'} } : ()
    );

    my $table2 = db_select(
        $destination->{'connection'},
        $destination->{'table'},
        $destination->{'filter'},
        $destination->{'distinct_rows'},
        $destination->{'distinct_rows'} ? @{ $destination->{'columns'}->{'input'} } : ()
    );

    $source->{'data'} = $table1;
    $destination->{'data'} = $table2;

    # Reset sequence for destination table.
    $destination->{'connection'}->do( "SELECT setval('$destination->{table}_id_seq', (SELECT coalesce(MAX(id)::integer,0) FROM $destination->{table}) + 1)" );

    foreach my $row1 ( @$table1 ) {

        # Execute the pre-matching input transform.
        $source->{'transform'}->{'input'}->( $table, $row1 )
            if defined $source->{'transform'}->{'input'};

        my $found = 0;

        foreach my $row2 ( @$table2 ) {

            # Execute the pre-matching input transform.
            $destination->{'transform'}->{'input'}->( $table, $row2 )
                if defined $destination->{'transform'}->{'input'};

            if ( match_columns( $table, $row1, $row2 ) ) {

                $found = 1;
                last;

            }

        }

        unless ( $found ) {

            my $data;

            my $column_mapping = $table->{'column_mapping'};

            # Get only the required columns and apply the column mappings.
            $data->{ $column_mapping->{$_} || $_ } = $row1->{$_}
                foreach @{ $source->{'columns'}->{'input'} };

            # Execute the output transform.
            $destination->{'transform'}->{'output'}->( $table, $data )
                if defined $destination->{'transform'}->{'output'};

            # Only output the required columns.
            %$data = map { $_ => $data->{$_} } @{ $destination->{'columns'}->{'output'} };

            my $has_data = grep { defined $_ && $_ ne '' } values %$data;

            db_insert(
                $destination->{'connection'},
                $destination->{'table'},
                $data
            ) if $has_data;

        }

    }

    if ( $delete ) {

        foreach my $row2 ( @$table2 ) {

            my $found = 0;

            foreach my $row1 ( @$table1 ) {

                if ( match_columns( $table, $row1, $row2 ) ) { 

                    $found = 1;
                    last;

                }

            }

            unless ( $found ) {

                db_delete(
                    $destination->{'connection'},
                    $destination->{'table'},
                    $destination->{'columns'}->{'primary'},
                    $row2->{ $destination->{'columns'}->{'primary'} }
                );

            }

        }

    }

}

sub table_lookup {
    my ( $table, $source, $lookup_column, $lookup_value, $return_column ) = @_;

    die "table_lookup: Missing parameter.\n" unless @_ == 5;
    die "table_lookup: Invalid table name '$table'.\n" unless exists $config->{'tables'}->{$table};
    die "table_lookup: Invaluid source '$source'.\n" unless $source =~ /^(source|destination)$/i;

    $source = $config->{'tables'}->{$table}->{$source};

    my @result = grep { $_->{$lookup_column} eq $lookup_value } @{ $source->{'data'} };
    return @result
        ? $result[0]->{$return_column}
        : '';

}

sub process_table {
    my ( $table_name ) = @_;

    return if $done{$table_name};

    # Get the table.
    my $table = $config->{'tables'}->{$table_name}
        || die "process_table: Table '$table_name' does not exist.\n";

    # Process tables this table depends on.
    process_table( $_ ) foreach @{ $table->{'dependencies'} };

    my $source      = $table->{'source'};
    my $destination = $table->{'destination'};

    # Create database connections.
    $source->{'connection'}      = db_connection( $source->{'connection'}      );
    $destination->{'connection'} = db_connection( $destination->{'connection'} );

    print "Processing table '$table_name'\n"
        if $verbose;

    db_table_apply( $table );

    $done{$table_name} = 1;

}

sub set_connection_parameter {
    my ( $identifier, $value ) = @_;

    my ( $name, $key ) = split /\./, $identifier;

    if ( defined $name && defined $key ) {

        if ( exists $config->{'connections'}->{$name} ) {

            if ( $key =~ /^(username|password|database|host)$/ ) {

                $config->{'connections'}->{$name}->{$key} = $value;

            } else {

                die "Invalid key name '$key' for connection.\nValid keys are: username, password, database, host.\n";

            }

        } else {

            die "Connection '$name' does not exist.\nValid connections: " . join( ', ', keys %{ $config->{'connections'} } ) . ".\n";

        }

    }

}

############################################################
# MAIN                                                     #
############################################################

my $opt_all;
my $options = {
    'all'     => \$opt_all,
    'verbose' => \$verbose,
    'show'    => \$show,
};

Getopt::Long::Configure ("bundling");
GetOptions(
    $options,
    'all|a',
    'verbose|v',
    'show|s',
    'connection|c=s%' => sub { set_connection_parameter( $_[1], $_[2] ) }
);

print "Only showing what will happen.\n"
    if $show;

my @selected_tables = @ARGV;

unless ( @selected_tables ) {

    if ( $opt_all ) {

        print "Procesing all tables.\n";
        @selected_tables = keys %{ $config->{'tables'} };

    } else {

        my $count = keys %{ $config->{'tables'} };
        die "To process all $count tables use --all\n";

    }

}

process_table( $_ ) foreach @selected_tables;

