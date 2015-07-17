package NAP::XT::Exception::Stock::RTVQuantityMove;
use NAP::policy "tt", 'exception';

=head1 NAME

NAP::XT::Exception::Stock::RTVQuantityMove

=head1 DESCRIPTION

Exception thrown if an attempt is made to move stock that has been marked for 'Return To Vendor'

=cut

has '+message' => (
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return 'This movement cannot be completed, as there is a pending pick for the RTV SKU.',
    },
);
