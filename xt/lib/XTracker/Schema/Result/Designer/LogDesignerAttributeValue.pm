package XTracker::Schema::Result::Designer::LogDesignerAttributeValue;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class';
__PACKAGE__->load_components('InflateColumn::DateTime', 'Core');
__PACKAGE__->table("designer.log_attribute_value");


__PACKAGE__->add_columns(
    'id', {
        data_type       => 'integer',
        default_value   => q{nextval('designer.log_attribute_value_id_seq'::regclass)},
        is_nullable     => 0,
    },
    'attribute_value_id', {
        data_type       => 'integer',
        default_value   => undef,
        is_nullable     => 0,
    },
    'operator_id', {
        data_type       => 'integer',
        default_value   => undef,
        is_nullable     => 1,
    },
    'date', {
        data_type       => 'timestamp',
        default_value   => undef,
        is_nullable     => 0,
    },
    'action', {
        data_type       => 'varchar',
        default_value   => undef,
        is_nullable     => 0,
    },
);
__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(
    'attribute_value' => 'XTracker::Schema::Result::Designer::AttributeValue',
    { 'foreign.id' => 'self.attribute_value_id' },
);
__PACKAGE__->belongs_to(
    'operator' => 'XTracker::Schema::Result::Public::Operator',
    { 'foreign.id' => 'self.operator_id' },
);


# Make a new ResultSource based on class
my $source = __PACKAGE__->result_source_instance();
my $new_source = $source->new( $source );
$new_source->source_name( 'DesignerAttributeValueLog' );

# set up query - acts like a subselect after the FROM clause
$new_source->name( "
( select l.id, l.date, l.action, op.name as operator_name, attr.name as category, d.designer
        from designer.log_attribute_value l, operator op, designer.attribute_value av, designer d, designer.attribute attr
        where l.operator_id = op.id
        and l.attribute_value_id = av.id
        and av.attribute_id = attr.id
        and av.designer_id = d.id
        and l.date > ? )
");

# register new ResultSource with Schema
XTracker::Schema->register_extra_source( 'DesignerAttributeValueLog' => $new_source );

1;
