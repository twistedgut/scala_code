package XT::DC::Messaging::Spec::PRL;
# Glue to get the NAP::DC::PRL::MessageSpec and its associated types
# in to XTracker
use strict;
use warnings;
use NAP::Messaging::Validator;
use NAP::DC::PRL::Type;
BEGIN { NAP::Messaging::Validator->add_type_plugins('NAP::DC::PRL::Type'); }
use parent 'NAP::DC::PRL::MessageSpec';

1;

