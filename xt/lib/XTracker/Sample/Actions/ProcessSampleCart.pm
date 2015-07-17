package XTracker::Sample::Actions::ProcessSampleCart;

use strict;
use warnings;
use Carp;

use XTracker::Handler;
use XTracker::Constants::FromDB qw( :authorisation_level );
use XTracker::Database::SampleRequest qw( :SampleCart bookout_request list_sample_request_types );
use XTracker::Utilities qw( url_encode );
use XTracker::Error;

sub handler {

    my $handler = XTracker::Handler->new(
        shift,
        { dbh_type => q{transaction} }
    );

    if ( $handler->auth_level < $AUTHORISATION_LEVEL__OPERATOR ) {
        ## Redirect to Review Requests
        my $loc = "/Sample/ReviewRequests";
        return $handler->redirect_to( $loc );
    }

    my $action_status_msg = '';
    my $msg_suffix = '';
    my $request_id;
    my $request_reference = '';
    my $variant_info = '';

    my $error_msg = '';
    my $errors = 0;

    my $ret_url = '';
    my $ret_params = '';


    ## create request_type_code => request_type mapping hash
    my $sample_request_types_ref = list_sample_request_types( { dbh => $handler->{dbh} } );
    my %request_type = ();
    $request_type{ $_->{code} } = $_->{type} foreach @{$sample_request_types_ref};

    ## get operator request types
    my $operator_request_types_ref = get_operator_request_types( { dbh => $handler->{dbh}, operator_id => $handler->operator_id } );
    my @operator_request_codes = map { $_->{code} } grep { $_->{type} } @{$operator_request_types_ref};

    ## set default operator request type
    my $request_type_code = (defined $handler->{param_of}{request_type_code} && $handler->{param_of}{request_type_code}) ? $handler->{param_of}{request_type_code} : $operator_request_types_ref->[0]{code};
    my $request_type = $request_type{$request_type_code};


    eval {

      CASE: {
            ## get variant from product_id as necessary - selects variant which has stock in 'Sample Room' or 'Press Samples' or first variant if none.
            if ( $handler->{param_of}{product_id} && !$handler->{param_of}{variant_id} ) {
                $handler->{param_of}{variant_id} = select_variant( { dbh => $handler->{dbh}, type => 'product_id', id => $handler->{param_of}{product_id} } );
            }

            ## 'Add' button (i.e. add sku to cart)
            if ( exists($handler->{param_of}{'submit_add_sku.x'}) && $handler->{param_of}{txt_add_sku} && $handler->{param_of}{txt_add_qty_sku} ) {

                $handler->{param_of}{action} = 'add';
                $handler->{param_of}{variant_id} = select_variant({
                    dbh         => $handler->{dbh},
                    type        => 'sku',
                    id          => $handler->{param_of}{txt_add_sku},
                });

                if ( !$handler->{param_of}{variant_id} ) {
                    $error_msg = "Invalid sku: $handler->{param_of}{txt_add_sku}. Please ensure that this item exists in Sample Inventory!";
                    $errors = 1;
                }

                last CASE;
            }

            ## 'Add' button (i.e. add variant to cart from Inventory >> Overview - Product Overview block (i.e. not left nav))
            if ( ($handler->{param_of}{action} eq 'add_variant') && $handler->{param_of}{variant_id} && $handler->{param_of}{quantity} ) {

                $handler->{param_of}{action} = 'add';
                if ( $handler->{param_of}{location} eq 'Press Samples' && grep { m{\Aprs\z}xms } @operator_request_codes ) {
                    $request_type       = 'Press';
                    $request_type_code  = 'prs';
                }

                last CASE;
            }

            ## Submit button - Press Request
            if ( exists( $handler->{param_of}{submit_request_prs} ) ) {

                croak "You do not have permission to submit requests of types '$request_type'"
                    unless grep { m{\A$request_type_code\z} } @operator_request_codes;

                $request_id = create_sample_request_press(
                    $handler->{dbh},
                    {
                        operator_id     => $handler->operator_id,
                        request_type    => 'Press',
                        receiver_id     => $handler->{param_of}{receiver_id},
                        notes           => $handler->{param_of}{txta_notes},
                        address_ref     => {
                            first_name      => $handler->{param_of}{txt_first_name},
                            last_name       => $handler->{param_of}{txt_last_name},
                            address_line_1  => $handler->{param_of}{txt_address_line_1},
                            address_line_2  => $handler->{param_of}{txt_address_line_2}    || '',
                            address_line_3  => $handler->{param_of}{txt_address_line_3}    || '',
                            towncity        => $handler->{param_of}{txt_towncity}          || '',
                            county          => $handler->{param_of}{txt_county}            || '',
                            postcode        => $handler->{param_of}{txt_postcode},
                            country         => $handler->{param_of}{txt_country}           || '',
                        }
                    }
                );

                $msg_suffix = " with 'Awaiting Approval' Status!";

                last CASE;
            }

            ## Submit button - Editorial Request
            if ( exists( $handler->{param_of}{submit_request_cre} ) ) {

                croak "You do not have permission to submit requests of types '$request_type'"
                    unless grep { m{\A$request_type_code\z} } @operator_request_codes;
                $request_id = create_sample_request_creative(
                    $handler->{dbh},
                    {
                        operator_id     => $handler->operator_id,
                        request_type    => $request_type,
                        notes           => $handler->{param_of}{txta_notes},
                    }
                );

                $msg_suffix = " with 'Awaiting Approval' Status!";

                last CASE;
            }

            ## Submit button - Upload, Styling, Pre-Shoot or Slow-Seller Request
            if ( exists( $handler->{param_of}{submit_request_crx} ) ) {

                croak "You do not have permission to submit requests of types '$request_type'"
                    unless grep { m{\A$request_type_code\z} } @operator_request_codes;

                $request_id = create_sample_request_creative(
                    $handler->{dbh},
                    {
                        operator_id     => $handler->operator_id,
                        request_type    => $request_type,
                        notes           => $handler->{param_of}{txta_notes},
                    }
                );

                # commit sample request
                $handler->{dbh}->commit();

                # now try and approve all items requested
                eval {
                    bookout_request( $handler->{dbh}, { sample_request_id => $request_id, date_return_due => undef, operator_id => $handler->operator_id } );
                };
                if ( $@ ) {
                    # rollback any bookout requests made so far as all of the request has to be approved not part of it
                    $handler->{dbh}->rollback();

                    $msg_suffix = " with 'Awaiting Approval' Status!";
                }
                else {
                    $msg_suffix = " and Approved!";
                }

                last CASE;
            }
        };

        # if there have been no errors above then now see if items are being added or removed
        if (!$errors) {
            ## add or remove sample cart item as appropriate
            if ( lc($handler->{param_of}{action} // '' ) eq 'add' && ($handler->{param_of}{variant_id} // 0) ) {

                my $prod_channel_id = check_cart_channel_match($handler->{dbh},$handler->operator_id,$handler->{param_of}{variant_id});
                if ( !$prod_channel_id ) {
                    $error_msg = "Can't Add Item. Item's Sales Channel Can Not be used in this Cart.";
                    $errors = 1;
                }
                else {
                    $action_status_msg = "Item added to cart." if add_cart_item( { dbh => $handler->{dbh}, operator_id => $handler->operator_id, variant_id => $handler->{param_of}{variant_id}, channel_id => $prod_channel_id } );
                }
            }
            elsif ( lc($handler->{param_of}{action}) eq 'remove' && $handler->{param_of}{variant_id} ) {
                $action_status_msg = "Item removed from cart." if remove_cart_item( { dbh => $handler->{dbh}, operator_id => $handler->operator_id, variant_id => $handler->{param_of}{variant_id} } );
            }
        }
    };
    if ($@ || $errors) {
        $handler->{dbh}->rollback();

        $ret_url = "/Sample/SampleCart";
        $ret_params = "?request_type_code=".$request_type_code;
        xt_warn( $@ || $error_msg );
    }
    else {
        $handler->{dbh}->commit();

        if ($request_id) {
            $action_status_msg = "Request Reference @{[sprintf('%05d', $request_id)]} was Created".$msg_suffix;
            $ret_url = "/Sample/ReviewRequests";
            $ret_params = "?action=conf_request&request_id=$request_id;";
            xt_success($action_status_msg);
        }
        else {
            $ret_url = "/Sample/SampleCart";
            $ret_params = "?request_type_code=".$request_type_code;
            xt_success($action_status_msg);
        }
    }

    return $handler->redirect_to( $ret_url.$ret_params );
}

1;

__END__
