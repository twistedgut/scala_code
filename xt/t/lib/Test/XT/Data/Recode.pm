package Test::XT::Data::Recode;

use NAP::policy "tt";

use MooseX::Params::Validate qw/ validated_list /;
use Test::More;

use Test::XTracker::Data;
use XTracker::Database 'xtracker_schema';

=head2 create_recode

Adds an entry directly into the stock_recode table. Doesn't create any
historical data, so don't use this if you need transaction logs, etc
to be correct.

Required params:
    schema : XTracker::Schema

Optional params:
    recode_args : hashref of col=>value mappings for the stock_recode row

=cut

sub create_recode {
    my $class = shift;
    my ($recode_args) = validated_list(\@_,
        recode_args =>  { isa => 'HashRef', optional => 1 },
    );

    my $schema = xtracker_schema();

    $recode_args->{quantity}   //= 1;
    $recode_args->{complete}   //= 0;
    $recode_args->{notes}      //= 'Test recode';

    unless (defined $recode_args->{variant_id}) {
        my ($channel, $pids) = Test::XTracker::Data->grab_products({
            force_create      => 1,
        });
        $recode_args->{variant_id} = $pids->[0]->{variant}->id;
        note "Created variant ".$pids->[0]->{variant}->id
            ." (product ".$pids->[0]->{variant}->product_id.") for recode";
    }

    my $recode_row = $schema->resultset('Public::StockRecode')->create({
        %$recode_args
    });

    return $recode_row;
}


1;

