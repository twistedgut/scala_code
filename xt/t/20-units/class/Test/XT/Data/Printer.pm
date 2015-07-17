package Test::XT::Data::Printer;

use NAP::policy "tt", qw/class test/;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::Printers';
};

use Data::UUID;
use XT::Data::Printer;

sub test_construction : Tests() {
    my $self = shift;
    for (
        [ 'valid basic' => $self->default_printer, 1 ],
        [ 'invalid section' => { %{$self->default_printer}, section => 'invalid section' }, 0 ],
        [ 'invalid type' => { %{$self->default_printer}, type => 'invalid type' }, 0 ],
    ) {
        my ( $test_name, $printer_hash, $should_live ) = @$_;
        if ( $should_live ) {
            lives_ok( sub { XT::Data::Printer->new($printer_hash); }, $test_name );
        }
        else {
            dies_ok( sub { XT::Data::Printer->new($printer_hash); }, $test_name );
        }
    }
}
