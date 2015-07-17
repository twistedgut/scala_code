package XTracker::Stock::GoodsIn::Barcode;

use strict;
use warnings;
use XTracker::Database::Product;
use XTracker::Error;
use XTracker::Handler;
use XTracker::PrintFunctions;
use XTracker::Printers;
use XTracker::Constants::FromDB qw( :season );
use XTracker::Constants::Regex qw{ :sku :pgid };

# Define label printer data
use XTracker::Config::Local qw( config_var );


sub handler {
    my $handler = XTracker::Handler->new(shift);

    $handler->{data}{section}           = 'Goods In';
    $handler->{data}{subsection}        = 'Barcode';
    $handler->{data}{content}           = 'stocktracker/goods_in/barcode.tt';

    $handler->{data}{printer_data} = [_old_printers(),_new_printers()];

    my $location = $handler->{param_of}{location};
    return $handler->process_template unless $location;

    my $redirect_uri = URI->new('/GoodsIn/Barcode');
    # TODO: Use Catalyst::Plugin::FillInForm for this instead of this ugly solution
    $redirect_uri->query_form({selected_printer => $location});

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;
    my $sku = $handler->{param_of}{sku};

    my ($prod_data, $pgroup);
    if ($sku && $sku =~ $SKU_REGEX) {
        my $variant = $schema
            ->resultset('Public::Variant')
            ->search_by_sku($sku)
            ->slice(0,0)
            ->single;

        # We reach a dead end in this path unless we can find a variant
        unless ( $variant ) {
            my $voucher = $schema->resultset('Voucher::Variant')->find_by_sku(
                $sku, { dont_die_when_cant_find => 1 }
            );
            my $error = $voucher
                ? "We don't print labels for vouchers"
                : "Couldn't find SKU '$sku'";
            xt_warn($error);
            return $handler->redirect_to($redirect_uri);
        }
        # Until we port all printers on this page to the 'new' way we'll have
        # to support two ways of printing
        if ( XTracker::Printers->new->location($location) ) {
            for my $size ( qw/large small/ ) {
                my ( $print_label, $copies, $method ) = (
                    (map { $handler->{param_of}{$_} } "print_$size", "num_$size"),
                    "${size}_label",
                );
                next unless $print_label;
                eval {
                    $variant->$method->print_at_location($location, $copies);
                    xt_success(sprintf
                        "Printed $copies $size label%s at $location",
                        $copies == 1 ? q{} : q{s}
                    );
                };
                if ( $@ ) {
                    xt_warn("There was an error printing the labels: $@");
                }
            }
            return $handler->redirect_to($redirect_uri);
        }
        # If we can't find a 'new' location we fall back to the 'old' way
        $prod_data = get_barcode_info( $dbh, $variant->id, { type => 'variant_id' } );
    }
    # Note that as an awesome side effect this elsif clause also sets $pgroup
    elsif ( $sku &&
            $sku =~ $PGID_REGEX &&
            ($pgroup = $handler->{schema}->resultset('Public::StockProcess')->get_group($sku))->first ) {
        # do nothing -- everything happened the elsif condition
    }
    else {
          xt_warn("Please enter a valid SKU or PGID");
          return $handler->redirect_to($redirect_uri);
    }

    eval {
        my $printer_data = _barcode_printer_hash();

        die "Could not find printer details for $location"
            unless exists $printer_data->{$location};

        if ( $handler->{param_of}{print_large} ) {
            print_labels($handler, $prod_data, $pgroup, 'large', \&print_large_label, $location);
        }

        if ( $handler->{param_of}{print_small} ) {
            print_labels($handler, $prod_data, $pgroup, 'small', \&print_small_label, $location);
        }
    };
    if (my $e = $@) {
        xt_warn("Unable to print barcode labels: $e");
    }
    return $handler->redirect_to($redirect_uri);
}

sub print_labels{
    my ($handler, $prod_data, $pgroup, $size, $printfunc, $printer) = @_;

    my $printer_data = _barcode_printer_hash();
    my $printer_info = $printer_data->{$printer}{$size};
    my $copies = $handler->{param_of}{"num_$size"};
    if ($pgroup){
        $pgroup->print_pgid_barcode( $printer_info, $copies );
    }
    else {
        $printfunc->( $prod_data, $printer_info, $copies );
    }
    xt_success(sprintf q{Printed %d %s barcode label(s) on the '%s' printer},
        $handler->{param_of}{"num_$size"}, $size, $printer_data->{$printer}{label});
}

# TODO replace this with PrintFunctions.pm
sub get_barcode_info {
    my ($dbh, $sku, $p) = @_;

    my $qry;

    if ( $p->{type} eq 'variant_id' ) {

        my $is_voucher  = XTracker::Database::Product::is_voucher( $dbh, { type => 'variant_id', id => $sku } ) || 0;

        $qry = "SELECT v.legacy_sku, d.designer, s.season, c.colour, si.size, p.id as product_id, v.size_id,
                       product_id || '-' || sku_padding(size_id) as sku, si2.size as designer_size
              FROM variant v, product p, designer d, season s, colour c, size si, size si2
             WHERE v.id = ?
                AND v.product_id = p.id
                AND p.designer_id = d.id
                AND p.season_id = s.id
                AND p.colour_id = c.id
                AND v.size_id = si.id
                AND v.designer_size_id = si2.id";

        if ( $is_voucher ) {
            $qry = "SELECT v.legacy_sku, 'Gift Card' as designer, s.season, 'Unknown' as colour, v.size_id as size, v.product_id, v.size_id,
                           v.product_id || '-' || sku_padding(size_id) as sku, si2.size as designer_size
                  FROM super_variant v, season s, size si2
                 WHERE v.id = ?
                    AND s.id = $SEASON__CONTINUITY
                    AND v.designer_size_id = si2.id";
        }
    }
    else {

        $qry = "SELECT v.legacy_sku, d.designer, s.season, c.colour, si.size, p.id as product_id, v.size_id,
                       product_id || '-' || sku_padding(size_id) as sku, si2.size as designer_size
              FROM variant v, product p, designer d, season s, colour c, size si, size si2
                WHERE v.legacy_sku = ?
                AND v.product_id = p.id
                AND p.designer_id = d.id
                AND p.season_id = s.id
                AND p.colour_id = c.id
                AND v.size_id = si.id
                AND v.designer_size_id = si2.id";

    }

    my $sth = $dbh->prepare($qry);
    $sth->execute($sku);

    my $data = $sth->fetchrow_hashref();

    return $data;
}

sub _old_printers {
    my $printer_data = config_var('BarCode_Printers', 'GoodsIn' ) || {};
    return (map {
        $printer_data->{ $_ }
    } sort { $a <=> $b } keys %{ $printer_data });

}

sub _new_printers {
    my $printers = config_var(qw/BarCode_Printers location/) // [];

    # TODO: When we port more stuff drop all this label stuff and use location
    return (map {
        # Once we port PGID labels these printers will support printing them
        # too
        +{label => $_, sku_only => 1 }
    } @{ ref($printers) ? $printers : [ $printers ] } );
}

sub _barcode_printer_hash {
    return { map { $_->{label} => $_ } _old_printers()};
}

1;
