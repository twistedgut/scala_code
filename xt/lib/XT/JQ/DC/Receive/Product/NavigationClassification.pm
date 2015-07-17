package XT::JQ::DC::Receive::Product::NavigationClassification;

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
            channel_id => Int,
            classification => Str,
            product_type => Str,
            sub_type => Str,
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

    my $dbh         = $self->dbh; # get transactional database handle
    my $schema      = $self->schema;
    my $channels    = $schema->resultset('Public::Channel')->get_channels();
    my $factory
        = XTracker::DB::Factory::ProductAttribute->new({ schema => $schema });

    my %web_dbhs;
    my $cant_talk_to_web = 0;

    # Navigation Classifications are now handled by fulcrum and AMQ
    return;
}

1;


=head1 NAME

XT::JQ::DC::Receive::Product::NavigationClassification - Bulk add navigation
categories to products

=head1 DESCRIPTION

This message is sent via the Fulcrum Send::Product::NavigationClassification when
products are bulk moved between categories

Expected Payload should look like:

ArrayRef[
    Dict[
        channel_id => Int,
        classification => Str,
        product_type => Str,
        sub_type => Str,
        product_ids => ArrayRef[Int],
    ],
],
