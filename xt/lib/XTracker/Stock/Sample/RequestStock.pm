package XTracker::Stock::Sample::RequestStock;

use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Attributes  qw( get_sample_request_reason );
use XTracker::Navigation            qw( get_navtype build_sidenav );
use XTracker::Database::Product     qw( get_product_id get_product_summary
                                        get_variant_list get_variant_id
                                        get_variant_id_by_type get_variant_type );
use XTracker::Database::Stock;
use XTracker::Database::Profile     qw( get_department );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $args;
    my $type    = "";
    my $navtype;


    if ( $handler->{param_of}{product_id} ) {
        $type           = 'product';
        $args->{type}   = 'product_id';
        $args->{id}     = $handler->{param_of}{product_id};
    }
    elsif ( $handler->{param_of}{variant_id} ) {
        $type           = 'variant';
        $args->{type}   = 'variant_id';
        $args->{id}     = $handler->{param_of}{variant_id};
    }
    $navtype    = get_navtype( { dbh => $handler->{dbh}, auth_level => $handler->auth_level, type => $type, id => $handler->operator_id } );

    $args->{navtype}    = $navtype;

    $handler->{data}{content}           = 'stocktracker/sample/requeststock.tt';
    $handler->{data}{section}           = 'Stock Control';
    $handler->{data}{subsection}        = 'Sample';
    $handler->{data}{subsubsection}     = 'Request Stock';
    $handler->{data}{sidenav}           = build_sidenav( $args );
    $handler->{data}{types}             = [ 'type_id', get_sample_request_reason( $handler->{dbh} ) ];
    $handler->{data}{type}              = 'Sample';

    $handler->{data}{department}        = get_department( { dbh => $handler->{dbh}, id => $handler->operator_id } );

    # Store which parameters the module was called so when it is redirected back to from CreateStockTransferRequest
    # they can be passed back and correctly show the correct menu structure amongst other things
    $handler->{data}{orig_type}         = $args->{type};
    $handler->{data}{orig_id}           = $args->{id};

    if ( $handler->{param_of}{product_id} or $handler->{param_of}{variant_id} ) {

        # if no size is specified
        if ( $handler->{param_of}{product_id} ) {
            $handler->{data}{product_id}    = $handler->{param_of}{"product_id"};
            my $variant_id = get_variant_id( $handler->{dbh}, { type => 'product_id', id => $handler->{data}{product_id}, stock_type => 'stock' } );

            $handler->{data}{variant_id}    = $variant_id;
        }
        # else a size has been specified
        else {

            # convert the Sample (if it is one) to Stock
            if ( 'Sample' eq get_variant_type( $handler->{dbh}, { id => $handler->{param_of}{"variant_id"} } ) ) {
                $handler->{data}{variant_id}    = get_variant_id_by_type( $handler->{dbh}, { variant_id => $handler->{param_of}{"variant_id"}, from_type => 'Sample', to_type => 'Stock' } );
            }
            else {
                $handler->{data}{variant_id}    = $handler->{param_of}{"variant_id"};
            }

            $handler->{data}{product_id}    = get_product_id( $handler->{dbh},{ type => 'variant_id', id => $handler->{param_of}{"variant_id"} } );
        }

        $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );

        $handler->{data}{variant}   = get_variant_list( $handler->{dbh},{ type => 'variant_id', id => $handler->{data}{variant_id} });
    }

    $handler->process_template( undef );

    return OK;
}

1;
