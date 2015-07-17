package XTracker::Stock::Log::VariantLog;

use strict;
use warnings;
use Carp;

use XTracker::Handler;
use XTracker::Navigation qw( get_navtype build_sidenav );
use XTracker::Database::Profile qw( get_department );
use XTracker::Database::Product qw( get_product_summary get_product_id );
use XTracker::Database::Logging qw( get_stock_log
                                    get_pws_log
                                    get_rtv_log
                                    get_cancellation_log
                                    get_location_log );
use XTracker::Database::Reservation;

sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $prod_id     = $handler->{param_of}{'product_id'} || 0;
    my $variant_id  = $handler->{param_of}{'variant_id'} || 0;
    my @levels      = split( /\//, $handler->{data}{uri} );
    my $log_type    = $levels[5];

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    $handler->{data}{department} = get_department({
        dbh => $dbh,
        id => $handler->{data}{operator_id},
    });

    my %args;

    # Ok - this module is called VariantLog - in what scenario do we not pass
    # it a variant_id?
    if ($prod_id) {
        %args          = ( type => 'product_id', id => $prod_id );
        $args{navtype} = get_navtype({
            dbh        => $dbh,
            auth_level => $handler->{data}{auth_level},
            type       => 'product',
            id         => $handler->{data}{operator_id},
        });
    }
    else {
        $prod_id = get_product_id( $dbh,
            { type => 'variant_id', id => $variant_id, },
        );
        %args = ( type => 'variant_id', id => $variant_id );
        $args{navtype} = get_navtype({
            dbh        => $dbh,
            auth_level => $handler->{data}{auth_level},
            type       => 'variant',
            id         => $handler->{data}{operator_id},
        });
    }
    $args{operator_id} = $handler->{data}{operator_id};

    # get common product summary data for header
    $handler->{data}{product_id} = $prod_id;
    $handler->add_to_data( get_product_summary( $schema, $handler->{data}{product_id} ) );

    # Decide which log is wanted and call appropriate function
    CASE: {
        # Transaction Log
        if ($log_type eq "StockLog") {
            $handler->{data}{log_title}   = 'Transaction Log';
            $handler->{data}{log_tt_file} = 'logs/stock_log.tt';
            $handler->{data}{log_data}    = get_stock_log( $dbh, \%args );
            last CASE;
        }
        # PWS Log
        if ($log_type eq "PWSLog") {
            $handler->{data}{log_title}   = 'PWS Log';
            $handler->{data}{log_tt_file} = 'logs/pws_log.tt';
            $handler->{data}{log_data}    = get_pws_log( $dbh, \%args );
            last CASE;
        }
        # RTV Log
        if ($log_type eq "RTVLog") {
            $handler->{data}{log_title}   = 'RTV Log';
            $handler->{data}{log_tt_file} = 'logs/rtv_log.tt';
            $handler->{data}{log_data}    = get_rtv_log( $dbh, \%args );
            last CASE;
        }
        # Reservation Log
        if ($log_type eq "ReservationLog") {
            $handler->{data}{log_title}   = 'Reservation Log';
            $handler->{data}{log_tt_file} = 'logs/reservation_log.tt';
            $handler->{data}{log_data}    = get_reservation_log( $dbh, \%args );
            last CASE;
        }
        # Cancellation Log
        if ($log_type eq "CancellationLog") {
            $handler->{data}{log_title}   = 'Cancellation Log';
            $handler->{data}{log_tt_file} = 'logs/cancellation_log.tt';
            $handler->{data}{log_data}    = get_cancellation_log( $dbh, \%args );
            last CASE;
        }
        # Location / Old Location Log
        if ($log_type eq "LocationLog") {
            $handler->{data}{log_title} = "Location Log";
            if (exists $handler->{param_of}{logtype}) {
                $args{'logtype'} = $handler->{param_of}{logtype};
                $handler->{data}{log_title} = "Old Location Log";
            }
            $handler->{data}{log_tt_file} = 'logs/location_log.tt';
            $handler->{data}{log_data}    = get_location_log( $dbh, \%args );
            last CASE;
        }
        # Sample Adjustment Log
        if ($log_type eq 'SampleAdjustmentLog') {
            $handler->{data}{log_title} = 'Sample Adjustment Log';
            $handler->{data}{log_tt_file} = 'logs/sample_adjustment_log.tt';
            $handler->{data}{log_data} = $schema->resultset('Public::LogSampleAdjustment')->data_for_log_screen({ variant_id => $variant_id });
            last CASE;
        }
    };

    # Place in a data structure for TT
    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Inventory';
    $handler->{data}{subsubsection} = $handler->{data}{log_title};
    $handler->{data}{content}       = 'logs/variant_log.tt';
    $handler->{data}{sidenav}       = build_sidenav(\%args);

    # TT Dispatch
    return $handler->process_template;
}

1;
