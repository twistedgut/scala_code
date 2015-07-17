package Test::XT::Data::Manifest;

use NAP::policy "tt", 'class';

use FindBin::libs;

use Carp;

use Test::XT::Data::Manifest::Row;

=head1 NAME

Test::XT::Data::Manifest - A class that encapsulates manifest testing logic.

=head1 SYNOPSIS

    my $test_manifest = Test::XT::Data::Manifest->new($manifest_string)

    my $header          = $test_manifest->get_header_row;
    my $rows            = $test_manifest->rows;
    my $shipment_rows   = $test_manifest->get_rows_by_type('shipment');

=head1 METHODS

=cut

has _raw_manifest => (
    is => 'rw',
    isa => 'Str',
    init_arg => 'manifest',
);

=head2 rows() : \@rows

Returns an arrayref of objects extending Test::XT::Data::Manifest::Row.

=cut

has rows => (
    is => 'rw',
    isa => 'ArrayRef',
);

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    if ( @_ == 1 && !ref $_[0] ) {
        return $class->$orig( manifest => $_[0] );
    }
    else {
        return $class->$orig(@_);
    }
};

sub BUILD {
    my ( $self ) = @_;

    # Remove the end-of-string newline
    chomp ( my $raw_manifest = $self->_raw_manifest );

    $self->rows([map {
        Test::XT::Data::Manifest::Row->new_row($_)
    } split m{\n}, $raw_manifest]);

    Carp::confess 'All manifests must start with a header row'
        unless $self->rows->[0]->type eq 'header';

    Carp::confess 'Manifests can only ever have one header record'
        if scalar @{$self->get_rows_by_type('header')} > 1;
}

=head2 get_header_row() : Test::XT::Data::Manifest::Row::Header

Return the object directly as every manifest can only ever have one header row.

=cut

sub get_header_row { return shift->rows->[0]; }

=head2 get_rows_by_type( $type ) : \@rows

Return an arrayref of rows with the given type (where type is one of header,
piece, service or shipment).

=cut

sub get_rows_by_type {
    my ( $self, $type ) = @_;
    return [grep { $_->type eq $type } @{$self->rows}];
}

=head1 SEE ALSO

L<Test::XT::Data::Manifest::Row>
