package Test::XTracker::Schema::Result::Public::Business;
use NAP::policy "tt", 'class', 'test';

BEGIN { extends 'NAP::Test::Class'; };

sub test__does_refund_shipping :Tests {
    my ($self) = @_;

    my $business = $self->schema->resultset('Public::Business')->search({},{
        rows => 1
    })->first();
    my $does_refund_shipping = $business->does_refund_shipping();
    ok(($does_refund_shipping == 0 || $does_refund_shipping == 1),
       'does_refund_shipping() returns a valid value');
}
