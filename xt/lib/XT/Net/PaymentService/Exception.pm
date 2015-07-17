package XT::Net::PaymentService::Exception;

use NAP::policy "tt", 'exception';

has 'error' => (
    is       => 'ro',
    required => 1,
);

has '+message' => (
    is       => 'ro',
    isa      => 'Str',
    init_arg => undef,
    lazy     => 1,
    default  => sub { "[PaymentService Error] " . $_[0]->code
                                                . ' '
                                                . $_[0]->error },
);

has 'code' => (
    is       => 'ro',
    isa      => 'Int',
    init_arg => undef,
    lazy     => 1,
    default  => 0,
);
