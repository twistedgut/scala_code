package XTracker::Stock::Actions::RTV::SetRequestRMA;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Utilities                 qw( url_encode );
use XTracker::Database::RTV             qw( :rtv_stock :rma_request update_fields );
use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    # grab search params from url so we can redirect back to same list
    my $select_product_id   = $handler->{param_of}{select_product_id} || '';
    my $select_designer_id  = $handler->{param_of}{select_designer_id} || '';
    my $select_channel      = $handler->{param_of}{select_channel} || '';

    my $redirect_type   = 'back';
    my %redirect_urls   = (
        back => "/RTV/RequestRMA?select_channel=$select_channel&select_product_id=$select_product_id&select_designer_id=$select_designer_id",
        rma  => "/RTV/ListRMA?submit_show_rma_email=1",
    );

    my $response;

    eval {

        my $schema = $handler->schema;
        my $dbh = $schema->storage->dbh;
        my $guard = $schema->txn_scope_guard;
        # fault type/description updated
        if ( $handler->{param_of}{'submit_update_fault_type'} ) {
                        my %args;

            foreach my $field ( keys %{ $handler->{param_of} } ) {

                my $rtv_quantity_id;
                my $fault_type;
                my $fault_desc;

                if ( ( $field =~ m/^(edit_ddl_item_fault_type_)(\d+)/ ) && ( $handler->{param_of}{$field} eq "on" ) ) {
                    $rtv_quantity_id = $2;
                    $fault_type      = $handler->{param_of}{'ddl_item_fault_type_'.$rtv_quantity_id} || 0;
                    $fault_desc      = $handler->{param_of}{'fault_description_'.$rtv_quantity_id} || '';

                    $args{$rtv_quantity_id} = { ddl_item_fault_type => $fault_type, fault_description => $fault_desc };
                }
            }

            _update_rtv_stock_data( $dbh, \%args );

            $response   = "Fault Type/Description updated successfully.";
        }
        # splitting an rtv quantity record
        elsif ( $handler->{param_of}{'submit_split_line'} ) {

            my $rtv_quantity_id;
            my $split_quantity;

            foreach my $field ( keys %{ $handler->{param_of} } ) {
                if ( $field =~ m/(^split_qty_)(\d+)/ ) {
                    $rtv_quantity_id    = $2;
                    $split_quantity     = $handler->{param_of}{$field};
                    last;
                }
            }

            ## split the line
            my $rtv_quantity_id_new = split_rtv_quantity(
                $dbh,
                {
                    rtv_quantity_id => $rtv_quantity_id,
                    split_quantity  => $split_quantity,
                }
            );

            $redirect_urls{back}    .= '&highlight_row_id='.$rtv_quantity_id_new;
            $response               = "Quantity split successfully.";

        }
        ## create an rma request
        elsif ( $handler->{param_of}{'submit_rma_request'} ) {

            ## create RMA Request
            my %rma_request_head = ( operator_id => $handler->{data}{operator_id}, comments => $handler->{param_of}{'rma_request_comments'}, channel_id => $handler->{param_of}{'channel_id'} );
            my %rma_request_dets = ();

            foreach my $field ( keys %{ $handler->{param_of} } ) {
                if ( $field =~ m/(^include_id_)(\d+)/ && $handler->{param_of}{$field} == 1 ) {
                    my $rtv_quantity_id    = $2;
                    $rma_request_dets{$rtv_quantity_id}{type_id} = $handler->{param_of}{'request_detail_type_'.$rtv_quantity_id};
                }
            }

            my $rma_request_id = create_rma_request({
                dbh      => $dbh,
                head_ref => \%rma_request_head,
                dets_ref => \%rma_request_dets,
            });

            $redirect_type      = 'rma';
            $redirect_urls{rma} .= '&rma_request_id='.$rma_request_id;
            $response           = "RMA request $rma_request_id was successfully created.";

        } ## END if

        $guard->commit();
        xt_success($response);

    };
    if ($@) {
        xt_warn("An error occured:<br />$@");
    }

    return $handler->redirect_to( $redirect_urls{ $redirect_type } );
}

sub _update_rtv_stock_data {
    my ( $dbh, $arg_ref)        = @_;

    ## map form fields to database fields for update
    my %form_db_fieldmap = (
        ddl_item_fault_type => 'fault_type_id',
        fault_description   => 'fault_description',
    );

    ## Update edited fault type & description
    foreach my $rtv_quantity_id ( keys %{$arg_ref} ) {

        my %update_fields = ();
        foreach my $form_field_name ( keys %form_db_fieldmap ) {

            my $db_field_name = $form_db_fieldmap{$form_field_name};

            if ( exists $arg_ref->{$rtv_quantity_id}{$form_field_name} ) {
                $update_fields{'rtv_quantity'}{$rtv_quantity_id}{$db_field_name} = $arg_ref->{$rtv_quantity_id}{$form_field_name};
            }

        } ## END foreach

        ## perform the update
        update_fields({
            dbh           => $dbh,
            update_fields => \%update_fields,
        });

    } ## END foreach

    return;

} ## END sub _update_rtv_stock_data

1;
