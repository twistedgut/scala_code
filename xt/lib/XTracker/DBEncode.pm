package XTracker::DBEncode;

use strict;
use warnings;

use Encode qw{ encode decode :fallback_all };
use Try::Tiny;
use Exporter;
use Data::Dump qw{ pp };
use XTracker::Logfile qw( xt_logger );
use parent 'Exporter';

our @EXPORT_OK = qw{decode_db encode_db decode_it encode_it};

my $MAX_DECODE_ATTEMPTS = 5;
my $logger;     # We want to avoid initialising xt_logger too many times

# Regex patterns to check data in order to try and catch double encoded data
# and data which is UTF8 but is not flagged as such
# matches a "double" encoded UTF-8 sequence within the range U+0000 - U+10FFFF
my $UTF8_double_encoded = qr/
    \xC3 (?: [\x82-\x9F] \xC2 [\x80-\xBF]                                    # U+0080 - U+07FF
           |  \xA0       \xC2 [\xA0-\xBF] \xC2 [\x80-\xBF]                   # U+0800 - U+0FFF
           | [\xA1-\xAC] \xC2 [\x80-\xBF] \xC2 [\x80-\xBF]                   # U+1000 - U+CFFF
           |  \xAD       \xC2 [\x80-\x9F] \xC2 [\x80-\xBF]                   # U+D000 - U+D7FF
           | [\xAE-\xAF] \xC2 [\x80-\xBF] \xC2 [\x80-\xBF]                   # U+E000 - U+FFFF
           |  \xB0       \xC2 [\x90-\xBF] \xC2 [\x80-\xBF] \xC2 [\x80-\xBF]  # U+010000 - U+03FFFF
           | [\xB1-\xB3] \xC2 [\x80-\xBF] \xC2 [\x80-\xBF] \xC2 [\x80-\xBF]  # U+040000 - U+0FFFFF
           |  \xB4       \xC2 [\x80-\x8F] \xC2 [\x80-\xBF] \xC2 [\x80-\xBF]  # U+100000 - U+10FFFF
          )
/x;

# matches a well-formed UTF-8 encoded sequence within the range U+0080 - U+10FFFF
my $UTF8 = qr/
    (?: [\xC2-\xDF] [\x80-\xBF]                           # U+0080 - U+07FF
      |  \xE0       [\xA0-\xBF] [\x80-\xBF]               # U+0800 - U+0FFF
      | [\xE1-\xEC] [\x80-\xBF] [\x80-\xBF]               # U+1000 - U+CFFF
      |  \xED       [\x80-\x9F] [\x80-\xBF]               # U+D000 - U+D7FF
      | [\xEE-\xEF] [\x80-\xBF] [\x80-\xBF]               # U+E000 - U+FFFF
      |  \xF0       [\x90-\xBF] [\x80-\xBF] [\x80-\xBF]   # U+010000 - U+03FFFF
      | [\xF1-\xF3] [\x80-\xBF] [\x80-\xBF] [\x80-\xBF]   # U+040000 - U+0FFFFF
      |  \xF4       [\x80-\x8F] [\x80-\xBF] [\x80-\xBF]   # U+100000 - U+10FFFF
    )
/x;


# Flags to control whether decode_db and encode_db do something
# # If pg_enable_utf8 is enabled and we are confident that the data in the
# # database does not contain double encoded data, then $DECODE should be set
# # to 0.
# # We now have client_encoding_utf8 enabled and are confident that XT only
# # has characters (not bytes) being passed around as strings internally so
# # $ENCODE is disabled.
our $DECODE = 1;
our $ENCODE = 0;

# Part of the intention is to replace ad-hoc usages of decode_utf8().

# We are now using pg_enable_utf8 in DBD::Pg however we know that we still
# have some double encoded data in the database. Once that is cleaned up
# we can set $DECODE to 0 thus setting all decode_db to no-ops.

# HOWEVER, it seems that even with pg_enable_utf8 enabled, you can still
# get problems passing strings into DBD::Pg, IF the strings are downgraded
# strings (i.e. those strings with the utf8 flag false).
# To make everything work, it is necessary to make the byte string which
# is passed to DBD::Pg be UTF-8. We could conceivably call encode_utf8 to
# HOWEVER this would be risky because:
#   We generally have DBIx::Class between us and the database.
#   If we call encode_utf8, this results in a downgraded string. If some
#   code in between the encode_utf8 and the time the data is passed to DBD::Pg
#   accidentally causes this string to get upgraded, then the data would get
#   "double encoded".
# So instead we can just do utf8::upgrade on the string.
#
# If the string was already upgraded then utf8::upgrade is a no-op.
# If the string was downgraded, then utf8::upgrade converts it to utf8
# representation by converting all code points 0x80..0xFF into two-byte utf8
# sequences (though from a Perl string perspective, the value is unchanged).
# So after utf8::upgrade, we have upgraded string, i.e. with the utf8 flag set.
#
# The in-memory representation of this will always be utf8, which will
# cause the correct value to be passed into DBD::Pg.
# Since the value is already upgraded, it can't accidentally by upgraded by
# intervening code (which would otherwise be a problem).

sub decode_db {
    return unless @_;
    if (!$DECODE) {
        if (!defined wantarray) { return }
        if (wantarray) { return @_ }
        if (scalar @_ != 1) {
            $logger->warn('Called in scalar context but not 1 parameter');
        }
        return $_[0];
    }

    if ( scalar @_ > 1 ) {
        my @return;
        foreach my $thing (@_) {
            push @return, decode_db($thing);
        }
        return wantarray ? @return : \@return;
    }

    return _deeply(\&_decode_db_single, @_);
}

sub decode_it {
    return unless @_;

    if ( scalar @_ > 1 ) {
        my @return;
        foreach my $thing (@_) {
            push @return, decode_it($thing);
        }
        return wantarray ? @return : \@return;
    }

    return _deeply(\&_decode_db_single, @_);
}

sub encode_db {
    return unless @_;
    if (!$ENCODE) {
        if (!defined wantarray) { return }
        if (wantarray) { return @_ }
        if (scalar @_ != 1) {
            $logger->warn('Called in scalar context but not 1 parameter');
        }
        return $_[0];
    }

    if ( scalar @_ > 1 ) {
        my @return;
        foreach my $thing (@_) {
            push @return, encode_db($thing);
        }
        return wantarray ? @return : \@return;
    }

    return _deeply(\&_encode_db_single, @_);
}

sub encode_it {
    return unless @_;

    if ( scalar @_ > 1 ) {
        my @return;
        foreach my $thing (@_) {
            push @return, encode_it($thing);
        }
        return wantarray ? @return : \@return;
    }

    return _deeply(\&_encode_db_single, @_);
}

# Decode a single value
sub _decode_db_single {
    if (!defined $_[0]) { return $_[0] }

    my $retval = $_[0];

    # Issue a warning in the logs if we encounter double encoded data
    if ( ( ! Encode::is_utf8($retval) )
            && _looks_like_double_encoded_utf8($retval) ) {
        my ($caller, $file, $line) = caller();
        my $logger = _get_logger();
        $logger->warn("Double encoded data in $caller at $line");
    }

    # We either decode the whole string, or we do none of it
    # we check to see if the string looks like UTF8 or double encoded data
    # and decode for as long as it does or until we reach MAX_DECODE_ATTEMPTS
    # which is there to stop runaway conditions.

    my $count = 0;

    DECODE:
    while ( _is_utf8($retval) || _looks_like_double_encoded_utf8($retval) ) {
        try {
            $retval = decode("UTF-8", $retval, DIE_ON_ERR | LEAVE_SRC);
        } catch {
            # Don't need to do anything here. The exception just signifies that
            # no further decoding from UTF-8 was necessary or possible.
        };
        $count++;
        if ( $count > $MAX_DECODE_ATTEMPTS ) {
            if ( (! Encode::is_utf8($retval) ) && _is_utf8( $retval ) ) {
                my $logger = _get_logger();
                $logger->warn("Max decodes exceeded and value remains encoded!"
                    .pp($retval) );
            }
            last DECODE;
        }
    }

    return $retval;
}

# Encode a single value
sub _encode_db_single {
    # Don't copy the string if the parameter is already upgraded
    # We no longer do this as it's not reliable. Instead we try and decode.
    # if ((!defined $_[0]) || utf8::is_utf8($_[0])) { return $_[0] }

    # (in)sanity to avoid double encoding
    my $upgrade = decode_db($_[0]);

    $upgrade = encode("UTF-8", $upgrade);

    return $upgrade;
}


# Map a string conversion function so that it can work on an arbitrarily
# nested data structure, applying it to all array elements and hash elements
# (but not hash keys)
# !!! RECURSIVE !!!
sub _deeply {
    my $action = shift;

    if (@_ == 1) {
        my $r = ref $_[0];

        if (!$r) {
            return $action->($_[0]);
        } elsif ($r eq 'ARRAY') {
            my $ra = $_[0];

            # RECURSE for array reference processing
            return [ map { _deeply($action, $_) } @$ra ];
        } elsif ($r eq 'HASH') {
            my $rh = $_[0];

            # RECURSE for hash reference processing
            return { map { $_ => _deeply($action, $rh->{$_}) } keys %$rh }
        }
        else {
            # For other ref types do nothing - just return what we were given
            _get_logger()->warn("_deeply called with input of type $r. Cannot process so returning input unchanged");
            return $_[0];
        }
    } else {
        if (!wantarray) {
            _get_logger()->warn('_deeply called with not one arg but not in list context');
        }

        # RECURSE for array processing
        return ( map { _deeply($action, $_) } @_ );
    }
}

sub _is_utf8 {
    return 1 if $_[0] =~ /$UTF8/og;
    return;
}

sub _looks_like_double_encoded_utf8 {
    # This method only takes a single scalar input so croaks if passed more
    # than 1 input.
    @_ == 1 || return;

    # This checks the input against each regex to determine whether it is
    # double encoded. If it matches a regex assigns 1 to the anonymous list
    # which gets evaluated as the result of do thus setting count if the data
    # is double encoded or undef otherwise.
    my $count = do {
        if (&utf8::is_utf8) { ## no critic(ProhibitAmpersandSigils)
            () = $_[0] =~ /$UTF8/og;
        }
        else {
            () = $_[0] =~ /$UTF8_double_encoded/og;
        }
    };
    return $count;
}

sub max_decodes {
    return $MAX_DECODE_ATTEMPTS;
}

sub _get_logger {
    return $logger if $logger;
    $logger = xt_logger( 'XTracker_DBEncode' );
    return $logger;
}

1;

