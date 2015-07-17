package Test::XTracker::Data::InternationalText;

use strict;
use warnings;

use utf8;

# This module is a place to keep example text for Unicode testing and such...
#
# There's no structure yet - for now, it's just a global hash of junk. :\

sub example_strings {
    return {
        chinese => '生日快乐！', # test Chinese characters
        german => 'Liebe Grüße aus UK', # test accented characters
        arabic => 'أنا أحبك', # test Arabic characters
        german_double_encoded => 'fÃ¼r meine schÃ¶ne Frau', # double-encoding as seen in our database
        triple_encoded_mojibake => 'Ã¦ÂÂÃ¥Â­ÂÃ¥ÂÂÃ£ÂÂ ', # triple encoded mojibake
        english => 'Happy Birthday', # plain English with ASCII characters only
        english_with_entity => 'Happy Father&#39;s Day', # single-quote HTML character entity
        english_with_heart => 'Thank you ❤', # heart character
        english_with_unicode_star => "Test \N{U+272A} Message", # unicode star character
        english_with_less_than => 'Happy Birthday <3', # < character should not break HTML
        javascript => 'Test <script type="javascript">alert("Hello!");</script> Message', # interrupt the app?
    };
}

sub safe_strings {
    return {
        chinese => '生日快乐！', # test Chinese characters
        german => 'Liebe Grüße aus UK', # test accented characters
        arabic => 'أنا أحبك', # test Arabic characters
        english => 'Happy Birthday', # plain English with ASCII characters only
        english_with_less_than => 'Happy Birthday <3', # < character should not break HTML
        english_with_heart => 'Thank you ❤', # heart character
    };
}

1;
