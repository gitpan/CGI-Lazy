=head1 LEGAL

#===========================================================================
Copyright (C) 2008 by Nik Ogura. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Bug reports and comments to nik.ogura@gmail.com. 

#===========================================================================

=head1 NAME

CGI::Lazy::Auth

=head1 SYNOPSIS

=head1 DESCRIPTION

CGI::Lazy Authentication module.  Draws much of it's inspiration from CGI::Auth. Presently a stub.  To be completed soon.


=cut

package CGI::Lazy::Auth;

use CGI::Lazy::Globals;

use strict;
use warnings;

#----------------------------------------------------------------------------------------
=head2 q ()

returns CGI::Lazy object

=cut

sub q {
	my $self = shift;

	return $self->{_q};
}

#----------------------------------------------------------------------------------------
=head2 new ( q ) 

Constructor.

=head3 q

CGI::Lazy object

=cut

sub new {
	my $class = shift;
	my $q = shift;

	return bless {_q => $q}, $class;
}

1
