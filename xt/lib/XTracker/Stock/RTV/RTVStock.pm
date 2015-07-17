package XTracker::Stock::RTV::RTVStock;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);
use Hash::Util                  qw(lock_hash);

use XTracker::Handler;
use XTracker::Constants::FromDB qw(:rma_request_detail_type);
use XTracker::Database::RTV     qw(:rtv_stock :rma_request update_fields);
use XTracker::Database::Channel qw( get_channels );
use XTracker::Utilities         qw( :edit );

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);
    my $schema      = $handler->{schema};

    my $RTV_CONSTANTS_REF = {
        RMA_REQUEST_DETAIL_TYPE__CUSTOMER_REPAIR    => $RMA_REQUEST_DETAIL_TYPE__CUSTOMER_REPAIR,
    };
    lock_hash(%$RTV_CONSTANTS_REF);

    $handler->{data}{section} = 'RTV';
    $handler->{data}{subsection}            = 'Request RMA';
    $handler->{data}{subsubsection}         = 'Search';
    $handler->{data}{content}               = 'rtv/rtv_stock.tt';
    $handler->{data}{tt_process_block}      = 'rtv_stock';
    $handler->{data}{rtv_constants}         = $RTV_CONSTANTS_REF;
    $handler->{data}{item_fault_types} = list_item_fault_types( { dbh => $handler->{dbh} } );
    $handler->{data}{rtv_designers} = list_rtv_stock_designers( { dbh => $handler->{dbh} } );
    $handler->{data}{request_detail_type}   = list_rma_request_detail_types( { dbh => $handler->{dbh} } );
    $handler->{data}{channels}              = $schema->resultset('Public::Channel')->channel_list;

    # get product or variant id from url
    $handler->{data}{search_params}{highlight_row_id}   = exists $handler->{param_of}{highlight_row_id} ? $handler->{param_of}{highlight_row_id} : '';
    $handler->{data}{search_params}{select_designer_id} = exists $handler->{param_of}{select_designer_id} ? $handler->{param_of}{select_designer_id} : '';
    $handler->{data}{search_params}{select_product_id}  = exists $handler->{param_of}{select_product_id}  ? $handler->{param_of}{select_product_id}  : '';
    $handler->{data}{search_params}{select_channel}     = exists $handler->{param_of}{select_channel}  ? $handler->{param_of}{select_channel}  : '';
    ($handler->{data}{search_params}{select_channel_id}, $handler->{data}{sales_channel}) = split(/__/, $handler->{data}{search_params}{select_channel});


    if ( $handler->{data}{search_params}{select_channel_id} ) {

        my $search_type;
        my $search_id;

        if ( $handler->{data}{search_params}{select_product_id} =~ m{\A\d+\z}xms ) {
            $search_type    = 'product_id';
            $search_id      = $handler->{data}{search_params}{select_product_id};
        }
        elsif ( $handler->{data}{search_params}{select_designer_id} =~ m{\A\d+\z}xms ) {
            $search_type   = 'designer_id';
            $search_id     = $handler->{data}{search_params}{select_designer_id};
        }
        else {
            $search_type   = 'all';
        }

        $handler->{data}{rtv_stock_list}  = list_rtv_stock({
            dbh             => $handler->{dbh},
            rtv_stock_type  => 'RTV Process',
            type            => $search_type,
            id              => $search_id,
            hide_requested  => 1,
            channel_id      => $handler->{data}{search_params}{select_channel_id},
        });
    }

    $handler->process_template( undef );

    return OK;
}

1;

__END__
