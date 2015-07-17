package XT::JQ::DC::Receive::Product::ReportingClassification;

use Moose;

use Data::Dump qw/pp/;

use Moose::Util::TypeConstraints;
use MooseX::Types::Moose                qw( Str Int ArrayRef );
use MooseX::Types::Structured           qw( Dict );


use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker';

use XTracker::Constants             qw( :application );
use XTracker::Database::Attributes  qw( set_product );


has payload => (
    is  => 'ro',
    isa => ArrayRef[
        Dict[
            classification => Str,
            product_type   => Str,
            sub_type       => Str,
            product_ids    => ArrayRef[Int],
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
    my $factory     = XTracker::DB::Factory::ProductAttribute->new(
        { schema => $schema }
    );

    my $guard = $schema->txn_scope_guard;
    foreach my $set ( @{ $self->payload } ) {

        # find all classification attributes
        my $l1 = $schema->resultset('Public::Classification')->search(
            { 'classification' => $set->{classification} })->first
            or die "Can't find classification '".$set->{classification}."'";
        my $l2 = $schema->resultset('Public::ProductType')->search(
            { product_type => $set->{product_type} })->first
            or die "Can't find product type '".$set->{product_type}."'";
        my $l3 = $schema->resultset('Public::SubType')->search(
            { sub_type => $set->{sub_type} })->first
            or die "Can't find sub-type '".$set->{sub_type}."'";

        foreach my $pid ( @{ $set->{product_ids} } ){
            foreach my $field (qw(classification product_type sub_type)){
                set_product(
                    $schema->storage->dbh, $pid, $field, $set->{$field}, $APPLICATION_OPERATOR_ID
                );
            }
        }
    }
    # commit all the changes
    $guard->commit();
    return;
}

1;


=head1 NAME

XT::JQ::DC::Receive::Product::ReportingClassification - Bulk add reporting
categories to products

=head1 DESCRIPTION

This message is sent via the Fulcrum Send::Product::ReportingClassification when
products are bulk moved between categories

Expected Payload should look like:

ArrayRef[
    Dict[
        classification => Str,
        product_type => Str,
        sub_type => Str,
        product_ids => ArrayRef[Int],
    ],
],
