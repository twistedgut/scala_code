package XTracker::PrinterMatrix;

use NAP::policy "tt", 'class';

use Carp 'confess';
use List::MoreUtils 'uniq';
use Moose;

use XTracker::Database;
use XTracker::Error;
use XTracker::PrinterMatrix::PrinterList;

use XTracker::Printers;

with 'XTracker::Role::WithSchema';

=head1 NAME

XTracker::PrinterMatrix

=head1 DESCRIPTION

Class to handle printers

=head1 METHODS

=cut

=head2 printer_list

Returns a L<XTracker::PrinterMatrix::PrinterList> object.

=cut

has printer_list => (
    is       => 'ro',
    isa      => 'XTracker::PrinterMatrix::PrinterList',
    reader   => 'printer_list',
    init_arg => undef,
    builder => '_build_printer_list',
);

=head2 merged_printers

This is just a temporary attribute. It gets a list
of printer names formed of old and new printers.
REMOVE THIS WHEN ALL THE PRINTERS ARE PORTED

=cut

has merged_printers => (
    is       => 'ro',
    isa      => 'ArrayRef[Str]',
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_printers',
);

sub _build_printer_list {
    return XTracker::PrinterMatrix::PrinterList->new;
}

sub printer_names {
    my ( $self ) = @_;
    return $self->printer_list->order_by('name')->names;
}

=head2 get_printers_by_section($section, $channel_id) : \@stations

Return an arrayref of printer stations for the given C<$section> and
C<$channel_id>.

=cut

sub get_printers_by_section {
    my $self        = shift;
    my $section     = shift;
    my $channel_id  = shift;

    croak "No Sales Channel Id Passed" if !$channel_id;

    SMARTMATCH: {
        use experimental 'smartmatch';
        given ( $section ) {
            when ( 'StockIn' ) {
                confess 'Stock In printers have been ported to XTracker::Printers';
            }
            when ( 'Recode' ) {
                return [$self->locations_for_section('recode')];
            }
            when ( 'Packing' ) {
                croak join q{ },
                    q{Use get_printers_for_packing - sadly we can't use this},
                    q{method as the only place where this is called for 'Packing'},
                    q{the caller expect a resultset to be returned instead of an},
                    q{arrayref of station names};
            }
            default {
                return $self->schema->resultset('SystemConfig::ConfigGroupSetting')
                    ->config_var( "PrinterStationList$section", "printer_station", $channel_id )
                    //[];
            }
        }
    }

    warn "We shouldn't really get here... args were '$section' and '$channel_id'";
    return;
}

=head2 get_packing_printers() : $dbic_resultset|@dbic_rows

See the 'Packing' option in the get_printers_by_section method to see why this
exists.

=cut

sub get_packing_printers {
    my $self = shift;
    # Code moved here from XTracker::Order::Functions::Order::OrderView
    return $self->schema->resultset('SystemConfig::ConfigGroup')
        ->search({name => 'PackingPrinterList'})
        ->search_related( config_group_settings => {}, {order_by => 'setting'});
}

sub get_printer {
    my ($self, $op_pref, $setting, $printer_type) = @_;

    my $operator_printer= $op_pref->printer_station_name;
    $operator_printer   =~s/^(.*?)\s+$/$1/g;
    $operator_printer   =~s/\s/_/g;

    my $schema       = $self->schema;
    my $printer_id   = $schema->resultset('SystemConfig::ConfigGroup')->search({ name=>$operator_printer})->first->id;
    my $printer_name = $schema->resultset('SystemConfig::ConfigGroupSetting')->search({config_group_id=>$printer_id,setting=>$setting})->first->value;
    return $self->get_printer_by_name($printer_name);
}

=head2 locations_for_section( $section )

Return an ordered list of location names for the given section.

=cut

sub locations_for_section {
    my ( $self, $section ) = @_;

    return uniq $self->printer_list
                     ->search(section => $section)
                     ->order_by('location')
                     ->locations
    ;
}

=head2 printers_for_location( $location )

Return a set of printers that matches the given location.

=cut

sub printers_for_location {
    my ( $self, $location ) = @_;
    return $self->printer_list->search(location => $location);
}

=head2 get_printer_by_name

A method that returns a hash with printer data, e.g.:

    {
        lp_name          "goodsinBarcodeSmall", # hostname
        name             "Goods In Barcode - Small",
        print_language   "ZPL"
    }

=cut

sub get_printer_by_name {
    my $self         = shift;
    my $printer_name = shift;

    for my $attr (qw{name lp_name}) {
        my $printer = $self->printer_list
                           ->search($attr => $printer_name)
                           ->printers
                           ->[0];
        return $printer if $printer;
    }

    # FIXME - DJ: this really shouldn't be an xt_warn...
    xt_warn("No such printer: $printer_name");
}


=head2 _get_printers

Temporary method to get an array of old and new printers.
The method will die if all the printers are ported.
REMOVE this when the method dies

=cut

sub _build_printers {
    my $self = shift;
    # Get the old printers
    my @printers = $self->printer_names
        or die 'This attribute should not be used anymore!';

    # Add the new printers
    my %new_printers = (
        ItemCount      => 'item_count',
        QualityControl => 'goods_in_qc',
        Recode         => 'recode',
        ReturnsIn      => 'returns_in',
        ReturnsQC      => 'returns_qc',
        StockIn        => 'stock_in',
    );

    foreach my $printer_name ( keys %new_printers ) {
        push @printers, map { $_->name }
        XTracker::Printers->new->locations_for_section(
            $new_printers{$printer_name}
        );
    }

    return \@printers;
}

no Moose;
