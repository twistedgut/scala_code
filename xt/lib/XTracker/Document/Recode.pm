package XTracker::Document::Recode;

use NAP::policy 'class';

use XTracker::Barcode qw{generate_png generate_file};
use XT::Data::Types qw(RecodeRow);

extends 'XTracker::Document';

=head1 NAME

XTracker::Document::Recode - Model recode document and prints it

=head1 DESCRIPTION

Given a C<$recode_id> it takes the recode associated to it and generates the
recode document.

=head1 SYNOPSIS

    my $document = XTracker::Document::Recode->new(recode => $recode_id);
    $document->print_at_location($location);

=head1 ATTRIBUTES

=head2 document_type

Represents the type of the document. In this case it is a static attribute

=cut

has document_type => (
    is       => 'ro',
    isa      => 'Str',
    init_arg => undef,
    default  => 'recode',
);


=head2 basename

Represents the basename of the filename. No extension
needed as this will be used to generate the temp folder
in which the document will be created

=cut

has basename => (
    is       => 'ro',
    isa      => 'Str',
    init_arg => undef,
    lazy     => 1,
    default  => sub {
        my $self = shift;

        return sprintf( 'recode-%s', $self->recode->id);
    }
);

=head2 template_path

String representing the path to the temaplate of
the document

=cut

has template_path => (
    is      => 'ro',
    isa     => 'Str',
    default => 'print/putaway_recode.tt'
);

=head2 printer_type : 'document'

=cut

sub build_printer_type { 'document' }


has recode => (
    is       => 'ro',
    isa      => RecodeRow,
    required => 1,
    coerce   => 1
);

=head2 gather_data

Gathers all the data needed, in a hashref, to build the recode

=cut

sub gather_data {
    my $self = shift;

    my $channel = $self->recode->variant->product->get_product_channel->channel;

    my $barcode_args = {
        font_size => 'small',
        scale     => 3,
        show_text => 1,
        height    => 65,
    };

    # Create our delivery barcode
    generate_file(
        File::Spec->catfile($self->directory, sprintf('recode-%i.png', $self->recode->id)),
        generate_png($self->recode->id, $barcode_args)
    );

    return {
        'recode'        => $self->recode,
        'variant'       => $self->recode->variant,
        'sales_channel' => $channel->name,
        'print_date'    => $self->schema->db_now->strftime("%d-%m-%Y %R")
    };
}


with qw{
    XTracker::Document::Role::Filename
    XTracker::Document::Role::PrintAsPDF
    XTracker::Document::Role::TempDir
    XTracker::Role::WithSchema
};
