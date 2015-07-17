package XTracker::Constants::Seaview;

use strict;
use warnings;
use base 'Exporter';

use Readonly;

Readonly our $SEAVIEW_FAILURE_MESSAGE__ACCOUNT_NOT_FOUND_FOR_URN     => 'Seaview account not found for URN';

our @SEAVIEW_FAILURE_MESSAGES = qw(
    $SEAVIEW_FAILURE_MESSAGE__ACCOUNT_NOT_FOUND_FOR_URN
);

our @EXPORT_OK = (
    @SEAVIEW_FAILURE_MESSAGES,
);

our %EXPORT_TAGS = (
    'seaview_failure_messages' => [@SEAVIEW_FAILURE_MESSAGES],
);

1;
