package XTracker::Stock::Actions::SetProductAttribute;

use strict;
use warnings;

use Scalar::Util 'looks_like_number';
use Try::Tiny;

use XTracker::Constants ':conversions';
use XTracker::Config::Local         qw( config_var );
use XTracker::Database::Attributes  qw(:update);
use XTracker::Database::Product     qw( validate_product_weight );
use XTracker::Handler;
use XTracker::Logfile               qw(xt_logger);
use XTracker::Utilities             qw(:edit :string);
use XTracker::Error;

sub handler {
    my $handler      = XTracker::Handler->new(shift);
    my $schema       = $handler->schema;
    my $logger       = xt_logger();
    my $product_id   = $handler->{param_of}{product_id};
    my $product      = $schema->resultset('Public::Product')->find($product_id);
    my $redirect_url = "/StockControl/Inventory/ProductDetails?product_id=$product_id";

    unless ( $product ) {
        my $voucher = $schema->resultset('Voucher::Product')->find($product_id);
        my $error_message
            = $voucher
            ? "This page doesn't support voucher changes"
            : "Could not find product (id $product_id)";
        xt_warn($error_message);
        return $handler->redirect_to($redirect_url);
    }
    eval {
        # hash to keep track of whats changed
        my %to_update = ();

        # loop over form post and get changes
        PARAM:
        foreach my $form_key ( keys %{ $handler->{param_of} } ) {
            if ( $form_key =~ m/edit\_(.*)/ && $handler->{param_of}{$form_key} eq 'on' ) {

                # if product weight appears to be incorrect - an exception is thrown
                validate_product_weight( product_weight => $handler->{param_of}{$1} ) if $1 eq 'weight';

                $to_update{ $1 } = $handler->{param_of}{ $1 };
            }
        }

        my $guard = $schema->txn_scope_guard;
        # update database
        _set_product_details($product, \%to_update, $handler->{data}{operator_id});

        ## create job to push attributes to Fulcrum
        # if anything required fields were set by user
        my $job_payload;

        if (defined $to_update{'country'}) {
            $job_payload->{'origin_country_id'} = $to_update{'country'};
        }
        if (defined $to_update{'weight'} and $to_update{weight} > 0 ) {
            $job_payload->{'weight'}        = $to_update{'weight'};
            $job_payload->{'weight_unit'}   = config_var('Units', 'weight');
        }
        if (defined $to_update{'fabric_content'}) {
            $job_payload->{'fabric_content'} = $to_update{'fabric_content'};
        }
        if (defined $to_update{'storage_type'}) {
            my $storage_type = $schema->resultset('Product::StorageType')->find({ id => $to_update{'storage_type'} });
            $job_payload->{'storage_type'} = $storage_type->name if $storage_type;
        }

        # create job if we have any updates
        if (keys %{$job_payload}){
            $job_payload->{product_id}  = $product_id;
            $job_payload->{operator_id} = $handler->{data}{operator_id};
            $job_payload->{from_dc}     = config_var('DistributionCentre', 'name');
            my $job = $handler->create_job( "Send::Product::ShippingData", $job_payload );
            $logger->debug('Creating Fulcrum job for Shipping Data, PID:'.$product_id);
        }

        # Updated OK, send message to IWS if some values have changed
        if ( grep { exists $to_update{$_} } qw/storage_type weight length width height/ ) {
            $product->discard_changes;
            # Tell IWS
            $handler->msg_factory->transform_and_send(
                'XT::DC::Messaging::Producer::WMS::PidUpdate',
                $product,
            );
        }
        # Tell PRLs if storage_type or weight has changed
        if ( $to_update{'storage_type'} || $to_update{'weight'} ) {
            $product->send_sku_update_to_prls({'amq'=>$handler->msg_factory});
        }

        $guard->commit();

        xt_success('Product attributes updated successfully.');
    };

    if($@){
        xt_warn("An error occurred whilst updating the product attributes:<br />$@");
    }

    return $handler->redirect_to( $redirect_url );
}

sub _set_product_details {
    my ($product, $data_ref, $operator_id) = @_;
    my $dbh     = $product->result_source->storage->dbh;

    # Volumetrics need to all values to be set at the same time due to check
    # constraints in the database, so we can't do the update in the loop below
    try {
        $product->add_volumetrics(
            map {
                my $val = $data_ref->{$_};
                # We need some additional validation here to prevent warnings
                # when users input invalid input... :/
                my $has_content = $val =~ m{\S};
                die "$_ should be a positive number\n"
                    if ($has_content && !looks_like_number($val));

                $_ => $has_content
                    ? $CONVERT{config_var(qw/Units dimensions/)}{cm}($val)
                    : undef;
            } grep { exists $data_ref->{$_} } qw/length width height/
        );
    }
    catch {
        if ( m{The '(.*)' parameter \("(.*)"\)} ) {
            die "Invalid value '$2' passed for parameter '$1'\n";
        }
        else { die "$_\n"; }
    };

    foreach my $item ( grep { not m{^(?:height|length|width)$} } keys %{$data_ref} ) {

        # product data
        if( $item eq 'hs_code' ){
            set_product( $dbh, $product->id, 'hs_code_id', $data_ref->{$item}, $operator_id );
        }
        elsif( $item eq 'storage_type' ){
            die("Product must have a storage type")
                unless $data_ref->{$item};
            set_product( $dbh, $product->id, 'storage_type_id', $data_ref->{$item}, $operator_id );
        }
        # shipping attribute data (default)
        else{

            if( $item eq 'fish_wildlife' || $item eq 'cites_restricted' ){
                if( !defined( $data_ref->{$item} ) ){ $data_ref->{$item} = 'F'; }
                else{ $data_ref->{$item} = 'T'; }
            }

            set_shipping_attribute(
                $dbh,
                $product->id,
                $item,
                $data_ref->{$item},
                $operator_id);
        }

    }

    return;
}

1;
