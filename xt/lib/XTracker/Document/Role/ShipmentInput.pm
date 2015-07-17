package XTracker::Document::Role::ShipmentInput;

use NAP::policy 'role';

use XT::Data::Types qw/ShipmentRow/;

use XTracker::Database;
use XTracker::XTemplate;

requires qw( gather_data template_path );

=head1 NAME

XTracker::Document::Role::ShipmentInput - Role that can be consumed in all document
classes that are based on the shipment object

=head1 DESCRIPTION

Given a C<$shipment_id> or <$shipment> it provides the shipment attribute
that it will be a DBIC object. Consumed in document classes, the attribute
will be used to provide all the data needed to build the document.
Required methods/attributes for this are C<gather_data>, which are defined
in the class that consumes the role and it collects all the data needed to
created the document. After we have the document data we will send it to
the template using C<template_path> which is a string representing the
path of the template
Current this role is used for:

=over 4

=item L<XTracker::Document::ReturnProforma>

=item L<XTracker::Document::OutwardProforma>

=back

=head1 SYNOPSIS

    # When creating your class
    package XTracker::Document::SomeClass

    extends 'XTracker::Document';
    with 'XTracker::Document::Role::ShipmentInput'

    ...
    # do stuff in document class
    ...

    # In the package where the document is printed

    my $document = XTracker::Document::SomeClass->new(shipment_id => $shipment_id);
    $document->print_at_location($location, $copies);


=head1 ATTRIBUTES

=head2 shipment

DBIC object representing the current shipment

=cut

has shipment => (
    is       => 'ro',
    isa      => ShipmentRow,
    required => 1
);


around BUILDARGS => sub {
    my ( $orig, $class, %args ) = @_;

    die 'Please define your object using only one of ' .
        'the shipment/shipment_id arguments'
        if ( $args{shipment} && $args{shipment_id} );

    if ( my $shipment_id = delete $args{shipment_id} ) {
        $args{shipment} = XTracker::Database::xtracker_schema
            ->resultset('Public::Shipment')
            ->find($shipment_id)
        or die "Couldn't find shipment with id $shipment_id";
    }

    $class->$orig(%args)
};

=head2 log_document

Log the printed file into DB

=cut

sub log_document {
    my ( $self, $printer_name ) = @_;

    my $shipment_log = $self->schema->resultset('Public::ShipmentPrintLog');

    $shipment_log->create({
        shipment_id  => $self->shipment->id,
        document     => $self->pretty_name,
        file         => $self->basename,
        printer_name => $printer_name,
    });
}
