package CGI::Lazy::Widget::DomLoader;

use strict;
use warnings;

use base qw(CGI::Lazy::Widget);
use JSON;

no warnings qw(uninitialized redefine);

#----------------------------------------------------------------------------------------
sub new {
	my $class = shift;
	my $q = shift;
	my $vars = shift;

        my $widgetID = $vars->{id};
	return bless {_q => $q, _vars => $vars, _widgetID => $widgetID}, $class;
}

#----------------------------------------------------------------------------------------
sub output {
	my $self = shift;

	my $output = $self->preloadLookup;
	$output .= $self->domload;

	return $output;
}

1

__END__

=head1 LEGAL

#===========================================================================

Copyright (C) 2008 by Nik Ogura. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Bug reports and comments to nik.ogura@gmail.com. 

#===========================================================================

=head1 NAME

CGI::Lazy::Widget::DomLoader

=head1 SYNOPSIS

	use CGI::Lazy;

	my $q = CGI::Lazy->new('frobnitz.conf');

	my $domloader = $q->domloader({

				lookups =>  {

						countryLookup => {  #name of resultant DOM object

							sql 	=> 'select ID, country from countryCodeLookup ', 

							orderby	=> ['ID'],

							output	=> 'hash',

							key	=> 'ID',

						},

					},

			});

	print $domloader->output;

=head1 DESCRIPTION

CGI::Lazy::Widget::DomLoader is an object for preloading useful stuff into a page's DOM, such as lookup queries, or any javascript object that might be desired.  This is functionality that is duplicated from the internals of CGI::Lazy::Widget::Dataset, but it's included as a separate object for preloading arbitrary values for other purposes.


=head1 METHODS

=head2 new (q, vars)

Constructor.

=head3 q

CGI::Lazy object.

=head3 vars

Hashref of object configs.


=head2 output ()

Returns output of object for printing to the web page

=cut

