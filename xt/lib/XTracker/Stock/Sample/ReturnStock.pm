package XTracker::Stock::Sample::ReturnStock;

use strict;
use warnings;
use Carp;

use Data::Dumper;
use Date::Format;
require File::Temp;
use File::Temp ();
use IO::Handle;

use XTracker::Handler;
use XTracker::Database::Product         qw( get_size_id get_product_id get_product_summary get_variant_list );
use XTracker::Database::Profile         qw( get_department );
use XTracker::Database::Stock;
use XTracker::Database::Sample          qw( get_sample_rma );
use XTracker::Utilities                 qw( get_date_db );
use XTracker::Navigation                qw( get_navtype build_sidenav );
use XTracker::Barcode                   qw( create_barcode );
use XTracker::PrintFunctions;

sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $prod_id         = $handler->{param_of}{'product_id'} || 0;
    my $variant_id      = $handler->{param_of}{'variant_id'} || 0;
    my $error           = $handler->{param_of}{'error'}      || 0;
    my $action          = $handler->{param_of}{'action'}     || 0;
    my $rma             = $handler->{param_of}{'rma'};

    my $barcode_file    = '';
    my $navtype         = "";
    my $product_id      = 0;

    my %args = ( operator_id => $handler->operator_id );

    if ( $variant_id ) {
        $args{type} = 'variant_id';
        $args{id}   = $variant_id;
        $navtype    = "variant";
        $product_id = get_product_id( $handler->{dbh}, { type => 'variant_id', id => $variant_id } );
    }
    elsif ( $prod_id ) {
        $args{type} = 'product_id';
        $args{id}   = $prod_id;
        $navtype    = "product";
        $product_id = $prod_id;
    }
    else {
        $action = 'print';
    }

    $args{'navtype'}    = get_navtype( { dbh => $handler->{dbh}, auth_level => $handler->auth_level, type => $navtype, id => $handler->operator_id } );
    $handler->{data}{department}    = get_department( { id => $handler->operator_id } );

    $handler->{data}{orig_type}     = $args{type};
    $handler->{data}{orig_type_id}  = $args{id};


    if ( $action eq 'print' ) {

        my $rma_details_ref     = get_sample_rma( $handler->{dbh}, { type => 'rma_number', id => $handler->{param_of}{'rma'} } );
        my $sku                 = $rma_details_ref->{product_id}.'-'.sprintf("%03d", $rma_details_ref->{size_id});

        $handler->{data}{product_id}        = $rma_details_ref->{product_id};
        $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );

        $barcode_file   = create_barcode("rma-$rma", $rma, 'small', 3, 1, 100)
            ? XTracker::PrintFunctions::path_for_print_document({
                document_type => 'barcode',
                id => "rma-$rma",
                extension => 'png',
                relative => 1, # want path relative to printdocs root
            })
            : '';

        $handler->{data}{content}           = 'sample/returnstockrma.tt';
        $handler->{data}{action}            = 'print';
        $handler->{data}{channel_name}      = $rma_details_ref->{sales_channel};
        $handler->{data}{sidenav}           = build_sidenav( \%args );
        $handler->{data}{printed_date}      = time2str("%Y-%m-%d", time());
        $handler->{data}{rma_details}       = $rma_details_ref;
        $handler->{data}{sku}               = $sku;
        $handler->{data}{id_args}           = \%args;
        $handler->{data}{barcode_file}      = $barcode_file;

    }
    elsif ( $action eq 'RMA' ) {

        my $rma_details_ref     = get_sample_rma( $handler->{dbh}, { type => 'rma_number', id => $handler->{param_of}{'rma'} } );

        $barcode_file   = create_barcode("rma-$rma", $rma, 'small', 3, 1, 100)
            ? XTracker::PrintFunctions::path_for_print_document({
                document_type => 'barcode',
                id => "rma-$rma",
                extension => 'png',
                relative => 1, # want path relative to printdocs root
            })
            : '';

        $handler->{data}{product_id}        = $product_id;
        $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );

        $handler->{data}{content}           = 'sample/returnstockrma.tt';
        $handler->{data}{channel_name}      = $rma_details_ref->{sales_channel};
        $handler->{data}{action}            = 'default';
        $handler->{data}{size}              = get_size_id( { dbh => $handler->{dbh}, variant_id => $variant_id } );
        $handler->{data}{curr_date}         = get_date_db( { dbh => $handler->{dbh}, format_string => 'DD/MM/YYYY HH24:MI:SS' } );
        $handler->{data}{rma}               = $rma;
        $handler->{data}{barcode_file}      = $barcode_file;
        $handler->{data}{sidenav}           = build_sidenav( \%args );
        $handler->{data}{id_args}           = \%args;

        $handler->{data}{sku}               = $handler->{data}{product}{id} . '-' . $handler->{data}{size};

    }
    else {

        $handler->{data}{product_id}        = $product_id;
        $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );

        $handler->{data}{content}           = 'sample/returnstock.tt';
        $handler->{data}{section}           = "Stock Control";
        $handler->{data}{subsection}        = "Sample";
        $handler->{data}{subsubsection}     = "Return Stock";
        $handler->{data}{type}              = "Sample Room Stock";
        $handler->{data}{variant}           = get_variant_list( $handler->{dbh}, \%args );
        $handler->{data}{located}           = get_located_stock( $handler->{dbh}, \%args );
        $handler->{data}{variant_id}        = $variant_id;
        $handler->{data}{sidenav}           = build_sidenav( \%args );

    }

    return $handler->process_template;
}

1;
