package XTracker::Script::Consistency::PWSStockAdjustment;
use NAP::policy "tt", 'class';

=head1 NAME

XTracker::Script::Consistency::PWSStockAdjustment

=head1 DESCRIPTION

Implements script that makes stock adjustments if it detects discrepancies between
the XT database and... err... somewhere else.

=cut

use Template;
use DateTime::Format::DateParse;
use XTracker::Config::Local;
use XTracker::Config::Parameters 'sys_param';
use XTracker::EmailFunctions;
use XTracker::WebContent::StockManagement;
use XTracker::Constants::FromDB qw(:shipment_type);
use File::stat;
use Time::Duration qw/ duration /;

extends 'XTracker::Script';
with 'XTracker::Script::Feature::Schema';
with 'XT::Data::Order::Import::Role::ManipulateOrderFiles';

use Readonly;
Readonly my $BACKLOG_CUTOFF => 59 * 60; # critical backlog in seconds

=head1 METHODS

=head2 invoke

Called to begin the stock check/adjust process

param - verbose : (Default=0) If set to 1, debug messages will be printed to STDOUT

=cut
sub invoke {
    my ( $self, %opts ) = @_;

    my $verbose = !!$opts{verbose};

    my $schema = $self->schema;

    my $channel_rs = $schema->resultset('Public::Channel')
                            ->fulfilment_only(0)
                            ->enabled
                            ->search(undef, { order_by => 'me.id', });

    my %pids_to_ignore = map { $_ => 1 }
        @{ sys_param('webconsistency/pids')//[] };

    my %ttdata;
    # go through each channel and check for differences
    foreach my $channel ( $channel_rs->all ) {

        my $backlog = $self->order_backlog($channel, $verbose);
        if (! $self->is_within_threshold($backlog)){
            # set error and move to next channel
            my $e_message = sprintf "Order import backlog of %s found. Skipping.",
                            duration($backlog, 2), $channel->name;
            $verbose && say $e_message;
            push @{$ttdata{channels}},
                { name => $channel->name, sc_error => $e_message };
            next;
        }

        $verbose && printf "No significant order import backlog found on %s\n", $channel->name;
        $verbose && printf "Running stock adjustments on %s\n", $channel->name;

        my %fail;
        my $stock_manager = $channel->stock_manager;
        # First we update the stock consistency table
        my $skip_next;
        try {
            my $pws_stock = $stock_manager->get_all_stock_levels;
            $stock_manager->disconnect;
            my ( $rows, $errors )
                = $channel->generate_stock_discrepancy_rows_to_insert( $pws_stock, \%pids_to_ignore );
            $channel->refresh_stock_consistency( @$rows );

            # If we have errors we haven't died on populate %fail with them
            for my $error ( @$errors ) {
                my ($pid,$sid) = ( $error->{sku} =~ m{^(\d+)-(\d+)$} );
                my @cols = ( qw{sku xt_quantity pws_quantity error} );
                @{$fail{$pid}{$sid}}{@cols} = @{$error}{@cols};
                $verbose && printf "%s: %s\n", @{$error}{qw/sku error/};
            }
            $skip_next = 0;
        }
        catch {
            push @{$ttdata{channels}},
                { name => $channel->name, sc_error => $_, };
            $verbose && say "Error - skipping stock adjustment for this channel: $_";
            $skip_next = 1;
        };
        next if $skip_next;

        ## create a new stock manager for the write operations
        $stock_manager = $channel->stock_manager;
        # Then we update any discrepancies we can...
        my %success;
        # Exclude stock that has been reported less than three times
        my $stock_consistencies = $channel->search_related('stock_consistencies', {
            reported => { q{>} => 2 },
        });
        for my $discrepancy ( $stock_consistencies->all ) {
            my $variant = $discrepancy->variant;
            next if $pids_to_ignore{$variant->product_id};
            try {
                $discrepancy->adjust_discrepancy({
                    stock_manager => $stock_manager,
                    notes => 'XTracker - Automated Stock Adjustment',
                });
                $success{$variant->product_id}{$variant->size_id} = {
                    sku => $variant->sku,
                    xt_quantity => $discrepancy->xt_quantity,
                    pws_quantity => $discrepancy->web_quantity,
                };
                $verbose && printf "Adjusted sku %s from %d to %d\n",
                    $variant->sku, $discrepancy->web_quantity, $discrepancy->xt_quantity;
            }
            catch {
                $fail{$variant->product_id}{$variant->size_id} = {
                    sku => $variant->sku,
                    xt_quantity => $discrepancy->xt_quantity,
                    pws_quantity => $discrepancy->web_quantity,
                    error => $_,
                };
                $verbose && printf "Failed to adjust sku %s: $_\n", $variant->sku;
            };
        }
        $stock_manager->disconnect;
        push @{$ttdata{channels}}, {
            name => $channel->name,
            success => \%success,
            fail => \%fail
        } if (keys %success or keys %fail);
    }
    # Finally, we only send an email if we have errors or changes to report
    $self->send_summary_email(\%ttdata, $verbose) if @{$ttdata{channels}||[]};
    $verbose && say 'DONE';
}

=head2 order_backlog

Will find the age of the oldest unimported order xml file for a channel

param - $channel : A Channel DBIC Result object for the channel to check
param - $verbose : As invoke()

return - $age_of_oldest_unimported_file : Age of the oldest order xml file (in seconds)

=cut
sub order_backlog {
    my ($self, $channel, $verbose) = @_;

    $verbose && printf "Checking order backlog on %s\n", $channel->name();
    my $age_of_oldest_unimported_file = 0;
    my $unimported_order_files = $self->get_unimported_order_file_paths($channel);

    for my $unimported_order_file (@$unimported_order_files) {
        my $file_age = abs(time() - stat($unimported_order_file)->mtime());
        $age_of_oldest_unimported_file = $file_age if $file_age > $age_of_oldest_unimported_file;
    }
    return $age_of_oldest_unimported_file;
}

=head2 send_summary_email

Generate and send a summary e-mail about the stock adjustments just performed

param - $ttdata : Data that will be passed to TemplateToolkit when generating the
    summary e-mail
param - $verbose : As invoke()

returns - As XTracker::EmailFunctions::send_email()

=cut
sub send_summary_email {
    my ( $self, $ttdata, $verbose ) = @_;
    my $email_template = q{};
    $email_template .= $_ while <DATA>;
    my $template = Template->new(POST_CHOMP => 1) or die Template->error;
    my $content = q{};
    $template->process( \$email_template, $ttdata, \$content )
        or die $template->error;

    my $to = XTracker::Config::Local::config_var('Email', 'pws_stock_adjustment_email');
    $verbose && print "Sending email to $to\nContent is $content\n";

    return XTracker::EmailFunctions::send_email(
        XTracker::Config::Local::config_var('Email', 'xtracker_email'),
        q{}, # reply_to address
        $to,
        'Stock Adjustment Summary',
        $content,
    );
}

=head2 is_within_threshold

Tests if a given age is within the maximum age threshold (in seconds) for an unimported
order xml file. Else an order-backlog should be declared for the channel

returns - $is_within_threshold : 1 if the file age is within the threshold, 0 if not

=cut
sub is_within_threshold {
    my ($self, $timestamp) = @_;
    return ($BACKLOG_CUTOFF > $timestamp ? 1 : 0);
}

__DATA__
Hello,

The stock adjustment script has finished running.
[% FOR channel IN channels;
     IF channel.sc_error %]

The adjustments could not be performed on [% channel.name %]: [% channel.sc_error %]
[%   END;
     IF channel.fail.keys.size %]

The following stock adjustments failed on [% channel.name %]:

[%   FOR product_id IN channel.fail.keys.nsort;
       FOR size_id IN channel.fail.$product_id.keys.nsort;
         details = channel.fail.$product_id.$size_id %]
    [% details.sku %]: XT Quantity: [% details.xt_quantity %], PWS Quantity: [% details.pws_quantity %], Error: [% details.error %]
[%     END;
     END;
   END %]
[%   IF channel.success.keys.size %]

The following stock adjustments were successful on [% channel.name %]:

[%     FOR product_id IN channel.success.keys.nsort;
         FOR size_id IN channel.success.$product_id.nsort;
           details = channel.success.$product_id.$size_id %]
    [% details.sku %]: Updated to [% details.xt_quantity %] (old quantity [% details.pws_quantity %])
[%       END;
       END;
     END;
   END %]
