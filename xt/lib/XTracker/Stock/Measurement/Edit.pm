package XTracker::Stock::Measurement::Edit;

use strict;
use warnings;

=head1 NAME

XTracker::Stock::Measurement::Edit

=head1 DESCRIPTION

This Page will Show the Measurements for a Product and will also create a Size
Preview chart which is ultimately pushed to the Web-Site.

This module can be called from two places:

    '/StockControl/Inventory' Left Hand Menu

    and the from the Main Nav

    '/StockControl/Measurement'

When it is called from the Left Hand Menu it is in Read-Only mode.

=cut

use Carp;
use Math::Round;

use XTracker::Database;
use XTracker::Handler;
use XTracker::XTemplate;
use XTracker::Database::Product      qw( get_product_summary );
use XTracker::Database::StockProcess qw( get_suggested_measurements );
use XTracker::Error;
use XTracker::Navigation qw( get_navtype build_sidenav );

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{content}           = 'stocktracker/measurement/edit.tt';
    $handler->{data}{section}           = 'Stock Control';

    # where to go back to if there are problems
    my $redirect_url    = (
        $handler->{data}{uri} =~ /Inventory/
        ? '/StockControl/Inventory'
        : '/StockControl/Measurement'
    );

    my $product_id = $handler->{param_of}{product_id};
    unless ( ( $product_id // '' ) =~ /^\s*\d+\s*$/ ) {
        xt_warn("Invalid Product Id");
        return $handler->redirect_to( $redirect_url );
    }

    my $schema = $handler->schema;
    my $product = $schema->resultset('Public::Product')->find( $product_id );

    unless ( $product ) {
        xt_warn("Product Not Found!");
        return $handler->redirect_to( $redirect_url );
    }
    $handler->{data}{product_id} = $product_id; # still needed by template
    $handler->add_to_data( get_product_summary($schema, $product_id) );

    if ( $handler->{data}{uri} =~ /Inventory/ ) {
    # If we're viewing this via the Inventory section.

        # Set the Sub Section.
        $handler->{data}{subsection}    = 'Inventory';
        $handler->{data}{subsubsection} = 'Measurements';
        $handler->{data}{read_only}     = 1;

        # Populate the side menu.
        $handler->{data}{sidenav}    = build_sidenav( {
            type        => 'product_id',
            id          => $handler->{data}{product_id},
            operator_id => $handler->{data}{operator_id},
            navtype     => get_navtype( {
                type       => 'product',
                auth_level => $handler->{data}{auth_level},
                id         => $handler->{data}{operator_id}
            } ),
        } );

    } else {

        # Set the Sub Section.
        $handler->{data}{subsection}    = 'Measurement';
        $handler->{data}{subsubsection} = 'Edit Measurements';
        $handler->{data}{read_only}     = 0;

        # Just add a back button.
        push @{ $handler->{data}{sidenav} },
            { 'None' => [ { title => 'Back', url => '/StockControl/Measurement' } ] };

    }

    # Get all appropriate product measurements

    # Get measurements that are to be shown on website
    $handler->{data}{shown_measurements} = [$product->get_ordered_shown_measurements];

    # Look at getting rid of $type_measurements by using this -
    # measurements should all be present in variant_measurements
    $handler->{data}{measurements}
        = get_suggested_measurements( $schema->storage->dbh, $product_id );
    $handler->{data}{variants}   = [$product->get_stock_variants->all];
    $handler->{data}{size_chart} = create_size_chart( $product );
    $handler->{data}{measurement_log} = [ map { { time => $_->date->hms, name => $_->operator->name, date => $_->date->ymd } }
                                            $product->variants->search_related('variant_measurements_logs',undef,{group_by => ['operator_id', 'date'],
                                                                                                                  order_by => { -desc => 'date'},
                                                                                                                  columns  => ['operator_id', 'date']
                                                                                                                 })->all ];
    return $handler->process_template;
}

# NOTE: This sub is also called from XTracker::Comms::DataTransfer...
sub create_size_chart {
    my ( $product, $conversion ) = @_;

    unless ( ref $product ) {
        croak "you must pass this sub a pid or a Public::Product DBIC Row object"
            unless $product =~ m{^\d+$};

        my $schema = XTracker::Database::get_database_handle({name => 'xtracker_schema'});
        $product = $schema->resultset('Public::Product')->find($product)
            || croak "Could not find product $product";
    }

    my @variants = $product->get_stock_variants->all;
    my @shown_measurements = $product->get_ordered_shown_measurements;

    my %active_variants;
    my $non_zero;
    my $measurements;

    # Find which shown measurements have non-zero entries
    foreach my $shown_measurement ( @shown_measurements ) {
        foreach my $variant ( @variants ) {
            VARIANT_MEASUREMENT:
            for my $variant_measurement ( $variant->variant_measurements->all ) {
                next VARIANT_MEASUREMENT
                    if $variant_measurement->measurement_id != $shown_measurement->measurement_id;
                next VARIANT_MEASUREMENT unless $variant_measurement->value;

                my $measurement_value = $variant_measurement->value;

                # apply conversion if required
                if ($conversion) {
                    # convert and round to nearest .5
                    $measurement_value = nearest(.5, ($measurement_value * $conversion));

                    # if rounding took us to 0 then use 0.5
                    if ($measurement_value == 0) {
                        $measurement_value = 0.5
                    }
                }

                $measurements->{$variant_measurement->measurement_id}{$variant->id}
                    = $measurement_value;

                $non_zero->{$variant_measurement->measurement_id} = 1;

                # record the fact that this variant has been used at least once
                $active_variants{$variant->id}  = 1;
            }
        }
    }

    my $size_conversion = {
        'xx small'  => 'XXS',
        'x small'   => 'XS',
        'small'     => 'S',
        'medium'    => 'M',
        'large'     => 'L',
        'x large'   => 'XL',
        'xx large'  => 'XXL',
        'xxx large' => 'XXXL',
    };

    ### build size chart
    my $chart = q{};
    if ( keys %{$non_zero} ) {
        XTracker::XTemplate->template->process(
            'stocktracker/measurement/size_chart.tt',
            {
                template_type => 'none',
                # display only thoose variants that are in the chart
                variants           => [ grep { exists $active_variants{$_->id} } @variants ],
                shown_measurements => \@shown_measurements,
                measurements       => $measurements,
                size_conversion    => $size_conversion,
                non_zero           => $non_zero,
            },
            \$chart,
        );
    }
    return $chart;
}

1;
