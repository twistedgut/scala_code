package Test::XTracker::Order::Functions::Return::AddItem;
use NAP::policy 'tt', 'test';
use parent 'NAP::Test::Class';

=head1 NAME

Test::XTracker::Order::Functions::Return::AddItem

=head1 DESCRIPTION

Test the L<XTracker::Order::Functions::Return::AddItem> class.

Extends L<NAP::Test::Class>.

=cut

use Test::XTracker::Mock::Handler;

=head1 STARTUP

Make sure the class being tested can be loaded OK.

=cut

sub test__startup : Test( startup => no_plan ) {
    my $self = shift;

    use_ok 'XTracker::Order::Functions::Return::AddItem';

}

=head1 TESTS

=head2 test__populate_return_items

Test the _populate_selected_return_items method populates the $handler->{data}{return_items}
HashRef with only selected return items.

=cut

sub test__populate_return_items : Tests {
    my $self = shift;

    can_ok( 'XTracker::Order::Functions::Return::AddItem'
        => '_populate_selected_return_items' );

    my %tests = (
        'None Selected' => {
            parameters => {
                $self->_build_return_item_parameter( 1, 0 ),
                $self->_build_return_item_parameter( 2, 0 ),
                $self->_build_return_item_parameter( 3, 0 ),
            },
            return_items => {},
        },
        'One Selected' => {
            parameters => {
                $self->_build_return_item_parameter( 4, 1 ),
                $self->_build_return_item_parameter( 5, 0 ),
                $self->_build_return_item_parameter( 6, 0 ),
            },
            return_items => {
                $self->_build_return_item_expected( 4, 1 ),
            },
        },
        'Two Selected' => {
            parameters => {
                $self->_build_return_item_parameter( 7, 1 ),
                $self->_build_return_item_parameter( 8, 1 ),
                $self->_build_return_item_parameter( 9, 0 ),
            },
            return_items => {
                $self->_build_return_item_expected( 7, 1 ),
                $self->_build_return_item_expected( 8, 1 ),
            },
        },
        'All Selected' => {
            parameters => {
                $self->_build_return_item_parameter( 10, 1 ),
                $self->_build_return_item_parameter( 11, 1 ),
                $self->_build_return_item_parameter( 12, 1 ),
            },
            return_items => {
                $self->_build_return_item_expected( 10, 1 ),
                $self->_build_return_item_expected( 11, 1 ),
                $self->_build_return_item_expected( 12, 1 ),
            },
        },
    );

    while ( my ( $name, $test ) = each %tests ) {

        subtest $name => sub {

            my $handler = Test::XTracker::Mock::Handler->new( {
                param_of => $test->{parameters}
            } );

            # Call the method.
            XTracker::Order::Functions::Return::AddItem::_populate_selected_return_items( $handler );

            ok( exists $handler->{data},
                'The key [data] exists in the [handler]' );

            ok( exists $handler->{data}->{return_items},
                'The key [return_items] exists in [data]' );

            cmp_deeply( $handler->{data}->{return_items},
                $test->{return_items},
                'The [return_items] are as expected' );

        }

    }

}

=head1 PRIVATE METHODS

=head2 _build_return_item_parameter( $id, $selected )

Return a HASH mocking the parameters the form would POST to the handler.

The HASH is as follows:

    'selected-<$id>'     => C<$selected>,
    'type-<$id>'         => 'Return',
    'exchange-<$id>'     => 'None/Unknown (33R)',
    'reason_id-<$id>'    => 'Just unsuitable',
    'full_refund-<$id>'  => 1,

=cut

sub _build_return_item_parameter {
    my ($self,  $id, $selected ) = @_;

    return (
        "selected-$id"      => $selected,
        "type-$id"          => 'Return',
        "exchange-$id"      => 'None/Unknown (33R)',
        "reason_id-$id"     => 'Just unsuitable',
        "full_refund-$id"   => 1,
    );

}

=head2 _build_return_item_expected( $id, $selected )

Return a HASH mocking what should be returned for an individual shipment item ID.

The HASH is as follows:

    C<$id> => {
        selected     => C<$selected>,
        type         => 'Return',
        exchange     => 'None/Unknown (33R)',
        reason_id    => 'Just unsuitable',
        full_refund  => 1,
    }

=cut

sub _build_return_item_expected {
    my ($self,  $id, $selected ) = @_;

    return (
        $id => {
            "selected"      => $selected,
            "type"          => 'Return',
            "exchange"      => 'None/Unknown (33R)',
            "reason_id"     => 'Just unsuitable',
            "full_refund"   => 1,
        },
    );

}
