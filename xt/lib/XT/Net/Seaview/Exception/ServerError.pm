package XT::Net::Seaview::Exception::ServerError;

use NAP::policy "tt", 'exception';

has 'error' => (
    is       => 'ro',
    required => 1,
);

has '+message' => (
    default  => '[Seaview Server Error] %{code}s : %{error}s',
);

has 'code' => (
    is      => 'ro',
    isa     => 'Int',
    default => 999,
);
