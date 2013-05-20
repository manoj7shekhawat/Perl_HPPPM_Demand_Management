package HPPPM::ErrorHandler;

use strict;
use warnings;
use Moose;
use Pod::Usage;
use Log::Log4perl;
use Data::Dumper;
use Getopt::Long;
use LWP::UserAgent;
use Error::TryCatch;
use namespace::autoclean;
use English qw( -no_match_vars );

our $VERSION = '0.01';

has 'input_parsed_xml' => (
    is      => 'rw',
    isa     => 'XML::Simple',
);

#Checks if the input fields that will be used to construct the SOAP
#message have all the reqd. (per operation) types present.Both inputs
#fields and the reqd types are mandatory inputs.Returns True if the reqd. 
#types are present

sub _check_reqd_types {
    my $self       = shift;
    my $fields     = shift || confess "No fields to check properties";
    my $reqd_types = shift || confess "No types to check";
    my $operation  = $self->current_operation();
    my $logger     = Log::Log4perl->get_logger( $PROGRAM_NAME );
    my (@present_types, $msg, $present, $reqd);

    @present_types = grep { exists $fields->{$_} } @{ $reqd_types };

    return 1 if @present_types == @{ $reqd_types };

    $reqd    = join " ",@{ $reqd_types };
    $present = join " ",@present_types;
    $msg  = "Properties present donot match the min. no of properties";
    $msg .= "needed for $operation operation.Properties present:$present";
    $msg .= " Properties required:$reqd Exiting!";

    $logger->logconfess($msg);
}


#Read and return file contents as a single string

sub _get_file_content {
    my $self   = shift;
    my $fname  = shift || confess "No filename to read content from";
    my $logger = Log::Log4perl->get_logger( $PROGRAM_NAME );
    my $fields;

    try {
        $logger->debug("About to read fields containing req fields");

        open my $fhandle, "<", $fname 
                             || throw new Error::Unhandled -text => $OS_ERROR;
        local $INPUT_RECORD_SEPARATOR = undef;
        ($fields = <$fhandle>) =~ s/\\n//g;
    }
    catch Error::Unhandled with {
        print "Unable to read $fname..Exiting! $OS_ERROR";
        $logger->logcroak("Unable to read $fname $OS_ERROR");
    }

    $logger->debug("$fname read! content: $fields");
    
    return $fields;
}


sub validate_read_cmdargs {
    my $self = shift;
    my $p    = new Getopt::Long::Parser;
    my ($oper, $fields, $log_cfg, $ret, $logger,
        $user, $pawd, $help, $oper_exists);
    
    $p->getoptions(
        'operation=s'=> \$oper,
        'user=s'     => \$user,
        'password=s' => \$pawd,
        'fields=s'   => \$fields,
        'config=s'   => \$log_cfg,
        'help|?'     => \$help,
    ) || confess pod2usage(-verbose => 2, -noperldoc => 1,
                           -msg => 'Command line options parsing failed!');

    #validate command line args
    pod2usage(-verbose => 2, -noperldoc => 1) if $help;
    confess pod2usage(-verbose => 2, -noperldoc => 1, -msg => 'Insufficient Args!')
                 if ! ($oper || $user || $pawd || $fields || $log_cfg);
    confess pod2usage(-verbose => 2, -noperldoc => 1, -msg => "$log_cfg missing!")
                                             if ! (-f $log_cfg || -s $log_cfg);
    #Most important, initialize the logger first
    Log::Log4perl->init($log_cfg);
    $logger = Log::Log4perl->get_logger( $PROGRAM_NAME );
 
    $oper_exists = grep { /$oper/ } $self->get_supported_ops();
    $logger->info("Current operation:  $oper") if $oper_exists;
    $logger->logconfess("Unsupported operation: $oper") if ! $oper_exists;
                                        
    #set current oper, user and password
    $self->current_operation($oper);
    $self->user($user);
    $self->password($pawd);
    
    #If $fields points to a file, slurp it
    $fields = $self->_get_file_content($fields) if( -f $fields and -s $fields );

    return $fields;
}


sub validate_inputs {
    my $self            = shift;
    my $fields          = shift || confess "No args to validate";
    my $ignore_types    = shift;
    my $operation       = $self->current_operation();
    my $logger          = Log::Log4perl->get_logger( $PROGRAM_NAME );
    my %ops_inputs_reqd = %{$self->ops_inputs_reqd};
    my (@reqd_types, $ret, $url); 

    #Lookup & localize reqd types needed perform the op
    @reqd_types = @{ $ops_inputs_reqd{ $operation } };
    $ret
	 = $self->_check_reqd_types($fields, \@reqd_types);
    $logger->debug("Reqd. Types for Current Oper Present!") if $ret;
    
    return 1;
}


sub validate_tokens {
    my $self      = shift;
    my $fields    = shift; 
    my $operation = $self->current_operation();
    my $logger    = Log::Log4perl->get_logger( $PROGRAM_NAME );
    my %ops_inputs_reqd = %{ $self->ops_inputs_reqd };
    my (@tokens, $has_tokens, @illegal_tokens, $illegal);

    $logger->info("No token tag in input fields!")
                                        if ! $fields;

    @tokens = ($fields =~ /\b((?:REQD|REQ|UD|T)\.[A-Z\._0-9]+)\b/gc);
    @illegal_tokens 
        = grep {! /(^(?:REQD|REQ|UD|T)\.?(?:VP|P)?\.[A-Z_0-9]+?)$/} @tokens;
    if(@illegal_tokens) {
	$illegal = join " ",@illegal_tokens;
        $logger->logconfess("Illegal Token names: $illegal Exiting!");
    }

    return 1;
}


sub check_url_availability {
    my $self         = shift;
    my $service_url  = shift || confess "No url to check availability";
    my $timeout      = shift || 60;
    my $ua           = LWP::UserAgent->new('timeout' => $timeout);
    my $logger       = Log::Log4perl->get_logger( $PROGRAM_NAME );
    my ($resp, $msg);

    try {
        $resp = $ua->get($service_url);
        throw new Error::Unhandled -text => $resp->status_line 
                                                if ! $resp->is_success;
    }
    catch Error::Unhandled with {
        $logger->logcroak($resp->status_line);
    }

    return 1;
}


sub extract {
    my $self = shift;
    my $resp = shift || confess "No response to extract from";
    my $to_extract = shift || confess "Nothing to extract";
    my $logger     = Log::Log4perl->get_logger( $PROGRAM_NAME );
    my ($xml_parser, $xml_ref, %details, $key, $code, $string, %tag_vals);

    $logger->debug("Extracting values in tags ". join ' ', @{ $to_extract });
    #$resp =~ s/^.+(\<?xml.*)$/$1/i if $resp =~ /^.+(\<?xml.*)$/;

    try {
        require XML::Simple 
               || throw new Error::Unhandled -text => 'XML::Simple not found';

        $xml_parser = XML::Simple->new();
        $xml_ref    = $xml_parser->XMLin($resp);

        $logger->debug("Extracting tag values using the neat XML Parsing");

        for my $key (keys %{$xml_ref}) {
            next if $key !~ /\:body$/i;

	    %details = %{$xml_ref->{$key}};
            #if ( $key =~ /\:fault$/i ) { 
            #    $tag_vals{$_} ||= $details{$_} for @{ $to_extract };
            #}
	    #($key)   = keys %details;

            $tag_vals{$_} = $details{$key}->{$_} for @{ $to_extract };
        }
    }
    catch Error::Unhandled with {
        $logger->debug("Extraction Failed..."); 
    }

    if (! %tag_vals ) {
        $logger->debug("Trying to extract fault with regexp..."); 

	for my $tag ( @{ $to_extract } ) {
	    $tag_vals{$tag} = $1 
	        if $resp =~ /<$tag>(.+)<\/$tag>/isx;
        }
    }
   
    $logger->debug("TAGS -> VALUES: ", %tag_vals);

    return \%tag_vals;
}

__PACKAGE__->meta->make_immutable;

1; # End of HPPPM::ErrorHandler

__END__

=head1 NAME

HPPPM::ErrorHandler - Error Handling Base class for all HPPPM Classes

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

Error Handling Base class for all HPPPM Classes.Performs command line parsing, 
validation of arguments and error extraction.Desginwise, this class is meant to
be subclassed and used transparently by HPPPM classes, however it can be 
instantiated directly.

$hpppm = HPPPM::Demand::Management->new();

$fields = $hpppm->validate_read_cmdargs(@ARGV);
$tags   = $hpppm->get_inputs($hpppm->get_current_oper());

$inputs = FieldParser::parser($fields, $tags);

$ret    = $hpppm->validate_inputs($inputs); 
$ret    = $hpppm->validate_tokens($inputs->{'fields'}) 
                            if grep /^fields$/, @{ $tags };  


$ret    = $hpppm->extract($res, ['faultcode', 'faultstring', 
                                 'exception:detail', 'id', 'return']);


=head1 DESCRIPTION

Error Handling Base class for all HPPPM Classes.Performs command line parsing, 
validation of arguments and error extraction.Desginwise, this class is meant to
be subclassed and used transparently by HPPPM classes, however it can be 
instantiated directly.

The class performs validation at various levels: 

1. Validating the presence of filenames(with data) passed as cmd args.

2. Web service operation being performed is legal and supported.

3. Before posting Check if the Web Service is up and accessible or not.

4. Validate data that will be used to create Web service request(optional).

The class also provides in-detail execption extraction.


=head1 ATTRIBUTES

=head1 METHODS

=head2 validate_read_cmdargs

perl bin/hpppm_demand.pl -o createRequest -u user -p password -f data/createRequest.data -c cfg/logging.conf

-o or --operation  is the webservice operation being performed
-u or --user       user authorized to perform web service operation
-p or --password   user's password
-f or --fields     location of file containing input fields that will be used to create
                   the web service request.Instead of a path this can also be a string
                   containing the input fields.A sample data file for each web service
                   operation has been bundled along with distribution under data dir.
-c or --logconfig  location to the configuration file that drives logging behavior.
-h or --help or -? display help.

=head2 validate_inputs

Checks if the required types need in order to perform
the operation successfully are present in the input data or not.

=head2 validate_tokens

Checks if the operation being performed supports tokens or not. If no
tokens are needed the method returns 0.Performs the following checks on
tokens as well -All field tokens must be all caps. Token prefixes
(REQD, REQ, UD, T, VP, P) must be one of the specified types.All tokens
can contain only alphanumeric characters and _ (underscore).Input is
input fields and output is Success or Failure

=head2 check_url_availability 

Tests service URL for accessibility.Input is url to test and return
Success or Failure

=head2 extract

Extracts the value(s) which are valid tags in the response received
in response to the request posted to the webservice.The value(s)/tag(s)
must be passed in as a array ref.The return value is a hash ref with 
key as the tag and value as its extracted value.

=head1 AUTHOR

Varun Juyal, <varunjuyal123@yahoo.com>

=head1 BUGS

Please report any bugs or feature requests to C<bug-hpppm-demand-management at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=HPPPM-Demand-Management>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc HPPPM::ErrorHandler


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=HPPPM-Demand-Management>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/HPPPM-Demand-Management>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/HPPPM-Demand-Management>

=item * Search CPAN

L<http://search.cpan.org/dist/HPPPM-Demand-Management/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Varun Juyal.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

