package XTracker::Document::SmallSKULabel;

use NAP::policy 'class';

use MooseX::ClassAttribute;
use XTracker::XTemplate;

extends 'XTracker::Document';

=head1 NAME

XTracker::Document::SmallSKULabel - A class modelling small SKU label documents.

=head1 SYNOPSIS

    my $small_label = XTracker::Document::SmallSKULabel->new(
        size => $size,
        sku  => $sku,
    );
    $small_label->print_at_location($location, $copies);

=head1 ATTRIBUTES

=head2 printer_type : 'small_label'

=cut

sub build_printer_type { 'small_label' }

=head2 template_path

String representing the path to the template of
the label

=cut

has '+template_path' => (
    default => 'print/small_sku_label.tt',
);

=head2 size

=head2 sku

=cut

for my $attr ( qw/size sku/ ) {
    has $attr => ( is => 'ro', isa => 'Str', required => 1, );
}

=head1 METHODS

=head2 gather_data() : $data

This method is used to generate data that gets printed when you call
this class's parent method L<XTracker::Document::print_at_location>, don't call
it directly as it won't contain the number of copies.

=cut

sub gather_data {
    return { map { $_ => $_[0]->$_ } qw/copies size sku/ }
}

with qw{
    XTracker::Document::Role::CopiesInContent
    XTracker::Document::Role::TempFile
};
