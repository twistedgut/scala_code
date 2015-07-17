package Test::XT::Data::Customer;

use NAP::policy "tt", qw( test role );
requires 'schema';


#
# Create a Customer
#
use XTracker::Config::Local;
use Test::XTracker::Data;

use DateTime;

use Log::Log4perl ':easy';
Log::Log4perl->easy_init({ level => $INFO });

use XTracker::Constants::FromDB qw(
    :customer_category
);

has customer => (
    is          => 'rw',
    lazy        => 1,
    builder     => '_set_customer',
);

has email => (
    is          => 'rw',
    lazy        => 1,
    builder     => '_set_email',
);

has account_urn => (
    is          => 'rw',
    default     => 'urn:nap:account:6da65c59-4bda-42f3-8dbc-6b00e2e2ba55',
);

# Create a Customer
#
sub _set_customer{
    my ($self) = @_;

    my $now         = DateTime->now;

    # get the maximum 'is_customer_number' (web customer number) and increase it
    # so we can have a unique customer number on the table
    my $is_customer_num = $self->schema
                                    ->resultset('Public::Customer')
                                        ->get_column('is_customer_number')
                                            ->max();
    $is_customer_num++;

    my $customer = $self->schema->resultset('Public::Customer')->create({
        is_customer_number      => $is_customer_num,
        title                   => 'Mr',
        first_name              => 'Joe',
        last_name               => 'Bloggs',
        email                   => $self->email,
        category_id             => $CUSTOMER_CATEGORY__NONE,
        created                 => $now,
        modified                => $now,
        telephone_1             => '0123 456789',
        telephone_2             => '',
        telephone_3             => '',
        group_id                => 1,
        ddu_terms_accepted      => 1,
        legacy_comment          => 'Leave behind side gate',
        credit_check            => $now,
        no_marketing_contact    => $now,
        no_signature_required   => 1,
        channel_id              => $self->channel->id,
        account_urn             => $self->account_urn,
    });

    note "Customer Created, ID/WebID: ".$customer->id."/".$customer->is_customer_number;
    return $customer;
}

# give a default Email Address
sub _set_email {
    return 'joe.bloggs@example.com';
}

1;
