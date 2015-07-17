package Test::XTracker::Barcode;

use parent 'NAP::Test::Class';
use NAP::policy "tt", 'test';

use Test::XT::Data::Order;
use Test::Exception;

use XTracker::Barcode 'create_barcode';
use Test::XTracker::PrintDocs;

sub startup :Test(startup) {
    my ($self) = @_;
    $self->{order_factory} = Test::XT::Data->new_with_traits(
        traits => [ 'Test::XT::Data::Order' ]
    );
}

sub test_create_barcode_normal :Tests {
    my ($self) = @_;
    note("Testing normal height");
    lives_ok(
        sub { $self->_create_barcode(65) },
        'create_barcode normal height, runs without dying',
    );
}

sub test_create_barcode_auto_size :Tests {
    my ($self) = @_;
    note("Testing special value for auto-height");
    lives_ok(
        sub { $self->_create_barcode(0) },
        'create_barcode auto-height, runs without dying',
    );
}

sub test_create_barcode_default_height :Tests {
    my ($self) = @_;
    note("Testing undef = default height");
    lives_ok(
        sub { $self->_create_barcode() },
        'create_barcode default height, runs without dying',
    );
}

sub test_create_barcode_too_short :Tests {
    my ($self) = @_;
    note("Testing height is too short");
    throws_ok(
        sub { $self->_create_barcode(1) },
        qr/Image height 1 is too small for bar code/,
        'create_barcode too short height, throws an error as expected',
    );
}

sub _create_barcode :Tests {
    my ($self, $height) = @_;
    ok(
        create_barcode( @{ $self->_barcode_parameters($height) } ),
        'barcode written successfully',
    );
};

sub _barcode_parameters {
    my ($self, $height) = @_;

    my $shipment_data = $self->{order_factory}->new_order;
    my $order_number = $shipment_data->{order_object}->id;
    my $name = sprintf('giftmessagewarning%s', $order_number );
    my $filename = "$name.png"; # XTracker::Barcode uses same .png

    # Delete any existing file
    note("deleting any previous file at $filename");
    Test::XTracker::PrintDocs->new->delete_file($filename);

    return [
        $name,
        $order_number, # value
        'small', # font size
        3,       # scale
        1,       # show text at bottom
        $height,
    ];
}

