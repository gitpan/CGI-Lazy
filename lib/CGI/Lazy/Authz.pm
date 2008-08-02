=head1 LEGAL

#===========================================================================
Copyright (C) 2008 by Nik Ogura. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Bug reports and comments to nik.ogura@gmail.com. 

#===========================================================================

=head1 NAME

CGI::Lazy::Authz

=head1 SYNOPSIS

Unknown at present

=head1 DESCRIPTION

This module is a stub for the CGI::Lazy Authorization mechanism.  It'll be fleshed out when we get there.
=cut

package CGI::Lazy::Authz;

use CGI::Lazy::Globals;

use strict;
use warnings;

#----------------------------------------------------------------------------------------
sub q {
	my $self = shift;

	return $self->{_q};
}

#----------------------------------------------------------------------------------------
sub new {
	my $class = shift;
	my $q = shift;

	return bless {_q => $q}, $class;
}
1
