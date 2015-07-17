package XTracker::Stock::Log::ProductLog;

use strict;
use warnings;
use Carp;

use XTracker::Handler;
use XTracker::Navigation qw( get_navtype build_sidenav );
use XTracker::Database::Product qw( get_product_summary get_product_id );
use XTracker::Database::Logging qw( get_delivery_log );
use XTracker::Database::OrderProcess qw( get_allocated_details );

sub handler {
    my $handler = XTracker::Handler->new(shift);
    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    my $prod_id     = $handler->{param_of}{'product_id'} || 0;
    my $variant_id  = $handler->{param_of}{'variant_id'} || 0;
    my @levels      = split( /\//, $handler->{data}{uri} );
    my $log_type    = $levels[5];

    my %args;
    if ($prod_id) {
        %args           = ( type => 'product_id', id => $prod_id );
        $args{navtype}  = get_navtype( { dbh => $dbh, auth_level => $handler->{data}{auth_level}, type => 'product', id => $handler->{data}{operator_id} } );
    }
    else {
        $prod_id        = get_product_id($dbh,{ type => 'variant_id', id => $variant_id });
        %args           = ( type => 'variant_id', id => $variant_id );
        $args{navtype}  = get_navtype( { dbh => $dbh, auth_level => $handler->{data}{auth_level}, type => 'variant', id => $handler->{data}{operator_id} } );
    }
    $args{operator_id}  = $handler->{data}{operator_id};

    # get common product summary data for header
    $handler->{data}{product_id}    = $prod_id;
    $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );

    my $voucher = $schema->resultset('Voucher::Product')->find( $prod_id );
    # Decide which log is requested and call appropriate function
    CASE: {
        # Delivery Log
        if ($log_type eq "DeliveryLog") {
            $handler->{data}{log_title}     = 'Delivery Log';
            $handler->{data}{log_tt_file}   = 'page_elements/log_body.tt';
            # If we have a voucher we want to prepare the data for the
            # template
            if ( $voucher ) {
                my $delivery_log_rs = $voucher->delivery_logs->order_for_log;
                $handler->{data}{log_data} = {
                    $voucher->channel->name => [
                        map {
                            time => $_->date->strftime('%R'),
                            date => $_->date->strftime('%F'),
                            quantity => $_->quantity,
                            operator => $_->operator->name,
                            delivery_id => $_->delivery_id,
                            sales_channel => $voucher->channel->name,
                            notes => ( $_->notes ? $_->notes : 'none' ),
                            action => $_->delivery_action->action,
                            type => 'Main',
                        }, $delivery_log_rs->all
                    ]
                };
            }
            else {
                $handler->{data}{log_data} = get_delivery_log( $dbh, $prod_id );
            }
            last CASE;
        }
        # Allocated Log
        if ($log_type eq "AllocatedLog") {
            $handler->{data}{log_title}     = 'Allocated Log';
            $handler->{data}{log_tt_file}   = 'logs/allocated_log.tt';
            $handler->{data}{log_data}      = get_allocated_details( $dbh, \%args );
            last CASE;
        }
        # Discrepancy Log
        if ($log_type eq "DiscrepancyLog"){
            $handler->{data}{log_title}     = 'Discrepancy Log';
            $handler->{data}{log_tt_file}   = 'logs/discrepancy_log.tt';
            my %data;
            if ($handler->{param_of}{'product_id'}){
               my $logs = $schema->resultset('Public::LogPutawayDiscrepancy')->search(
                                                    {
                                                        'variant.product_id' => $prod_id
                                                    },
                                                    {
                                                        join => 'variant'
                                                    },
                                                );
                while (my $log = $logs->next){
                    push @{$data{$log->channel->name}}, $log ;
                }
            }
            elsif($variant_id){
                my $logs = $schema->resultset('Public::LogPutawayDiscrepancy')->search({variant_id => $variant_id});
                while (my $log = $logs->next){
                    push @{$data{$log->channel->name}}, $log ;
                }
            }
            $handler->{data}{log_data}      = \%data;
        }
    };

    # Place in a data structure for TT
    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Inventory';
    $handler->{data}{subsubsection} = $handler->{data}{log_title};
    $handler->{data}{content}       = 'logs/product_log.tt';
    $handler->{data}{sidenav}       = build_sidenav(\%args);

    # TT Dispatch
    return $handler->process_template;
}

1;
