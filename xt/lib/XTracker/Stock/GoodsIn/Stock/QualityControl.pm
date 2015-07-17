package XTracker::Stock::GoodsIn::Stock::QualityControl;

use NAP::policy "tt";

use XTracker::Handler;
use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Database::Delivery qw( get_delivery get_delivery_channel );
use XTracker::Database::StockProcess qw( :DEFAULT :measurements );
use XTracker::Database::Attributes qw( :DEFAULT );
use XTracker::Database::Product qw(:DEFAULT get_product_summary);
use XTracker::Database::Utilities qw( is_valid_database_id );
use XTracker::Error qw( xt_warn );
use XTracker::Config::Local qw( config_var );
use List::UtilsBy qw( uniq_by );
use JSON;

sub handler {
    my $h = XTracker::Handler->new(shift);

    # delivery id and errors from url
    $h->{data}{delivery_id} = $h->{request}->param('delivery_id') || 0;
    $h->{data}{error} = $h->{request}->param('error') || 0;
    $h->{data}{section} = 'Goods In';
    $h->{data}{subsection} = 'Quality Control';
    $h->{data}{subsubsection} = '';
    $h->{data}{content} = 'goods_in/stock/quality_control.tt';

    # Redirect to printer selection screen unless operator has one set
    return $h->redirect_to($h->printer_station_uri)
        unless $h->operator->has_location_for_section('goods_in_qc');

    # delivery id defined then we're processing a product
    return _handle_delivery($h) if $h->{data}{delivery_id};

    # no delivery defined show list
    # data to populate barcode form
    $h->{data}{scan}{action}  = '/GoodsIn/QualityControl';
    $h->{data}{scan}{field}   = 'delivery_id';
    $h->{data}{scan}{name}    = 'Delivery Id';
    $h->{data}{scan}{title}   = 'Quality Control';

    # get list of deliveries
    $h->{data}{deliveries} = $h->schema->resultset('Public::Delivery')->for_qc
        unless $h->{data}{datalite};
    $h->{data}{sidenav} = [{ "None" => [
            {
                'title' => 'Set Quality Control Station',
                'url' => "/My/SelectPrinterStation?section=GoodsIn&subsection=QualityControl&force_selection=1"
            } ] }];

    return $h->process_template;
}

sub _handle_delivery {
    my ($h) = @_;

    my $schema = $h->schema;
    my $dbh = $schema->storage->dbh;

    my $delivery_id = $h->{data}{delivery_id};

    my $delivery;

    # First ensure that the delivery_id is valid
    my $err;
    try {
        if ( ! is_valid_database_id($delivery_id) ) {
            die q{invalid delivery id '}.($delivery_id // '').q{'};
        }
        $delivery = $schema->resultset('Public::Delivery')->find($delivery_id);
        die "Delivery $delivery_id can't be found" unless $delivery;
    }
    catch {
        $err = 1;
        xt_warn( "Delivery $delivery_id can't be found" );
    };
    return $h->redirect_to('/GoodsIn/QualityControl') if $err;

    if (!$delivery->ready_for_qc) {
      xt_warn( "Delivery $delivery_id is not ready for QC" );
      return $h->redirect_to('/GoodsIn/QualityControl');
    }

    $h->{data}{subsubsection} = 'Process Item';
    # form field data
    $h->{data}{scan}{name} = 'Delivery Id';
    $h->{data}{scan}{action} = 'Book';
    $h->{data}{scan}{field} = 'delivery_id';

    # get delivery data
    $h->{data}{delivery}  = get_delivery( $dbh, $h->{data}{delivery_id});
    $h->{data}{sales_channel} = get_delivery_channel( $dbh, $h->{data}{delivery_id});

    $h->{data}{product_id} = get_product_id( $dbh, { type => 'delivery_id',
            id => $h->{data}{delivery_id} } );

    unless ($h->{data}{product_id}){
        xt_warn('No product id found for delivery id ' . $h->{data}{delivery_id});
        return $h->redirect_to('/GoodsIn/QualityControl');
    }

    # get common product summary data for header
    $h->add_to_data( get_product_summary( $schema, $h->{data}{product_id} ) );

    $h->{data}{weight_unit} = config_var('Units', 'weight');
    $h->{data}{dimensions_unit} = config_var('Units', 'dimensions');

    # list of countries to select country of origin
    $h->{data}{countries} = [ 'country', get_countries( $dbh ) ];

    my $product
        = $schema->resultset('Public::Product')->find($h->{data}{product_id})
       || $schema->resultset('Voucher::Product')->find($h->{data}{product_id});
    unless ($product ) {
        xt_warn("Couldn't find product for id: '$h->{data}{product_id}'");
        return $h->redirect_to('/GoodsIn/QualityControl');
    }

    # list storage types to select.
    $h->{data}{storage_types} = $schema->resultset('Product::StorageType')
        ->get_options
        ->search({
            ($product->storage_type_id ? (id => $product->storage_type_id) : ())
        });

    $h->{data}{attribute} = $product->shipping_attribute;

    if($h->{data}{voucher}) {
        # A JS object/hash of whether or not a given voucher code has already been scanned.
        my $code = { map {
            $_ => 0
        } $delivery->stock_order->get_voucher_codes->get_column('code')->all };
        $h->{data}{code} = encode_json( $code );
        $h->{data}{code_count} = scalar keys %$code;
        $h->{data}{stock_process} = $delivery->delivery_items->related_resultset('stock_processes');
    }
    else {
        $h->{data}{stock_process_items} = get_stock_process_items(
            $dbh, 'delivery_id',
            $h->{data}{delivery_id}, 'quality_control'
        );

        # required measurement info
        my $suggest_ref = $h->{data}{measurements} = get_suggested_measurements( $dbh, $h->{data}{product_id} );
        my $measure_ref = get_measurements( $dbh, $h->{data}{product_id} );
        # remove duplicate variants on measure_items
        $h->{data}{measure_items} = [ uniq_by { $_->{variant_id} } @{$h->{data}{stock_process_items}} ];
        ($h->{data}{processed_measurements},$h->{data}{measurement_values})
             = _process_measurements( $suggest_ref, $measure_ref, $h->{data}{measure_items} );

        $h->{data}{variants} = [$product->get_stock_variants->all];
        $h->{data}{qc_page}  = 1;
    }

    # left nav links
    push @{ $h->{data}{sidenav}[0]{'None'} },
        { title => 'Back',
          url => "/GoodsIn/QualityControl" },
        { title => 'Fast Track',
          url => "/GoodsIn/QualityControl/FastTrack?delivery_id=$h->{data}{delivery_id}" },
        { title => 'Hold Delivery',
          url => "/GoodsIn/DeliveryHold/HoldDelivery?delivery_id=$h->{data}{delivery_id}" };

    return $h->process_template;
}

sub _process_measurements {
    my ( $suggest_ref, $measure_ref, $sp_ref ) = @_;
    my %measurements = ();
    my %measurement_values = ();

    foreach my $record (@$sp_ref) {
        my $v_id = $record->{variant_id};
        my @measurement_list = ();
        foreach my $measure (sort {($a->{sort_order}||0) <=> ($b->{sort_order}||0)} @$suggest_ref) {
            push @measurement_list, $measure->{measurement};
            $measurement_values{$v_id}->{ $measure->{measurement} } = $measure_ref->{$v_id}->{$measure->{id}};
        }
        $measurements{$v_id}->{measurement_list} = \@measurement_list;
    }

    return (\%measurements, \%measurement_values);
}

1;

