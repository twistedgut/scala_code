package XT::JQ::DC::Receive::Product::WearItWith;

use Moose;

use Data::Dump qw/pp/;

use Moose::Util::TypeConstraints;
use MooseX::Types::Moose                qw( Str Int ArrayRef );
use MooseX::Types::Structured           qw( Dict Optional );


use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker';

use XTracker::Constants::FromDB         qw( :recommended_product_type );
use XTracker::Database                  qw( get_database_handle );
use XTracker::Comms::FCP                qw( create_fcp_related_product delete_fcp_related_product );


has payload => (
    is => 'ro',
    isa => ArrayRef[
            Dict[
                action          => enum([qw/delete insert/]),
                # outfit_product is the MASTER product
                outfit_product  => Int,
                # 'product' is recommended to be worn with outfit_product
                product         => Int,
                channel_id      => Int,
                slot            => Optional[enum([1,2,3,4])],
                sort_order      => Optional[enum([1,2])],
            ],
        ],
    required => 1
);

# We want to help people out who try and update a product, that's part of a
# product upload, before that product has made it to the DC
sub max_retries { return 10 }
sub retry_delay { return 60 * 10 }

sub do_the_task {
    ## no critic(ProhibitDeepNests)
    my ($self, $job)    = @_;

    my %exceptions  = (
        'Deadlock' => 'retry'
    );

    my $recom_rs    = $self->schema->resultset('Public::RecommendedProduct');
    my $prdchann_rs = $self->schema->resultset('Public::ProductChannel');
    my $channels    = $self->schema->resultset('Public::Channel')->get_channels();

    my $cant_talk_to_web    = 0;

    my %web_dbhs;

    eval {
        $self->schema->txn_do( sub {
            foreach my $recommend ( @{ $self->payload } ) {

                my $ch_id = $recommend->{channel_id};

                # skip products on channels we dont have.
                next unless $channels->{$ch_id};

                my $main_prod  = $prdchann_rs->search({
                    channel_id => $ch_id,
                    product_id => $recommend->{outfit_product}
                    })->first or die "Product $recommend->{outfit_product} not found on channel $ch_id";
                my $recom_prod = $prdchann_rs->search({
                    channel_id => $ch_id,
                    product_id => $recommend->{product}
                    })->first or die "Product $recommend->{product} not found on channel $ch_id";

                if ( $recommend->{action} eq "insert" ) {

                    my $del_first_pid   = 0;

                    # check if the slot and sort order is free for the main product
                    my $slot_free   = $recom_rs->search( {
                        product_id  => $main_prod->product_id,
                        channel_id  => $ch_id,
                        type_id     => $RECOMMENDED_PRODUCT_TYPE__RECOMMENDATION,
                        sort_order  => $recommend->{sort_order},
                        slot        => $recommend->{slot}
                    } );

                    if ( $slot_free->count() ) {
                        # if the slot & sort order is not free but the
                        # recommended product matches with the job's one then
                        # there's no problem
                        if ( $slot_free->first->recommended_product_id == $recom_prod->product->id ) {
                            next;
                        }

                        my $clash   = $recom_rs->count( {
                                product_id  => $main_prod->product_id,
                                channel_id  => $ch_id,
                                type_id     => $RECOMMENDED_PRODUCT_TYPE__RECOMMENDATION,
                                recommended_product_id => $recom_prod->product->id
                            } );
                        # If the recommended product is in another slot for the
                        # outfit product then we have a problem
                        if ( $clash ) {
                            #die "ERROR: Slot & Sort Order Clash for Product " .
                            die "ERROR: Clash for Product " .
                                $recom_prod->product_id .
                                " is in a different slot for Outfit Product " .
                                $main_prod->product_id;
                        }

                        # If the recommended product DOES not exist in another slot
                        # then overwrite current slot's product by first deleting the
                        # existing one

                        # store the PID of the existing product to delete from the
                        # web-site first
                        $del_first_pid  = $slot_free->first->recommended_product_id;

                        $slot_free->first->delete;
                    }

                    my $rec = $recom_rs->create( {
                        product_id              => $main_prod->product_id,
                        channel_id              => $ch_id,
                        recommended_product_id  => $recom_prod->product_id,
                        type_id                 => $RECOMMENDED_PRODUCT_TYPE__RECOMMENDATION,
                        sort_order              => $recommend->{sort_order},
                        slot                    => $recommend->{slot}
                    } );

                    if ( $main_prod->live && $recom_prod->live ) {

                        unless ( $web_dbhs{$ch_id} ) {
                            my $web_dbh;
                            eval {
                                $web_dbh = get_database_handle( {
                                    name => 'Web_Live_'
                                            .$channels->{$ch_id}{config_section},
                                    type => 'transaction'
                                } );
                            };
                            if ( $@ || (!defined $web_dbh) ) {
                                $cant_talk_to_web   = 1;
                                die "Can't Talk to Web Site for Channel "
                                    .$ch_id." ("
                                    .$channels->{$ch_id}{config_section}
                                    .") - ".$@;
                            }
                            $web_dbhs{$ch_id} = $web_dbh;
                        }

                        if ( $del_first_pid ) {
                            delete_fcp_related_product( $web_dbhs{$ch_id}, {
                                product_id         => $main_prod->product_id,
                                related_product_id => $del_first_pid,
                                type_id            => "Recommended"
                            } );
                        }

                        create_fcp_related_product( $web_dbhs{$ch_id}, {
                            product_id          => $rec->product_id,
                            related_product_id  => $rec->recommended_product_id,
                            type_id             => "Recommended",
                            position            => $rec->slot,
                            sort_order          => $rec->sort_order
                        } );
                    }
                }

                if ( $recommend->{action} eq "delete" ) {
                    my $rec = $recom_rs->search( {
                        product_id             => $main_prod->product_id,
                        channel_id  => $ch_id,
                        recommended_product_id => $recom_prod->product_id,
                        type_id                => $RECOMMENDED_PRODUCT_TYPE__RECOMMENDATION,
                    })->first;

                    if ( $rec ) {
                        # Delete the product from our table
                        $rec->delete;

                        # And if the product made it to the PWS,
                        # delete it from there too
                        if ( $main_prod->live ) {

                            unless( $web_dbhs{$ch_id} ) {
                                my $web_dbh;
                                eval {
                                    $web_dbh = get_database_handle( {
                                        name => 'Web_Live_'
                                                .$channels->{$ch_id}{config_section},
                                        type => 'transaction'
                                    } );
                                };
                                if ( $@ || (!defined $web_dbh) ) {
                                    $cant_talk_to_web = 1;
                                    die "Can't Talk to Web Site for Channel "
                                        .$ch_id." ("
                                        .$channels->{$ch_id}{config_section}
                                        .") - ".$@;
                                }
                                $web_dbhs{$ch_id} = $web_dbh;
                            }

                            delete_fcp_related_product( $web_dbhs{$ch_id}, {
                                product_id         => $main_prod->product_id,
                                related_product_id => $recom_prod->product_id,
                                type_id            => "Recommended"
                            } );
                        }
                    }
                }

            }

            $web_dbhs{$_}->commit() foreach keys %web_dbhs;
            $job->completed;
        } );
    };
    if (my $e = $@) {
        #rollback & disconnect for the web
        $web_dbhs{$_}->rollback() for keys %web_dbhs;
        $web_dbhs{$_}->disconnect() for keys %web_dbhs;

        if ( !$cant_talk_to_web ) {
            my $action  = "die";
            foreach my $exception ( keys %exceptions ) {
                if ( $@ =~ /$exception/ ) {
                    $action = $exceptions{$exception};
                    last;
                }
            }

            $cant_talk_to_web   = 1     if ( $action eq "retry" );
        }

        if ( $cant_talk_to_web ) {
            # Non perm failue
            $job->failed( $e );
        }
        else {
            die $e
        }
    }
    else {
        # disconnect from the web
        $web_dbhs{$_}->disconnect() for keys %web_dbhs;
    }

    return ();
}

sub check_job_payload {

    my ( $self, $job )  = @_;

    my @errors = ();
    foreach my $recommend ( @{ $self->payload } ) {
        my $error   = "";

        if ( $recommend->{action} eq "insert" ) {
            if ( $recommend->{slot} !~ /^[1234]$/ ) {
                $error  = "Invalid Slot";
            }
            if ( $recommend->{sort_order} !~ /^[12]$/ ) {
                $error  .= ( $error ? ", " : "" ) . "Invalid Sort Order";
            }
        }
        if ( $error ) {
            push @errors, "ERROR in Payload for Product ".$recommend->{outfit_product}.": ".$error;
        }
    }

    return @errors;
}

1;

=head1 NAME

XT::JQ::DC::Receive::Product::WearItWith - Add/Delete a Recommended Product

=head1 DESCRIPTION

This message is sent via the Fulcrum Send::Product::WearItWith when a product
recommendation is set.

Expected Payload should look like:

[
    {
        action          => 'insert',
        outfit_product  => 122324,
        product         => 344666,
        slot            => 2,
        sort_order      => 1
    }
]
