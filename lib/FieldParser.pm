package FieldParser;

use 5.006;
use strict;
use warnings;
use Exporter ();
use base qw(Exporter);
use List::MoreUtils qw(first_index last_index);

our @EXPORT    = qw(parser);
our @EXPORT_OK = qw(tokenizer weeder extractor); 

our $VERSION = '0.01';

sub Iterator(&) { $_[0] };


sub tokenizer {
    my $input    = shift || die "No input passed!Exiting...";
    my $weedout  = shift; 
    my $split_on = shift || qr/"\s+?"/;
    my $ignore   = shift || [];
    my @tokens;

    @tokens = split /$split_on/, $input;

    return Iterator {
        while( @tokens ) {
            my $token = shift @tokens;
            
            for my $to_ignore ( @{ $ignore } ) {
                return $weedout->($token) if $token ne $to_ignore;
            }

            return $weedout->($token) if ! @{ $ignore };
        }
    }
}


sub weeder {
    my $weed = shift || qr/\<\/|\>|\<|\"|\'/;
    
    return sub {
        my $token = shift;

        $token =~ s/$weed//g if $token;
        return $token; 
    }

}


sub extractor {
    my $tokens = shift || die "No tokens passed!Exiting...";
    my $all    = shift || [];
    my $ignore = shift || [];
    my $what   = shift;
    my $how    = shift;
    my %request;

    return $how->($tokens, $what) if ref $how eq 'CODE';

    if (! $what) {
        for $what ( @{ $all } ) {
            my ($s_idx, $e_idx);
            $s_idx = first_index { $what eq $_ } @{ $tokens };
            if ( $s_idx == -1 ) {
                print "Search for $what failed!Error - $what doesn't exist"; 
                next;
            }

            $e_idx = last_index  { $what eq $_ } @{ $tokens };
            if ( $s_idx == $e_idx ) {
                print "Search for $what failed!Error - Only one tag Found";
                next; 
            }

            $request{$what} = [ @{ $tokens }[$s_idx+1..$e_idx-1] ];
            
        }
        return \%request;
    }
    else {
        my ($s_idx, $e_idx);
        $s_idx = first_index { $what eq $_ } @{ $tokens };
        print "Search for $what failed!Error - 
              $what doesn't exist"; return \%request if $s_idx == -1;

        $e_idx = last_index  { $what eq $_ } @{ $tokens };
        print "Search for $what failed!Error - 
               Only one tag Found"; return \%request if $s_idx == $e_idx; 
        
        return [ @{ $tokens }[$s_idx+1..$e_idx-1] ];
    }
}


sub parser {
    my $inp     = shift || die "No input passed!Exiting...";
    my $extract = shift || die "No interested tags passed!Exiting...";
    my $sep     = shift || qr/"\s+?"/;
    #my $wo      = shift || qr/\<\/|\>|\<|\"|\'/;
    my $wo      = shift || qr/\<\/|\>|\<|\"|\'|\s+$/;
    my $it      = shift || [];
    my $ig      = shift || [];
    my ($inputs, $weed, @tokens, $token);

    $inputs = $inp;
    $inputs = $inp->[0] if ref $inp eq 'ARRAY';

    $weed = weeder($wo);
    if (! ref $inputs) {
        my $iter = tokenizer($inputs, $weed, $sep, $it);

        push @tokens, $token while ( $token = $iter->() );
    }
    else {
        #push @tokens, $token for token @$inputs;
        push @tokens, $weed->($_) for @$inputs;
    }

    return extractor(\@tokens, $extract, $ig);
}

1; # End of FieldParser

__END__

=head1 NAME

FieldParser - A generic parser. 

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

A generic parser made on the principles of Higher Order 
Programming.The parser is meant to parse the input and
store the parsed text in a hashref.

use FieldParser;

my $interesting_tags = ['requestType', 'serviceUrl'];

my $input  = '"<serviceUrl>" "http://d.com" "</serviceUrl>" "<requestType>" "AIS" "</requestType>"'

my $parsed = FieldParser::parser($input, $interesting_tags);

=head1 EXPORT

parser    (default export)

tokenizer (ondemand export)

weeder    (ondemand export)

extractor (ondemand export)

=head1 SUBROUTINES

=head2 tokenizer

Convert raw input string into units of interest.Weedout and ignore 
text not needed. 

=head2 weeder

Sanitize input - remove weeds/unwanted text

=head2 extractor

Extract tokens embedded between specific tags.One can extract
tokens between a specific tag or ask for all tokens embedded
between all tags of interest.

=head2 parser

Intended interface to the outside unsuspecting world.Takes in the
raw input, interested tags, token separator(regexp), unwanted text
in tokens(regexp), unwanted tokens and all unwanted tokens between
specific tags.

=head1 AUTHOR

Varun Juyal, C<< <varunjuyal123 at yahoo.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-fieldparser at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=FieldParser>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc FieldParser


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=FieldParser>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/FieldParser>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/FieldParser>

=item * Search CPAN

L<http://search.cpan.org/dist/FieldParser/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Varun Juyal.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

