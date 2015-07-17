package XTracker::Stock::Actions::SetMeasurement;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Utilities;
use XTracker::PrintFunctions;
use XTracker::Database qw( :common );
use XTracker::Database::StockProcess;
use XTracker::Database::Stock;
use XTracker::Database::Product qw( product_present );
use XTracker::Database::Attributes  qw(:update);
use XTracker::Comms::DataTransfer   qw(:transfer_handles :transfer);
use XTracker::Database::Channel qw(get_channel_details);

use XTracker::Error;
use XTracker::Logfile qw(xt_logger);
use XTracker::DBEncode qw( encode_it );
use DateTime;
use Try::Tiny;

sub handler {
    my $r           = shift;

    my $handler  = XTracker::Handler->new($r);
    my $schema   = $handler->schema;
    my $dbh_xt   = $schema->storage->dbh;

    my $logger = xt_logger(__PACKAGE__);

    # get form data
    my %postdata = %{ ($handler->{param_of}||{}) };

    # initialize structure to hold data to be sent via AMQ
    my %variants_to_sync;

    # form submitted
    if ( keys %postdata ) {

        # product id and use measurement flag - indicates if measurements should be used on website so create size chart
        my $prod_id = $postdata{'prodid'};
        my $channel = $postdata{'channel'};

        my $guard = $schema->txn_scope_guard;
        # get config section for channel
        my $channel_details = get_channel_details($dbh_xt, $channel);


        # web transfer handles
        my $transfer_dbh_ref = get_transfer_sink_handle({ environment => 'live', channel => $channel_details->{config_section} });
        $transfer_dbh_ref->{dbh_source} = $dbh_xt;

        # do stuff
        eval{
            my %unique_measurement;

            my $product = $schema->resultset('Public::Product')->find($prod_id)
                or die "Couldn't find product $prod_id";
            # actual product measurements
            foreach my $item ( keys %postdata ) {
                my $date = DateTime->now();
                my $variant;
                # form field matches measurement format
                if ($item =~ m/-/) {

                    # get action, variant id and measurement type from field name
                    my ( $action, $variant_id, $measurement ) = split /-/, $item;

                    # clean
                    eval {
                        $postdata{$item} = clean_measurement($postdata{$item});
                    };
                    if ( my $error = $@ ) {
                        my $loc = q{/StockControl/Measurement/Edit?product_id=}.$postdata{prodid};
                        xt_warn("You entered bad data: ". $error);
                        return $handler->redirect_to( $loc );
                    }

                    # The reason why we are not also checking $postdata{$item} >= 0 as we used to before,
                    # is related with giving the user the possibility of clearing out the fields if they so desire.
                    # As we are not checking the updated form values Vs the DB we have to set them all
                    if ( $action eq 'measure' && $variant_id && $measurement ) {
                        $variant = $schema->resultset('Public::Variant')->find( $variant_id );
                        my $variant_notes_delta = DBIx::Class::Row::Delta->new({
                            dbic_row => $variant,
                            changes_sub => sub{
                                my ($row) = @_;
                                my %hash = map {
                                    $_->measurement->measurement => $_->value
                                } $row->variant_measurements->all;
                                return \%hash;
                            }
                        });
                        # update measurement
                        set_measurement($dbh_xt, $measurement, $variant_id, $postdata{$item});

                        # get mesurement id's and cache them in a hash for later usage
                        unless (exists $unique_measurement{$measurement}) {
                            my $measurement_id = $schema->resultset('Public::Measurement')->find({
                            measurement => $measurement,
                            })->id;

                            $unique_measurement{$measurement} = $measurement_id;
                        }
                        if(my $changes = $variant_notes_delta->changes) {
                           $variant->create_related('variant_measurements_logs', {
                               operator_id => $handler->operator_id,
                               note        => $changes,
                               date        => $date,
                           });
                        }


                        $variants_to_sync{$variant_id} = 1;
                    }
                }
                if ($item =~ /^on_website/) {
                    # Hide measurement on website
                    if ( $postdata{$item} =~ /^hide_(\d+)$/ ) {
                        $product->hide_measurement($1);
                    }
                    # Show measurement on website
                    elsif ( $postdata{$item} =~ /show_(\d+)$/ ) {
                        $product->show_measurement($1);
                    }
                }
            }

            # check if product is live for website updates
            my $is_live = 0;
            if ( product_present( $dbh_xt, { type => 'product_id', id => $prod_id, channel_id => $channel_details->{id} } ) ) {
                $is_live = 1;
            }


            # update live site if product uploaded
            if ( $is_live ) {

                # array of attributes to be updated on the website
                my @attributes = ('SIZE_CHART_CM', 'SIZE_CHART_INCHES');

                # transfer to website
                transfer_product_data({
                    dbh_ref             => $transfer_dbh_ref,
                    product_ids         => $prod_id,
                    channel_id          => $channel_details->{id},
                    transfer_categories => 'catalogue_attribute',
                    attributes          => \@attributes,
                    sql_action_ref      => { catalogue_attribute => {'insert' => 1, 'update' => 1, 'delete' => 0 } },
                });

                my @fields = ('size_fit');

                transfer_product_data({
                    dbh_ref             => $transfer_dbh_ref,
                    product_ids         => $prod_id,
                    channel_id          => $channel_details->{id},
                    transfer_categories => 'catalogue_product',
                    attributes          => \@fields,
                    sql_action_ref      => { catalogue_attribute => {'insert' => 1, 'update' => 1, 'delete' => 0 } },
                });
            }

            $guard->commit();
            $transfer_dbh_ref->{dbh_sink}->commit();
        };

        if ( my $error = $@ ) {
        $logger->fatal($error);
            $transfer_dbh_ref->{dbh_sink}->rollback();

            $r->print(encode_it($error));

            $transfer_dbh_ref->{dbh_sink}->disconnect();

            return OK;
        }

        $transfer_dbh_ref->{dbh_sink}->disconnect();
    }


    # Let's try to send a message to all the other DCs flagging the
    # Measurement update
    try {
        $handler->msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::Sync::VariantMeasurement',
            {
                variants => [ keys %variants_to_sync ],
                schema => $schema,
            },
        );
    } catch {
        $logger->warn($_);
    };

    # redirect to Edit Measurement Page
    my $loc = q{/StockControl/Measurement/Edit?product_id=}.$postdata{prodid};
    return $handler->redirect_to( $loc );
}

1;

__END__

