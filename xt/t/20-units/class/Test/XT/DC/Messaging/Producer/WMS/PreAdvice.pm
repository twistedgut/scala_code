package Test::XT::DC::Messaging::Producer::WMS::PreAdvice;
use NAP::policy "tt", 'class', 'test';

BEGIN {
    extends 'NAP::Test::Class';
};

use XTracker::Config::Local 'config_var';
use XTracker::Database::PutawayPrep;

use Test::XT::Data::PutawayPrep;
use Test::XTracker::MessageQueue;

=head1 NAME

Test::XT::DC::Messaging::Producer::WMS::PreAdvice

=head1 METHODS

=cut

sub startup : Tests(startup) {
    my $self = shift;

    $self->{message_queue} = new_ok('Test::XTracker::MessageQueue');
}

=head1 test__transform

Currently only tests the 'C<client>' field.

=cut

sub test__transform :Tests {
    my ($self) = @_;

    my ($stock_process) = $self->_create_stock_process_and_product;
    my $expected_client_code = $stock_process->channel()->client()->get_client_code();

    my ($headers, $body) = $self->{message_queue}->transform(
        'XT::DC::Messaging::Producer::WMS::PreAdvice',
        { sp => $stock_process, }
    );
    note('Generated data for "pre_advice" message');
    is($body->{items}->[0]->{skus}->[0]->{client}, $expected_client_code,
        "Correct client code: $expected_client_code");
}

=head1 test_dimensions

Tests for the 'C<length>', 'C<width>', 'C<height>' and 'C<weight>' fields.

=cut

sub test_dimensions : Tests {
    my $self = shift;

    for (
        [ 'test all dimensions set' => {
            length => 1, width => 2, height => 3, weight => 4,
        } ],
        [ 'test no dimensions set'  => {
            length => undef, width => undef, height => undef, weight => undef,
        } ],
        [
            'test voucher pre_advice dimensions',
            { map { $_ => config_var('Voucher', $_) } qw/length width height/ },
            1,
        ],
    ) {
        my ( $test_name, $arg, $is_voucher ) = @$_;
        subtest $test_name => sub {
            my ( $stock_process, $product )
                = $self->_create_stock_process_and_product($is_voucher);
            $product->shipping_attribute->update({%$arg}) unless $is_voucher;

            my ($headers, $body) = $self->{message_queue}->transform(
                'XT::DC::Messaging::Producer::WMS::PreAdvice',
                { sp => $stock_process, }
            );

            for my $dimension ( sort keys %$arg ) {
                ok( exists $body->{items}[0]{$dimension},
                    "$dimension exists in message"
                ) or diag explain $body;
                my $got = $body->{items}[0]{$dimension};
                if ( defined $got ) {
                    cmp_ok( $got, q{==}, $arg->{$dimension},
                        "$dimension in message should match product's"
                    );
                }
                else {
                    is( $got, $arg->{$dimension}, "$dimension should be undef" );
                }
            }
        };
    }
}

sub _create_stock_process_and_product {
    my ( $self, $is_voucher ) = @_;
    my ( $stock_process, $product_data )
        = Test::XT::Data::PutawayPrep->new->create_product_and_stock_process(1, {
            voucher    => $is_voucher,
            group_type => XTracker::Database::PutawayPrep->name(),
        });
    return ( $stock_process, $product_data->{product} );
}
