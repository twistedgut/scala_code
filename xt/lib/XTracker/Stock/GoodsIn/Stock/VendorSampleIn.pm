package XTracker::Stock::GoodsIn::Stock::VendorSampleIn;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Channel qw( get_channels );
use XTracker::Database::Attributes qw( get_faulty_atts );
use XTracker::Database::Product qw( get_product_summary );
use XTracker::Database::Sample qw( get_vendor_sample_shipment_items );

use vars qw( $operator_id $department_id );

sub handler {
    my $handler = XTracker::Handler->new(shift);


    my $channel_id = $handler->{param_of}{channel_id};

    $handler->{data}{section} = 'Vendor Sample';
    $handler->{data}{subsection} = 'Quality Control';
    $handler->{data}{subsubsection} = '';

  CASE: {
        if ( $handler->{param_of}{scan} ) {

            my ( $product_id, $size_id ) = split( /-/, $handler->{param_of}{psku} );

            if ( my $variant = get_vendor_sample_shipment_items( $handler->{dbh}, { product_id => $product_id, size_id => $size_id, channel_id => $channel_id } ) ) {

                $handler->{data}{sidenav} = [{ 'None' => [{ title => 'Back to List', url => '/GoodsIn/VendorSampleIn?show_channel='.$channel_id }] }];
                $handler->{data}{content} = 'stocktracker/goods_in/stock/vendorsampleqccheck.tt';
                $handler->{data}{type} = 'product_id';
                $handler->{data}{id} = $handler->{param_of}{psku};
                $handler->{data}{product_id} = $product_id;
                $handler->{data}{variant_id} = $variant->{variant_id};
                $handler->{data}{size_id} = $size_id;
                $handler->{data}{size} = $variant->{size};
                $handler->{data}{variant_type} = 'Sample';
                $handler->{data}{primary_loc} = 'Transfer Pending';
                $handler->{data}{faultys} = [ 'fault_reason', get_faulty_atts( $handler->{dbh} ) ];
                $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );

                $handler->{data}{sales_channel} = $variant->{sales_channel};
                $handler->{data}{channel_id} = $channel_id;

                last CASE;
            }
            else {
                $handler->{data}->{error_msg} = "cannot find SKU: ".$handler->{param_of}{psku}." (check you selected the correct Sales Channel)";
            }

        }

        $handler->{data}->{shipment_items} = get_vendor_sample_shipment_items( $handler->{dbh} );

        my $channels = get_channels( $handler->{dbh} );
        foreach ( keys %$channels ) {
            $handler->{data}->{channels}{ $channels->{$_}{name} } = $channels->{$_};
        }

        $handler->{data}{sidenav} = "";
        $handler->{data}{content} = 'stocktracker/goods_in/stock/vendorsampleqc.tt';
        $handler->{data}{css} = ['/yui/tabview/assets/skins/sam/tabview.css'];
        $handler->{data}{js} = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];
    }
    ;

    $handler->process_template( undef );

    return OK;
}

1;
