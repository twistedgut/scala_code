package XTracker::WebContent::Roles::DetailStockFields;
use NAP::policy "tt", 'role';
require XTracker::Schema::Result::Public::VirtualProductSaleableQuantityDetails;
require XTracker::Schema::Result::Public::VirtualProductOrderedQuantityDetails;
use XTracker::Constants::FromDB ':flow_type';

requires 'schema';

has _field_map_cache => (
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1,
    traits => ['Hash'],
    handles => {
        _public_name_for => 'get',
        public_quantity_fields => 'values',
    },
);
sub _build__field_map_cache {
    my ($self) = @_;

    my @data =
        $self->schema->resultset('Flow::Status')->search({
            type_id => $FLOW_TYPE__STOCK_STATUS,
        },{
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
        })->all;
    my %ret;
    for my $status (@data) {
        my $input_col_name = XTracker::Schema::Result::Public::VirtualProductSaleableQuantityDetails::status_colname($status->{id});
        my $output_col_name = lc($status->{name});
        $output_col_name =~ s{\W+}{_}g;
        $ret{$input_col_name}="${output_col_name}_quantity";
    }
    for my $col (
        XTracker::Schema::Result::Public::VirtualProductSaleableQuantityDetails::non_status_columns(),
        XTracker::Schema::Result::Public::VirtualProductOrderedQuantityDetails::quantity_columns()) {
        $ret{$col} = $col;
    }
    return \%ret;
}

sub required_stock_detail_columns {
    my ($self) = @_;

    my %all_cols;@all_cols{$self->public_quantity_fields}=();

    delete @all_cols{$self->optional_stock_detail_columns()};

    return keys %all_cols;
}

sub optional_stock_detail_columns {
    my ($self) = @_;

    return XTracker::Schema::Result::Public::VirtualProductOrderedQuantityDetails::quantity_columns();
}
