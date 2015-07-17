package XTracker::Schema::Result::Any::Variant;
use NAP::policy "tt";

use base qw/DBIx::Class::Core/;

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');

__PACKAGE__->table('DUMMY_any_variant');
__PACKAGE__->result_source_instance->is_virtual(1);
__PACKAGE__->result_source_instance->view_definition(
    "SELECT 'This is a virtual class; see ::ResultSet::Any::Variant' AS message"
);
__PACKAGE__->add_columns(qw/message/);

1;
