package XTracker::Document::UPSBoxLabel;

use NAP::policy 'class';

use MIME::Base64;
use Moose::Util::TypeConstraints;

extends 'XTracker::Document';

=head1 NAME

XTracker::Document::UPSBoxLabel - Document class for UPS Box labels

=head1 ATTRIBUTES

=cut

sub build_printer_type { 'ups_label' }

=head2 box

Box record

=cut

has box => (
    is       => 'ro',
    isa      => 'XTracker::Schema::Result::Public::ShipmentBox',
    required => 1,
);

=head2 document_type

`outward` or `return`

=cut

has document_type => (
    is       => 'ro',
    isa      => enum([ qw\ outward return \ ]),
    required => 1,
);

=head2 basename

Required to fulfil XTracker::Document::Role::Filename

=cut

has basename => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    init_arg => undef,
    default  => sub {
        my ($self) = @_;
        return sprintf('%s-%s', $self->document_type, $self->box->id);
    },
);

=head2 content

Overrides the content method from XTracker::Document since the label
isn't printed via template

=cut

sub content {
    my ($self) = @_;

    my $caller_method = sprintf("%s_box_label_image", $self->document_type);

    my $label_image = decode_base64($self->box->$caller_method);

    return $label_image;
}


with qw\
    XTracker::Document::Role::Filename
    XTracker::Document::Role::TempDir
\;
