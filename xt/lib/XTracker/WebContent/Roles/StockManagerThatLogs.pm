package XTracker::WebContent::Roles::StockManagerThatLogs;
use NAP::policy "tt", 'role';
use NAP::XT::Exception::MissingRequiredParameters;
use XTracker::Database::Product qw( product_present );

requires 'stock_update', 'schema', 'channel_id';

around 'stock_update' => sub {
    my ($orig, $self, %args) = @_;

    # Make sure we should be logging this
    my $log_update = (defined($args{log_update}) ? $args{log_update} : 1);

    # If we're skipping 'non_live' and the variant is not live, then we don't want
    # to log the update
    if ($log_update && $args{skip_non_live}) {

        # The caller wants us to check to see if the variant is live before logging
        my $dbh = $self->schema->storage->dbh;
        $log_update = 0 unless product_present($dbh, {
            type        => 'variant_id',
            id          => $args{variant_id},
            channel_id  => $self->channel_id(),
        });
    }

    # Ensure we have the parameters required to log
    if ($log_update) {
        for my $required_param (qw/
            variant_id
            quantity_change
            pws_action_id
        /) {
            NAP::XT::Exception::MissingRequiredParameters->throw({
                missing_parameters => [$required_param],
            }) unless defined($args{$required_param});
        }
    }

    $self->schema->txn_do(sub {
        # First do the stock_update
        $self->$orig(%args);

        # Now log it
        $self->schema->resultset('Public::LogPwsStock')->log_stock_change(
            variant_id      => $args{variant_id},
            channel_id      => $self->channel_id(),
            pws_action_id   => $args{pws_action_id},
            quantity        => $args{quantity_change},
            ($args{operator_id} ? (operator_id => $args{operator_id}) : ()),
            ($args{notes} ? (notes => $args{notes}) : ()),
        ) if $log_update;
    });

    return 1;
};
