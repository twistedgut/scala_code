package Test::XTracker::Schema::Result::Public::ShippingAttribute;
use NAP::policy "tt", qw/test class/;

BEGIN {
    extends 'NAP::Test::Class';
};

use Test::MockModule;

use Test::XTracker::Data;
use XTracker::Constants ':application';

=head1 NAME

Test::XTracker::Schema::Result::Public::ShippingAttribute

=head1 METHODS

=head2 test_add_volumetrics

Test the C<add_volumetrics> method by passing different combinations of
agruments.

=cut

sub test_add_volumetrics : Tests {
    my ($self) = @_;

    my $shipping_attribute = Test::XTracker::Data->grab_products({force_create => 1})
        ->[0]{product}->shipping_attribute;
    my $operator_id = $APPLICATION_OPERATOR_ID;
    # Set an operator id against the schema, so we know we can test it's being
    # stored too
    my $schema = $self->schema;
    $schema->operator_id($operator_id);
    for (
        [
            'Pass non-numeric volumetric weight',
            { length => undef, width => undef, height => undef },
            { length => 'invalid argument' },
            qr{invalid argument},
        ],
        [
            'Volumetric fields unset, input one dimension only',
            { length => undef, width => undef, height => undef },
            { length => 1 },
            qr{must all be either set or unset},
        ],
        [
            'Volumetric fields unset, input two dimensions',
            { length => undef, width => undef, height => undef },
            { length => 2, width => 2 },
            qr{must all be either set or unset},
        ],
        [
            'Volumetric fields set, unset one dimension',
            { length => 1, width => 1, height => 1 },
            { length => undef },
            qr{must all be either set or unset},
        ],
        [
            'Pass one dimension to round up',
            { length => 1, width => 1, height => 1 },
            { length => 1.9999 },
        ],
        [
            'Pass two dimensions to round down',
            { length => 1, width => 1, height => 1 },
            { length => 1.9994, width => 1.9994 },
        ],
        [
            'Volumetric fields unset, input all dimensions',
            { length => undef, width => undef, height => undef },
            { length => 2, width => 2, height => 2 },
        ],
        [
            'Volumetric fields set, input all dimensions',
            { length => 1, width => 1, height => 1 },
            { length => 2, width => 2, height => 2 },
        ],
        [
            'Volumetric fields set, unset all dimensions',
            { length => 1, width => 1, height => 1 },
            { length => undef, width => undef, height => undef },
        ],
        [
            'Volumetric fields set, attempt to pass a negative number',
            { length => 1, width => 1, height => 1 },
            { length => -1 },
            qr{The 'length' parameter},
        ],
    ) {
        my ( $test_name, $setup_data, $input, $error_message ) = @$_;
        $shipping_attribute->update($setup_data);
        if ( $error_message ) {
            throws_ok(
                sub { $shipping_attribute->add_volumetrics(%$input); },
                $error_message,
                $test_name,
            );
            next;
        }
        subtest $test_name => sub {
            my $pg_now = $schema->format_datetime($schema->db_now);
            lives_ok(
                sub { $shipping_attribute->add_volumetrics(%$input); },
                'add_volumetrics lives'
            );
            $shipping_attribute->discard_changes;
            for my $field ( sort keys %$input ) {
                # If the value has changed we need to test we logged
                if ( $setup_data->{$field}//0 != $input->{$field}//0 ) {
                    my @logs = $shipping_attribute->search_related(
                        'audit_recents',
                        { timestamp => { q{>} => $pg_now }, col_name => $field }
                    )->all;
                    is( @logs, 1, "$field should have logged once" );

                    # Test the columns we're interested in (note that
                    # table_schema, table_name and col_name are part of the
                    # join so we don't need to test them here)
                    for (
                        [ new_val     => $input->{$field}, ],
                        [ old_val     => $setup_data->{$field} ],
                        [ operator_id => $operator_id ],
                    ) {
                        my ( $col, $expected ) = @$_;
                        if ( defined $expected ) {
                            cmp_ok( $logs[0]->$col, q{==}, $expected,
                                "$col for $field should have logged correctly" );
                        }
                        else {
                            is( $logs[0]->$col, $expected,
                                "$col for $field should have logged correctly" );
                        }
                    }
                }

                # Check our field has been updated
                if ( defined $input->{$field} ) {
                    cmp_ok( $shipping_attribute->$field,
                        q{==}, sprintf('%.3f', $input->{$field}),
                        "$field stored correctly"
                    );
                }
                else {
                    is( $shipping_attribute->$field, $input->{$field},
                        "$field stored correctly" );
                }
            }
        };
    }
}
