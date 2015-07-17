package XTracker::Constants::Regex;

use strict;
use warnings;
use base 'Exporter';

use Readonly;

# N.B. These regexes assume postcodes have already been upcased and had whitespace stripped
# see http://www.govtalk.gov.uk/gdsc/html/frames/PostCode.htm for formal definition of UK postcode
# For simplicities sake, our regex is a little less restrictive than the official one.

# Each key in the $POSTCODE_REGEX hash is the two-letter ISO country code for the country
# the regex applies to. The values are another hashref, with the following keys:
#   expression : The regex used to validate the postcodes from this country
#   matcher_at : Identifies the matched part of a validated postcode that should be used
#       for further analysis and checks (this is not always the entire postcode)

Readonly our $POSTCODE_REGEX => do { Readonly my %h   => (
    US      => {
        expression      => qr/^([0-9]{5})(-[0-9]{4})?$/,
        matcher_at      => 1,
    },
    GB      => {
        expression      => qr/^([A-Z]{1,2}[0-9]{1,2}?)([A-Z]?[0-9][A-Z]{2})$
                | ^GIR0AA$ # Special case for Alliance & Leicester, Bootle /x,
        matcher_at      => 1,
    },
    AT      => {
        expression      => qr/^([0-9]{4})$/,
        matcher_at      => 1,
    },
    CZ      => {
        expression      => qr/^([0-9]{5})$/,
        matcher_at      => 1,
    },
    DK      => {
        expression      => qr/^([0-9]{4})$/,
        matcher_at      => 1,
    },
    FI      => {
        expression      => qr/^([0-9]{5})$/,
        matcher_at      => 1,
    },
    FR      => {
        expression      => qr/^([0-9]{5})$/,
        matcher_at      => 1,
    },
    DE      => {
        expression      => qr/^([0-9]{5})$/,
        matcher_at      => 1,
    },
    GG      => {
        expression      => qr/^([A-Z]{1,2}[0-9]{1,2}?)([A-Z]?[0-9][A-Z]{2})$/,
        matcher_at      => 1,
    },
    HU      => {
        expression      => qr/^([0-9]{4})$/,
        matcher_at      => 1,
    },
    NL      => {
        expression      => qr/^([0-9]{4})([A-Z]{2})?$/,
        matcher_at      => 1,
    },
    ES      => {
        expression      => qr/^([0-9]{4})([0-9]{1})$/,
        matcher_at      => 1,
    },
    SE      => {
        expression      => qr/^([0-9]{5})$/,
        matcher_at      => 1,
    },
    CH      => {
        expression      => qr/^([0-9]{4})$/,
        matcher_at      => 1,
    },
    AU      => {
        expression      => qr/^([0-9]{4})$/,
        matcher_at      => 1,
    }
); \%h };

# These regexes are to extract the component parts of a location name.
#
# example DC1: 012J299B
#              ^ ^^^  ^
#              | |||  |
#  DC 01_______/ |||  |
#  Floor 2_______/||  |
#  Zone J_________/|  |
#  Number 299______/  |
#  Level B____________/
#
# example DC2: 021A-0037A
#              ^ ^^ ^   ^
#              | || |   |
#  DC 02_______/ || |   |
#  Floor 1_______/| |   |
#  Zone A_________/ |   |
#  Number 0037______/   |
#  Level A______________/

# DC, Floor, Zone, Number, Level
Readonly our $LOCATION_REGEX =>
    qr/^
        (\d{2})                 # dc name
        (\d)                    # floor
        ([A-Z])                 # zone
        -?
        ([0-9]{3,4})            # 3 or 4 digit number
        ([A-Z])                 # level
        $
    /x;

# The names of the component parts of a location name.

Readonly our $LOCATION_PARTS => do { Readonly my @a => (
    qw[
        dc
        floor
        zone
        number
        level
    ]
); \@a };

our @POSTCODE = qw( $POSTCODE_REGEX );
our @LOCATION = qw( $LOCATION_REGEX $LOCATION_PARTS );

Readonly our $SKU_REGEX =>
    qr/^
        (\d+)   # product_id
        -
        0?(\d+) # size_id
    $/x;

our @SKU = qw( $SKU_REGEX );

Readonly our $PGID_REGEX =>
    qr/^
        P       # the letter 'P' (upper or lower)
        -       # a hyphen
        (\d+)   # some digits
    $/xi;

our @PGID = qw( $PGID_REGEX );

# CANDO-1386: Regex for Language tags
Readonly our $LANGUAGE_REGEX__ISO_639_1     => qr/^([A-Z]{2})$/i;
Readonly our $LANGUAGE_REGEX__IETF_LANG_TAG => qr/^([A-Z]{2})-([A-Z]{2})$/i;

our @LANGUAGE = qw( $LANGUAGE_REGEX__ISO_639_1
                    $LANGUAGE_REGEX__IETF_LANG_TAG );

Readonly our $COUNTRY_REGEX__ISO_3166_1_ALPHA2 => qr/\A([A-Z]{2})\z/;

our @COUNTRY = qw( $COUNTRY_REGEX__ISO_3166_1_ALPHA2 );

our @EXPORT_OK = (
                  @POSTCODE,
                  @LOCATION,
                  @SKU,
                  @PGID,
                  @LANGUAGE,
                  @COUNTRY,
                  );

our %EXPORT_TAGS = (
                    'all'      => [@EXPORT_OK],
                    'postcode' => [@POSTCODE],
                    'location' => [@LOCATION],
                    'sku'      => [@SKU],
                    'pgid'      => [@PGID],
                    'language' => [@LANGUAGE],
                    'country'  => [@COUNTRY],
                    );

1;
