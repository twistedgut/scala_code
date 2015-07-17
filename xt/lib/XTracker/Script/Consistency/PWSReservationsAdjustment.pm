package XTracker::Script::Consistency::PWSReservationsAdjustment;

use NAP::policy "tt", 'class';

use Template;
use XTracker::Config::Local;
use XTracker::EmailFunctions;
use XTracker::WebContent::StockManagement;

extends 'XTracker::Script';
with 'XTracker::Script::Feature::Schema';

sub invoke {
    my ( $self, %opts ) = @_;

    my $verbose = !!$opts{verbose};

    my $schema = $self->schema;

    my $channel_rs = $schema->resultset('Public::Channel')
                            ->fulfilment_only(0)
                            ->enabled
                            ->search(undef, { order_by => 'me.id', });

    my %ttdata;
    for my $channel ( $channel_rs->all ) {

        $verbose && printf "Running stock adjustments on %s\n", $channel->name;

        my %fail;
        my $stock_manager = $channel->stock_manager;
        my $skip_next;
        try {
            my ( $rows, $errors )
                = $channel->generate_reservation_discrepancy_rows_to_insert( $stock_manager );
            $channel->refresh_reservation_consistency( @$rows );

            # If we have errors we haven't died on populate %fail with them
            for my $error ( @$errors ) {
                my ($pid,$sid) = ( $error->{sku} =~ m{^(\d+)-(\d+)$} );
                my @cols = ( qw{sku xt_quantity pws_quantity error} );
                @{$fail{$pid}{$sid}{$error->{customer_number}}}{@cols}
                    = @{$error}{@cols};
                $verbose && printf "SKU %s, PWS Customer %s: %s\n",
                    @{$error}{qw/sku customer_number error/};
            }
            $skip_next = 0;
        }
        catch {
            push @{$ttdata{channels}},
                { name => $channel->name, sc_error => $_, };
            $verbose && say "Error - skipping reservation adjustment for this channel: $_";
            $skip_next = 1;
        };
        next if $skip_next;

        my %success;
        my $reservation_consistencies = $channel->reservation_consistencies({
            reported => { q{>} => 2 }
        });
        for my $discrepancy ( $reservation_consistencies->all ) {
            my $variant = $discrepancy->variant;
            try {
                $discrepancy->adjust_discrepancy( $stock_manager );
                $success{$variant->product_id}{$variant->size_id}{$discrepancy->customer_number} = {
                    sku => $variant->sku,
                    xt_quantity => $discrepancy->xt_quantity,
                    pws_quantity => $discrepancy->web_quantity,
                };
                $verbose
                    && printf "Adjusted sku %s for customer %s from %d to %d\n",
                        $variant->sku,
                        $discrepancy->customer_number,
                        $discrepancy->web_quantity,
                        $discrepancy->xt_quantity;
            }
            catch {
                $fail{$variant->product_id}{$variant->size_id}{$discrepancy->customer_number} = {
                    sku => $variant->sku,
                    xt_quantity => $discrepancy->xt_quantity,
                    pws_quantity => $discrepancy->web_quantity,
                    error => $_,
                };
                $verbose && printf "Failed to adjust sku %s for customer %s: $_\n",
                    $variant->sku, $discrepancy->customer_number;
            };
        }
        $stock_manager->disconnect;
        push @{$ttdata{channels}}, {
            name => $channel->name,
            success => \%success,
            fail => \%fail
        } if @{[keys %success, keys %fail]};
    }
    $self->send_summary_email(\%ttdata, $verbose) if @{$ttdata{channels}||[]};
    $verbose && say 'DONE';
}

sub send_summary_email {
    my ( $self, $ttdata, $verbose ) = @_;
    my $email_template = q{};
    $email_template .= $_ while <DATA>;
    my $template = Template->new(POST_CHOMP => 1) or die Template->error;
    my $content = q{};
    $template->process( \$email_template, $ttdata, \$content )
        or die $template->error;

    my $to = XTracker::Config::Local::config_var('Email', 'pws_reservation_adjustment_email');
    $verbose && print "Sending email to $to\nContent is $content\n";

    return XTracker::EmailFunctions::send_email(
        XTracker::Config::Local::config_var('Email', 'xtracker_email'),
        q{}, # reply_to address
        $to,
        'Reservation Adjustment Summary',
        $content,
    );
}

__DATA__
Hello,

The reservation adjustment script has finished running.
[% FOR channel IN channels;
     IF channel.sc_error %]

The adjustments could not be performed on [% channel.name %]: [% channel.sc_error %]
[%   END;
     IF channel.fail.keys.size %]

The following adjustments failed on [% channel.name %]:

[%   FOR product_id IN channel.fail.keys.nsort;
       FOR size_id IN channel.fail.$product_id.keys.nsort;
         # Not sorting here as pws customer numbers can have non-numeric values
         FOR customer IN channel.fail.$product_id.$size_id.keys;
           details = channel.fail.$product_id.$size_id.$customer %]
    SKU [% details.sku %] - Customer [% customer %]: XT Quantity: [% details.xt_quantity %], PWS Quantity: [% details.pws_quantity %], Error: [% details.error %]
[%       END;
       END;
     END;
   END %]
[%   IF channel.success.keys.size %]

The following adjustments were successful on [% channel.name %]:

[%     FOR product_id IN channel.success.keys.nsort;
         FOR size_id IN channel.success.$product_id.keys.nsort;
           FOR customer IN channel.success.$product_id.$size_id.keys;
             details = channel.success.$product_id.$size_id.$customer %]
    SKU [% details.sku %] - Customer [% customer %]: Updated to [% details.xt_quantity %] (old quantity [% details.pws_quantity %])
[%         END;
         END;
       END;
     END;
   END %]
