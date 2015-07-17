package Test::XTracker::Document::UPSBoxLabel;

use NAP::policy qw/ class test /;

use Test::XT::Data;
use Test::File;
use Test::Fatal;
use MIME::Base64;

use XTracker::Printers::Populator;

use XTracker::Document::UPSBoxLabel;


BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::Printers';
};

sub startup :Tests(startup) {
    my ($self) = @_;

    $self->SUPER::startup;

    # ups label printers haven't been configured yet
    # so we need to add a suitable one here
    $self->new_printers_from_arrayref([{
        lp_name  => 'ups_label',
        location => 'ups_location',
        section  => 'packing',
        type     => 'ups_label',
    }])->populate_if_updated;
}

sub shutdown :Tests(shutdown) {
    my ($self) = @_;

    # Rebuild XT's printers using the configured source plugin
    XTracker::Printers::Populator->new->populate_if_updated;
    $self->SUPER::shutdown;
}

sub test__simple :Tests {
    my ($self) = @_;

    my $expected_type = 'ups_label';

    ## Create a two-box shipment
    my $box = $self->create_box;

    my @box_documents;

    for my $document_type (qw/ outward return /) {
        push @box_documents, XTracker::Document::UPSBoxLabel->new(
            document_type   => $document_type,
            box             => $box,
        );
    }

    for my $label (@box_documents) {
        is($label->printer_type, $expected_type,
            "Document uses the correct printer type");

        lives_ok( sub {
            $label->print_at_location($self->location_with_type($expected_type)->name);
        }, "Print document works ok");

        my $filename = $label->filename;

        file_exists_ok($filename, "Label file exists");
        file_not_empty_ok($filename, "Label file isn't empty");
    }
}

sub test__exceptions :Tests {
    my ($self) = @_;

    my $box = $self->create_box;

    like(
        exception {
            XTracker::Document::UPSBoxLabel->new(
            document_type   => 'stupid_document',
            box             => $box,
        )},
        qr{Attribute \(document_type\) does not pass the type constraint},
        "Can't instantiate with an invalid document type"
    );
}

sub create_box {
    my ($self) = @_;

    return $self->schema->resultset('Public::ShipmentBox')->new({
        id                      => "C987654321",
        outward_box_label_image => encode_base64("OUTWARD IMAGE DATA"),
        return_box_label_image  => encode_base64("OUTWARD IMAGE DATA"),
    });
}
