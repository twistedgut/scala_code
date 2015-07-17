package Test::AssertRecords::Plugin::Shipping::Charge;
use Moose;
use Test::More 0.98;
use Data::Dump qw/pp/;
use Test::Differences;


with 'Test::AssertRecords::PluginBase';


sub make_record {
    my($self,$row) = @_;

    return {
        'sku'                   => $row->sku,
        'description'           => $row->description,
        'charge'                => $row->charge,
        'currency'              => (defined $row->currency_id)
            ? $row->currency->currency : undef,
        'channel'               => $row->channel->name,
        'account_number'        => (defined $row->account_id)
            ? $row->account->account_number : undef,
        'return_cutoff_days'    => (defined $row->account_id)
            ? $row->account->return_cutoff_days : undef,
        'option_name'           => (defined $row->option_id)
            ? $row->option->name : undef,
    };
}

sub test_assert {
    my($self,$schema,$data) = @_;

    my $charge_rs = $schema->resultset('Shipping::Charge');

    foreach my $rec (@{$data}) {
        my $zones = delete $rec->{zones};

        my $charge = $charge_rs->find_sku($rec->{sku});

        isa_ok($charge,'XTracker::Schema::Result::Shipping::Charge',
            'its a charge rec');

        is($charge->description,$rec->{description},"description matches");
        is($charge->charge,$rec->{charge},"charge matches");
        is($charge->currency->currency,$rec->{currency},"currency matches");
        is($charge->channel->name,$rec->{channel},"channel matches");
        is($charge->account->account_number,$rec->{account_number},
            "account number matches");
        is($charge->account->return_cutoff_days,$rec->{return_cutoff_days},
            "return_cutoff_days matches");
        is($charge->option->name,$rec->{option_name},"option name matches");
    }

}


1;
