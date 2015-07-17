package XT::JQ::DC::Receive::Product::NavigationTag;

use Moose;

use Data::Dump qw/pp/;

use Moose::Util::TypeConstraints;
use MooseX::Types::Moose                qw( Str Int ArrayRef );
use MooseX::Types::Structured           qw( Dict );


use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker';

use XTracker::Constants             qw( :application );
use XTracker::DB::Factory::ProductAttribute;


has payload => (
    is  => 'ro',
    isa => ArrayRef[
        Dict[
            name        => Str,
            channel_id  => Int,
            action      => enum([qw/add delete/]),
            product_ids => ArrayRef[Int],
        ],
    ],
    required => 1,
);

# We want to help people out who try and update a product, that's part of a
# product upload, before that product has made it to the DC
sub max_retries { return 10 }
sub retry_delay { return 60 * 10 }

sub check_job_payload {
    return ();
}

sub do_the_task {
    my ($self, $job)    = @_;

    my $schema      = $self->schema;
    my $dbh         = $schema->storage->dbh;
    my $channels    = $schema->resultset('Public::Channel')->get_channels();
    my $factory     = XTracker::DB::Factory::ProductAttribute->new(
        { schema => $schema }
    );

    my %web_dbhs;
    my $cant_talk_to_web = 0;

    eval {
        my $guard = $schema->txn_scope_guard;
        foreach my $set ( @{ $self->payload } ) {

            my $cid = $set->{channel_id};
            next unless $channels->{$cid};

            # still need this because it is used by some functions
            $web_dbhs{$cid}->{dbh_source} = $self->dbh unless $web_dbhs{$cid};

            my $tag;
            if (!($tag = $schema->resultset('Product::Attribute')
                    ->search({
                        'me.name' => $set->{name},
                        'me.channel_id' => $cid,
                        'me.deleted'     => 0,
                        'type.name' => 'Hierarchy'
                    },
                    {
                        join => 'type'
                    })->first )) {
                        # Ignore this error has XT can no longer be kept in sync
                        warn "Can't find tag '".$set->{name} ."' on channel $cid to add/remove from product";
                        next;
            }

            foreach my $pid ( @{ $set->{product_ids} } ){
                my $pc = $schema->resultset('Public::ProductChannel')
                        ->search({channel_id => $cid, product_id => $pid})->first
                            or die "Product $pid not found on channel $cid";

                # add/remove tag
                if ($set->{action} eq 'delete'){
                    $factory->remove_product_attribute( {
                        attribute_id        => $tag->id,
                        product_id          => $pid,
                        transfer_dbh_ref    => $web_dbhs{$cid},
                        operator_id         => $APPLICATION_OPERATOR_ID,
                        channel_id          => $cid
                    });
                } elsif ($set->{action} eq 'add'){
                   $factory->create_product_attribute( {
                        attribute_id        => $tag->id,
                        product_id          => $pid,
                        transfer_dbh_ref    => $web_dbhs{$cid},
                        operator_id         => $APPLICATION_OPERATOR_ID,
                        channel_id          => $cid
                    });
                }
            }
        }
        # commit all the changes
        $guard->commit;
    };
    if (my $err = $@){
        my %exceptions  = (
            'Deadlock'      => 'retry'
        );

        my $action  = "die";
        foreach my $exception ( keys %exceptions ) {
            $action = $exceptions{$exception} if ( $err =~ /$exception/ )
        }
        if ( $action eq "retry" || $cant_talk_to_web ) {
            $job->failed( $err );
        }
        else {
            die $err;
        }
    }
    return;
}

1;


=head1 NAME

XT::JQ::DC::Receive::Product::NavigationTag - Bulk add/remove navigation tags
to/from products

=head1 DESCRIPTION

This message is sent via the Fulcrum Send::Product::NavigationTag when tags are
bulk added/removed

Expected Payload should look like:

ArrayRef[
    Dict[
        name        => Str,
        channel_id  => Int,
        action      => enum([qw/add delete/]),
        product_ids => ArrayRef[Int],
    ],
],
