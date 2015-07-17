package XTracker::Document::ReturnsLabel;

use NAP::policy 'class';

use File::Spec;

use XTracker::Database;
use XTracker::XTemplate;

extends 'XTracker::Document';

=head1 NAME

XTracker::Document::ReturnsLabel - Model returns label and prints it

=head1 DESCRIPTION

The returns label tamplate will contain the PSGI and the SKU

=head1 SYNOPSIS

    # You can create the ReturnsLabel object in two ways
    # First passing the stock process id as an argument
    # and it will be transformed into a StockProcess object

    my $returns_label = XTracker::Document::ReturnsLabel->new(
        stock_process_id => $stock_process_id,
    );

    # The second option is to pass the stock process object as an
    # argument. Be careful not to pass both stock_process_id and
    # stock_process object as arguments. Choose only one of them
    my $returns_label = XTracker::Document::ReturnsLabel->new(
        stock_process => $stock_process,
    );

    $returns_label->print_at_location($location);

=head1 ATTRIBUTES

=head2 printer_type : 'small_label'

=cut


sub build_printer_type {'small_label'}

=head2 template_path

String representing the path to the template of
the document

=cut

has '+template_path' => (
    default => 'print/returns_label.tt',
);

=head2 stock_process_id

=cut

has stock_process => (
    is       => 'ro',
    isa      => 'XTracker::Schema::Result::Public::StockProcess',
    required => 1,
);

around BUILDARGS => sub {
    my ( $orig, $class, %args ) = @_;

    die 'Please define your object using only one of '.
        'stock_process or stock_process_id attributes'
        if ( $args{stock_process} && $args{stock_process_id} );

    if ( my $sp_id = delete $args{stock_process_id} ) {
        $args{stock_process} = XTracker::Database::xtracker_schema
            ->resultset('Public::StockProcess')
            ->find( $sp_id )
        or die sprintf("Couldn't find stock process with id: %s", $sp_id);
    }

    $class->$orig(%args);
};

=head1 METHODS

=head2 gather_data(): $data

Generates data needed for returns label template

=cut

sub gather_data {
    my $self = shift;

    my $schema = $self->schema;
    my $dbh    = $schema->storage->dbh;
    my $stock_process = $self->stock_process;

    my %data;

    # Get all needed data
    $data{group_id} = ($self->iws_rollout_phase ? q{p-} : q{}) . $stock_process->group_id;

    my $variant = $stock_process->delivery_item
        ->link_delivery_item__return_item
        ->return_item
        ->variant;

    die sprintf(
        "Couldn't find variant for return item with id: %d",
        $stock_process->delivery_item->link_delivery_item__return_item->return_item_id
    ) unless $variant;

    $data{sku}  = $variant->sku;
    $data{type} = q{F} if ( $stock_process->is_faulty );

    return \%data;
}

=head2 filename

Return the filename for printing. This will write a lbl file.
TODO: this should be removed and use Filename role

=cut

sub filename {
    my $self = shift;

    my $content = $self->content;

    my $filename = File::Spec->catfile(
        $self->directory,
        sprintf('%s-%s.lbl', $self->printer_type, $self->stock_process->id)
    );

    open my $fh, '>', $filename
        or die "Couldn't open '$filename': $!\n";

    binmode $fh;
    print $fh $content;
    close $fh;

    return $filename;
}

with qw{
    XTracker::Document::Role::TempDir
    XTracker::Role::WithIWSRolloutPhase
    XTracker::Role::WithSchema
};
