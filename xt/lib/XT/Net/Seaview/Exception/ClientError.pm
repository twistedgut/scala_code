package XT::Net::Seaview::Exception::ClientError;

use NAP::policy "tt", 'exception';

has 'error' => (
    is       => 'ro',
    required => 1,
);

has '+message' => (
    default  => '[Seaview Client Error] %{code}s : %{error}s',
);

has 'code' => (
    is      => 'ro',
    isa     => 'Int',
    default => 999,
);
