package XT::DB::BackFill::Type;

use NAP::policy;

=head1 NAME

XT::DB::BackFill::Type

=head1 SYNOPSIS

    package Some::Class;

    use XT::DB::BackFill::Type      qw( PrettySQLComment );

    has some_attrib => (
        is  => 'rw',
        isa => PrettySQLComment,
    );
    ...
    1;

    # somewhere else:

    my $obj = Some::Class->new( {
        some_attrib => 'a comment',
    } );

=head1 DESCRIPTION

Provides Types for the 'XT::DB::Backfill' name-space.

=cut

use XTracker::Utilities     qw( trim );

use MooseX::Types   -declare => [ qw(
    EmptyString
    PrettySQLComment
    EmptyOrPrettySQLComment
) ];

use MooseX::Types::Moose    qw( Str );


=head1 TYPES

=head2 EmptyString

An Empty String Type.

=cut

subtype EmptyString,
    as      Str,
    where   { $_ eq '' },
    message { "String (${_}) is NOT Empty" }
;

=head2 PrettySQLComment

An SQL Comment, meaning the String should start with '-- ' and
end with a 'newline' character, or for spacer comments just
have '--' followed by a 'newline' character.

    Examples:
        -- A Comment

        with spacer comments:
        --
        -- A Comment
        --

Having '--' followed by a space makes the comment easier
(Prettier) to read. You should use coercion with your
Attributes so that this will automatically be done, so
passing '--comment' will automatically be turned into
'-- comment'.

=cut

subtype PrettySQLComment,
    as      Str,
    where   { $_ =~ m/^(--|-- .*)\n$/m },
    message { "String (${_}) is NOT a Pretty SQL Comment" }
;

# this will make sure that any string passed to
# the 'PrettySQLComment' Type will have leading '-- '
# and end with a newline character.
coerce PrettySQLComment,
    from Str,
    via  {
        join( "\n",
            map { (
                $_ eq ''
                ? '--'          # used for spacer comments when you just want '--'
                : '-- ' . $_    # used for comments with content, prefixed with '-- '
            ) } map {
                    my $str = $_;
                    $str    =~ s/^\s*-+//;
                    trim( $str );
                } split( /\n/, $_ )
        ) . "\n"
    }
;

=head2 EmptyOrPrettySQLComment

A Union of the 'EmptyString' and 'PrettySQLComment' Types.

=cut

subtype EmptyOrPrettySQLComment,
    as      EmptyString | PrettySQLComment,
    message { "String (${_}) is neither Empty or a Pretty SQL Comment" }
;

