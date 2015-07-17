package NAP::XT::Exception::EditPO::PurchaseOrderAlreadyEditable;
use NAP::policy "tt", 'exception';

=head1 NAME

NAP::XT::Exception::EditPO::PurchaseOrderAlreadyEditable

=head1 DESCRIPTION

Exception thrown if we are attempting to edit a purchase order in XT if it is
already editable in XT.

=cut

has '+message' => (
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return 'The purchase order is already editable in XT.',
    },
);
