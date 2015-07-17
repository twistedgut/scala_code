package XTracker::Stock::Actions::Recode;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Barcode;
use XTracker::Constants::FromDB qw( :variant_type );
use XTracker::Constants::Regex  qw( :sku );
use XTracker::Database::Stock   qw( get_transit_stock );
use XTracker::Error;
use XTracker::PrintFunctions;
use XTracker::Utilities         qw( unpack_handler_params );
use XTracker::Config::Local     qw( config_var );
use XTracker::Document::Recode;
use Try::Tiny;
use URI;

=pod

Input data from the handler

After skus to recode have been selected, either:
$rest_ref = {
          'variant_id' => '1050050'
        };
or
$rest_ref = {
          'variant_id' => [
                     '1050041',
                     '1050050'
                   ]
        };
or
$rest_ref = {
          '165058-005' => 'on',
          'action' => 'choose',
          'submit' => 'Submit »',
          '162293-005' => 'on',
          '165060-005' => 'on'
        };



On submitting recode action:
$data_ref = {
          '1' => {
                   'newquantity' => '11',
                   'newsku' => '123456-10'
                 },
          '3' => {
                   'newquantity' => '13',
                   'newsku' => '43236234-14'
                 },
          '2' => {
                   'newquantity' => '12',
                   'newsku' => '7890-12'
                 }
        };
$rest_ref = {
          'destroyquantity-48411-005' => '10',
          'action' => 'recode',
          'submit' => 'Submit »',
          'destroyquantity-48414-091' => '20',
          'notes' => 'Recode: from 165065-005(33), 165066-005(11) to 301179-023(1), 301179-023(1). ',
          'user_notes' => 'because we wanted to',
          'sales_channel' => 'MRPORTER.COM',
          'channel_id' => 5,
        };

=cut

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{content}       = 'recode.tt';
    $handler->{data}{subsection}    = 'Inventory';
    $handler->{data}{subsubsection} = 'Recode';

    # Redirect to printer selection screen unless operator has one set
    return $handler->redirect_to($handler->printer_station_uri)
        unless $handler->operator->has_location_for_section('recode');

    push @{$handler->{data}{sidenav}}, { "None" => [
        {
            'title' => 'Select Recode Station',
            'url'   => "/My/SelectPrinterStation?section=StockControl&subsection=Recode&force_selection=1"
        }]
    };

    # get those funky values out of the form
    my ( $data_ref, $rest_ref ) = unpack_handler_params( $handler->{param_of} );

    my $redirect_url;

    if (defined $rest_ref->{action} && $rest_ref->{action} eq "recode" ) {

        $redirect_url = _perform_recode($handler, $data_ref, $rest_ref);

        $handler->{data}{transit_list} = get_transit_stock( $handler->{dbh} )
            unless $redirect_url;

    } elsif (
        (defined $rest_ref->{action} && $rest_ref->{action} eq "choose" ) ||
        (defined $rest_ref->{variant_id})
    ) {
        # if they've followed a link with a sku/some skus in the url, or selected
        # some skus from the full transit list, check that they're still in transit
        # and then display them
        my $transit_list = get_transit_stock( $handler->{dbh} );
        my @list;
        my @url_variants;
        if (defined $rest_ref->{variant_id}) {
            @url_variants = (ref $rest_ref->{variant_id} eq 'ARRAY') ? @{$rest_ref->{variant_id}} : $rest_ref->{variant_id};
        }
        foreach my $channel (keys %$transit_list) {
            foreach my $index (sort keys %{$transit_list->{$channel}}) {
                my $item = $transit_list->{$channel}->{$index};
                my $sku = $item->{product_id}.'-'.$item->{sku_size};
                if (
                    (grep {/^$item->{variant_id}$/} @url_variants) ||
                    (defined $rest_ref->{$sku} && $rest_ref->{$sku} eq 'on')
                ) {
                    push @list, $item;
                }
            }
        }
        $handler->{data}{list} = \@list;
    } else {
        # get list of stock units currently in transit
        $handler->{data}{transit_list} = get_transit_stock( $handler->{dbh} );
    }

    return $handler->redirect_to($redirect_url->as_string()) if $redirect_url;

    return $handler->process_template;

}

sub _perform_recode {
    my ($handler, $data_ref, $rest_ref) = @_;

    my $schema = $handler->schema;

    # Validate parameters passed to us and munge them in to a form that the recoder
    # will understand

    my $error_messages = [];
    my $create_data = [];
    for (keys %$data_ref) {
        my $sku_data = $data_ref->{$_};

        my $munged_data = _check_and_munge_sku_data($handler, {
            sku     => $sku_data->{newsku},
            quantity=> $sku_data->{newquantity}
        }, $error_messages);
        next unless $munged_data;

        push @$create_data, $munged_data;
    }

    my $destroy_data = [];
    foreach my $key (keys %$rest_ref ) {
        # Only parse the 'destroy' sku data
        next unless $key =~ /destroy/; # param in format : 'destroyquantity-<sku>'

        my $munged_data = _check_and_munge_sku_data($handler, {
            sku     =>( split(/-/,$key,2) )[1],
            quantity=> $rest_ref->{$key},
        }, $error_messages);
        next unless $munged_data;

        push @$destroy_data, $munged_data;
    }

    # If we have already encountered problems, go no further
    if (@$error_messages){
        my $error_msg = join('<br>', @$error_messages);
        xt_warn($error_msg);

        my $redirect_uri = URI->new('/StockControl/Recode');
        my %params = map { $_->{variant}->sku() => 'on' } @$destroy_data;
        $redirect_uri->query_form({
            action => 'choose',
            %params,
        });

        return $redirect_uri;
    }

    # Then we're good to go :)
    my $recode_ok = 0;
    try {

        my $recoder = XTracker::Database::Stock::Recode->new(
            schema => $schema,
            operator_id => $handler->operator_id,
            msg_factory => $handler->msg_factory,
        );

        my $recode_objs = $recoder->recode({
            from    => $destroy_data,
            to      => $create_data,
            notes   => _create_notes($data_ref, $rest_ref),
        });

        my @recode_ids = map { $_->id() } @$recode_objs;
        $handler->{data}->{stock_recode_ids} = \@recode_ids;

        # Recode has been successful, so if we get an error from now on we know it will
        # be to do with the printing
        $recode_ok = 1;

        xt_success("Recoded old SKUs ("
            . join(", ", map { $_->{variant}->sku() } @$destroy_data )
            . ") into new SKUs ("
            . join(", ", map { $_->{variant}->sku() } @$create_data )
            . "); new SKUs ready for put-away"
            . ($handler->prl_rollout_phase ? " preparation" : "")
            . "."
        );

        my $location = $handler->operator->operator_preference->printer_station_name;

        xt_warn("No Recodes printer defined in config") && return
            unless $location;

        foreach my $recode_id (@{$handler->{data}->{stock_recode_ids}}) {
            my $recode = XTracker::Document::Recode->new(
                recode => $recode_id
            );
            $recode->print_at_location($location);
        }
    }
    catch {
        my $error = $_;
        my $error_message;

        if(ref($error) eq 'NAP::XT::Exception::Recode::ThirdPartySkuRequired') {
            $error_message = sprintf('Please contact Service Desk as the SKU %s does not have a third-party-sku',
                $error->sku() );
        } else {
            $error_message = "$error";
        }

        xt_warn('An error occurred while '
            . ($recode_ok ? 'printing' : 'recoding')
            . ": $error_message"
        );
    };

    return undef;
}

sub _check_and_munge_sku_data {
    my ($handler, $args, $error_messages) = @_;
    return undef unless (defined($args->{quantity}) && $args->{quantity} > 0);

    my $variant_obj = $handler->schema->resultset('Public::Variant')->find_by_sku(
        $args->{sku}, {
            variant_type_id         => $VARIANT_TYPE__STOCK,
            dont_die_when_cant_find => 1,
        }
    );

    if (!$variant_obj) {
        push @$error_messages, sprintf('Could not find sku: %s', $args->{sku});
        return undef;
    }

    ## check that product has weight and storage type assigned to it
    my $product = $variant_obj->product();
    my $product_weight = $product->shipping_attribute->weight;
    my $product_storage_type = $product->storage_type_id;
    if (!$product_storage_type && $product_weight == 0){
        push @$error_messages, _create_product_error_message(
            $product->id(),
            $args->{sku},
            'storage type and weight'
        );
    }
    elsif (!$product_storage_type){
        push @$error_messages, _create_product_error_message(
            $product->id(),
            $args->{sku},
            'storage type'
        );
    }
    elsif ($product_weight == 0){
        push @$error_messages, _create_product_error_message(
            $product->id(),
            $args->{sku},
            'weight'
        );
    }

    return {
        variant => $variant_obj,
        quantity=> $args->{quantity},
    };
}

sub _create_product_error_message {
    my ($product_id, $sku, $key) = @_;

    my $error_uri = URI->new('/StockControl/Inventory/ProductDetails');
    $error_uri->query_form({
        product_id => $product_id,
    });
    my $error_link = sprintf(q{ <a href='%s' target='_blank'>%s</a> }, $error_uri, $sku);
    return sprintf('Please enter the %s to continue processing the recode for the following product(s) %s',
        $key, $error_link);
}

sub _create_notes {
    my ($data_ref, $rest_ref) = @_;

    my $notes;
    if ($rest_ref->{notes}) {
        # If notes are already supplied (should be created automatically by JavaScript)
        # then we can just use them
        $notes = $rest_ref->{notes};
    } else {
        # If not, then we'll have to generate some
        $notes = "Recode: to " . join(', ',
            map {
                $data_ref->{$_}{newsku}.'('. $data_ref->{$_}{newquantity}.')'
            } keys %{$data_ref}
        );
        $notes .= ' from ' . join( q{, },
            map {
                my $sku = ( split(m{-},$_,2) )[1];
                my $quantity = $rest_ref->{$_};
                "$sku($quantity)"
            } grep { m{destroy} } keys %{$rest_ref}
        );
        $notes .= q{.};
    }

    # If user has supplied some additional notes, then chuck those in too
    $notes .= " $rest_ref->{user_notes}" if ($rest_ref->{user_notes});

    return $notes;
}


1;
