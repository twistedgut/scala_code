package Test::XTracker::Printers::Populator;

use NAP::policy qw/class test/;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::Printers';
}

use XT::Data::Printer;

=head1 NAME

Test::XTracker::Printers::Populator

=cut

sub test_populate_db : Tests {
    my $self = shift;

    my $schema = $self->schema;
    my $printer_rs = $schema->resultset('Printer::Printer');
    for (
        [ 'valid printer' => 1, [ $self->default_printer ]],
        [ 'different printer types in one location' => 1, [
            $self->default_printer,
            { %{$self->default_printer}, type => [(sort keys %XT::Data::Printer::type_name)]->[1] },
        ]],
        [ 'duplicate type at same location' => 0, [
            { %{$self->default_printer}, location => 'location', },
            { %{$self->default_printer}, location => 'location', },
        ]],,
    ) {
        my ( $test_name, $should_live, $printer_ref ) = @$_;

        subtest $test_name => sub {
            my %printer_lp_name = map { $_->{lp_name} => $_ } @$printer_ref;
            $self->schema->txn_dont(sub{
                my $xpp = $self->new_printers_from_arrayref($printer_ref);
                unless ( $should_live ) {
                    throws_ok( sub { $xpp->populate_db },
                        qr{Duplicate definition of type},
                        "should error populating db" );
                    return;
                }

                lives_ok( sub { $xpp->populate_db }, "shouldn't die populating db" );

                for my $printer (
                    $schema->resultset('Printer::Printer')
                        ->search(undef, {
                            order_by => 'me.id',
                            prefetch => [ 'type', { location => 'section' }, ],
                        })->all
                ) {
                    subtest sprintf('printer %s', $printer->lp_name) => sub {
                        $self->printer_properties_test(
                            $printer, $printer_lp_name{$printer->lp_name}
                        );
                    };
                }
            });
        };
    }
}

sub printer_properties_test {
    my ( $self, $printer, $expected_ref ) = @_;
    my %field_got = (
        lp_name  => $printer->lp_name,
        type     => $printer->type->name,
        location => $printer->location->name,
        section  => $printer->location->section->name,
    );
    while ( my ( $field, $got ) = each %field_got ) {
        is( $got, $expected_ref->{$field}, "$field ($expected_ref->{$field}) ok" );
    }
}

sub test_populate_if_updated : Tests {
    my $self = shift;

    my @printer_lists = (
        [
            $self->default_printer,
            {
                %{$self->default_printer},
                section => ${XT::Data::Printer::sections}->[1],
            },
        ],
        [
            $self->default_printer,
            {
                %{$self->default_printer},
                section => ${XT::Data::Printer::sections}->[2],
            },
        ],
    );
    my $schema = $self->schema;
    $schema->txn_dont(sub{
        ok( $schema->resultset('Public::RuntimeProperty')
                ->find({name => 'printer_digest'})
                ->update({value => q{}}),
            'printer digest reset to an empty string'
        );
        ok( $self->new_printers_from_arrayref($printer_lists[0])->populate_if_updated,
            'populate_if_updated populates the db when the digest is empty' );
        ok( !$self->new_printers_from_arrayref($printer_lists[0])->populate_if_updated,
            'populate_if_updated does nothing when the same printer list is passed' );
        ok( $self->new_printers_from_arrayref($printer_lists[1])->populate_if_updated,
            'populate_if_updated populates the db when a different printer list is passed' );
    });
}
