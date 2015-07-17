package XTracker::PrinterMatrix::PrinterList;

use NAP::policy "tt", 'class';

use Carp;
use Moose;

use XTracker::Config::Local qw(
    get_config_sections
    config_section_slurp
    config_var
);

=head1 NAME

XTracker::PrinterMatrix::PrinterList

=head1 DESCRIPTION

Singleton class to return printer list

=head1 METHODS

=cut

=head2 printers

Return a list of printers that XTracker has access to.

=cut

has printers => (
    is => 'ro',
    isa => 'ArrayRef',
    init_arg => '_printers',
    builder => '_build_printers',
);

sub _build_printers {
    my $self = shift;
    my @printer_ids = get_config_sections('^(.+)_Printer');
    my @printers = map { config_section_slurp("${_}_Printer") } @printer_ids;

    return \@printers;
}

=head2 search( $attr => $str|qr/pattern/ )

Returns a filtered L<XTracker::PrinterMatrix::PrinterList> object.

=cut

sub search {
    my ( $self, $attr, $val ) = @_;
    croak "This method takes two arguments" unless 3 == @_;

    my $grep_expr = ref $val && ref $val eq 'Regexp'
                  ? sub { $_[0] && $_[0] =~ $val }
                  : sub { $_[0] && $_[0] eq $val };

    return __PACKAGE__->new(
        _printers => [
            grep { $grep_expr->( $_->{$attr}, $val ) } @{$self->printers}
        ]
    );
}

=head2 order_by( $attr )

Returns an alphabetically ascending ordered L<XTracker::PrinterMatrix::PrinterList>
object. Filters out any printers without the attribute we want to order by.

=cut

sub order_by {
    my ( $self, $attr ) = @_;
    croak "This method takes one argument" unless 2 == @_;
    return __PACKAGE__->new(
        _printers => [
            sort { $a->{$attr} cmp $b->{$attr} } grep { $_->{$attr} } @{$self->printers}
        ]
    );
}

=head2 names

Return a list of names for the printers.

=cut

sub names { shift->get_list_for('name'); }

=head2 locations

Return a list of locations for the printers.

=cut

sub locations { shift->get_list_for('location'); }

=head2 get_list_for( $attr )

Return the values for the given attribute.

=cut

sub get_list_for {
    my ( $self, $attr ) = @_;
    return map { $_->{$attr} } grep { $_->{$attr} } @{$self->printers};
}

=head2 count

Returns a count of the printers in this list.

=cut

sub count { return scalar @{shift->printers}; }

no Moose;
