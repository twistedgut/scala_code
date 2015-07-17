package XTracker::Constants::Ajax;

use strict;
use warnings;
use base 'Exporter';

use Readonly;

Readonly our $AJAX_MESSAGE__METHOD_NOT_SUPPORTED  => 'Method not supported';

our @AJAX_MESSAGES = qw(
    $AJAX_MESSAGE__METHOD_NOT_SUPPORTED
);

our @EXPORT_OK = (
    @AJAX_MESSAGES
);

our %EXPORT_TAGS = (
    'ajax_messages'      => [@AJAX_MESSAGES],
);

1;
