package XT::Net::Seaview::Exception::NetworkError;

use NAP::policy "tt", 'exception';

has 'error' => (
    is       => 'ro',
    required => 1,
);

has '+message' => (
    default  => '[Seaview Network Error] %{error}s',
);
