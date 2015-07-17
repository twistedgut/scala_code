package XT::DC::Messaging::Consumer::VMSync;
use NAP::policy "tt", 'class';
use XTracker::Config::Local;
extends 'NAP::Messaging::Base::Consumer';
with 'NAP::Messaging::Role::WithModelAccess';
use XT::DC::Messaging::Spec::VMSync;

=head1 NAME

XT::DC::Messaging::Consumer::VMSync

=head1 DESCRIPTION

Consumer for VariantMeasurement updates.

=cut

sub routes {
    return {
        destination => {
            vmsync => {
                spec => XT::DC::Messaging::Spec::VMSync::vmsync(),
                code => \&vmsync,
            },
        },
    }
}

sub vmsync {
    my ( $self, $message ) = @_;

    my $variant_id = $message->{variant_id};

    my $schema = $self->model('Schema');
    my $variant = $self->model('Schema::Public::Variant')->find($variant_id);

    return 1 if (!$variant);

    my $product_id = $variant->product_id;

    die "Received PID $message->{product_id}, should have been $product_id"
        unless $product_id == $message->{product_id};

    my @set_measurements;

    $schema->txn_do(
        sub {
            for my $measure (@{$message->{measurements}}) {
                my $measurement_id = $measure->{measurement_id};
                my $value = $measure->{value};
                my $visible = $measure->{visible};

                # for this measurement, we may have no value, but we still
                # want to set the visibility
                if (length($value)) {
                    my $VariantMeasurement =
                        $self->model('Schema::Public::VariantMeasurement')
                            ->search({
                                variant_id => $variant_id,
                                measurement_id => $measurement_id,
                            });

                    $VariantMeasurement->update_or_create({
                        variant_id => $variant_id,
                        measurement_id => $measurement_id,
                        value          => $value,
                    });
                    push @set_measurements,$measurement_id;
                }

                my $product = $variant->product;
                if ($visible) {
                    $product->show_measurement($measurement_id);
                }
                else {
                    $product->hide_measurement($measurement_id);
                }
            }

            # remove non-mentioned measurements
            $self->model('Schema::Public::VariantMeasurement')
                ->search({
                    variant_id => $variant_id,
                    measurement_id => { '-not_in' => \@set_measurements }
                })->delete();
        });

    return;
}
