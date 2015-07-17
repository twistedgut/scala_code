package XTracker::Retail::Attribute::AJAX::UpdateAttribute;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Database qw( :common );
use XTracker::DB::Factory::ProductAttribute;

use XTracker::Comms::DataTransfer   qw(:transfer_handles);

use XTracker::Handler;
use XTracker::DBEncode  qw( encode_it );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $response        = '';       # response string

    # get update action from the form
    my $action          = $handler->{param_of}{'action'};

    # get sales channel id & channel config section from the form
    my $channel_id      = $handler->{param_of}{'channel_id'};
    my $channel_config  = $handler->{param_of}{'channel_config'};


    # action & channel defined
    if ( $action && $channel_id ) {

        # get schema and web transfer handles
        my $schema                      = $handler->{schema};           # get schema
        my $transfer_dbh_ref            = get_transfer_sink_handle({ environment => 'live', channel => $channel_config });      # get web transfer handle
        $transfer_dbh_ref->{dbh_source} = $schema->storage->dbh;                                                                # pass the schema handle in as the source for the transfer

        # get Product Attribute DB Factory object
        my $factory = XTracker::DB::Factory::ProductAttribute->new({ schema => $schema });


        eval {

            # create attribute
            if ( $action eq "create" ) {

                # type id and name required
                if ($handler->{param_of}{'type_id'} && $handler->{param_of}{'name'}) {

                    # transaction wraps XT and Website updates
                    $schema->txn_do( sub {
                        my $atrr_id = $factory->create_attribute( $handler->{param_of}{'name'}, $handler->{param_of}{'type_id'}, $channel_id, $transfer_dbh_ref );
                    } );

                }
                else {
                    die "ERROR: Could not create attribute - please provide type_id and name\n";
                }

            }

            # edit attribute
            elsif ( $action eq "edit" ) {

                # type id and name required
                if ($handler->{param_of}{'attribute_id'} && $handler->{param_of}{'name'}) {

                    # transaction wraps XT and Website updates
                    $schema->txn_do( sub {
                        my $atrr_id = $factory->update_attribute_simple( $handler->{param_of}{'attribute_id'}, $handler->{param_of}{'name'}, $handler->{param_of}{'type_id'}, $channel_id, $transfer_dbh_ref );
                    } );

                }
                else {
                    die "ERROR: Could not edit attribute - please provide attribute_id and name\n";
                }

            }

            # delete attribute
            elsif ( $action eq "delete" ) {

                # id required
                if ($handler->{param_of}{'attribute_id'}) {
                    my @pids;

                    $schema->txn_do( sub {

                        # get Attribute Details
                        my $attr_rec    = $schema->resultset('Product::Attribute')->find( $handler->{param_of}{'attribute_id'}, { join => 'type' } );

                        # get all attribute value entries for this attribute that havn't been deleted
                        my $attr_values = $schema->resultset('Product::AttributeValue')->search( {
                                                                            'attribute_id'  => $handler->{param_of}{'attribute_id'},
                                                                            'deleted'       => 0
                                                                        } );

                        # delete all attribute values for this attribute
                        while ( my $record = $attr_values->next ) {

                            $factory->remove_product_attribute( {
                                                            product_id      => $record->product_id,
                                                            attribute_id    => $record->attribute_id,
                                                            operator_id     => $handler->operator_id,
                                                            channel_id      => $attr_rec->channel_id,
                                                            transfer_dbh_ref=> $transfer_dbh_ref
                                                    } );

                            push @pids, $record->product_id;
                        }

                        $factory->delete_attribute( $handler->{param_of}{'attribute_id'}, $channel_id, $transfer_dbh_ref, $handler->operator_id );
                    } );

                }
                else {
                    die "ERROR: No attribute_id provided to delete\n";
                }
            }

            # update synonyms
            elsif ( $action eq "set_synonyms" ) {

                # id required
                if ($handler->{param_of}{'attribute_id'}) {
                    my $synonyms    = $handler->{param_of}{'synonyms'};

                    if ( !$synonyms ) {
                        $synonyms   = '';
                    }

                    $schema->txn_do( sub {
                        $factory->set_synonyms( $handler->{param_of}{'attribute_id'}, $synonyms, $transfer_dbh_ref );
                    } );

                }
                else {
                    die "ERROR: No attribute_id or synonyms provided\n";
                }
            }

            # update manual sort flag
            elsif ( $action eq "set_manual_sort" ) {

                # id and synonyms required
                if ($handler->{param_of}{'attribute_id'}) {

                    $schema->txn_do( sub {
                        $factory->set_manual_sort( $handler->{param_of}{'attribute_id'}, ($handler->{param_of}{'manual_sort'} || 0), $transfer_dbh_ref );
                    } );

                }
                else {
                    die "ERROR: No attribute_id or manual sort flag provided\n";
                }
            }

            else {
                die "ERROR: Unrecognised action - $action\n";
            }

            # commit website changes
            $transfer_dbh_ref->{dbh_sink}->commit();
        };

        if (my $err = $@ ) {
            # rollback website updates on error - XT updates rolled back as part of txn_do
            $transfer_dbh_ref->{dbh_sink}->rollback();

            $err    =~ s/[\r\n]//g;
            if ( $err =~ /Attribute already Exists in:/ ) {
                $err    =~ s/ at .*//;
                $err    =~ s/.*(Attribute)/' $1/;
                $err    = "ERROR: '" . $handler->{param_of}{'name'} . $err . ", you must delete this first or use a different name. Attribute not created.";
            }
            $response = $err;
        }
        else {
            $response = 'OK';
        }

        # disconnect website transfer handles
        $transfer_dbh_ref->{dbh_sink}->disconnect()     if $transfer_dbh_ref->{dbh_sink};

    }
    else {
        $response   = 'No action provided';
        $response   = 'No channel provided'     if ($action && !$channel_id);
    }

    # write out response
    $handler->{r}->content_type( 'text/plain' );
    $handler->{r}->print( encode_it($response) );

    return OK;
}

1;
