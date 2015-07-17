package NAP::XT::Exception::Stock::InvalidReturnReverse;
use NAP::policy "tt", 'exception';

=head1 NAME

NAP::XT::Exception::Stock::InvalidReturnReverse

=head1 DESCRIPTION

Exception thrown if an attempt is made to reverse a return item after it has been booked in

=cut

has '+message' => (
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return 'This return item has already be booked-in and therefore can not be reversed.',
    },
);
