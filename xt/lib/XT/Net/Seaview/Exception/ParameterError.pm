package XT::Net::Seaview::Exception::ParameterError;

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
    default  => sub { '[Seaview Parameter Error] ' . $_[0]->error },
);
