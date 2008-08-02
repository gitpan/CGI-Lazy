=head1 NAME

CGI::Lazy::Utility

=head1 SYNOPSIS

use CGI::Lazy;

my $q = CGI::Lazy->new('/path/to/config/file');

my $t = $q->util->debug;

=head1 DESCRIPTION

Wrapper object for utility functions.  Primarily serves as a means to access more specific utility objects, while not polluting the namespace of the parent.

=cut

package CGI::Lazy::Utility;

use strict;
use warnings;

use CGI::Lazy::Globals;
use CGI::Lazy::Utility::Debug;

#--------------------------------------------------------------
=head2 debug ()

Debugging object.  See CGI::Lazy::Utility::Debug for details.

=cut

sub debug {
	my $self = shift;

	return CGI::Lazy::Utility::Debug->new($self->q);
}

#--------------------------------------------------------------
=head2 q

Returns CGI::Lazy object

=cut

sub q {
	my $self = shift;

	return $self->{_q};
}

#--------------------------------------------------------------
=head2 new (lazy)

Constructor.

=head3 lazy

CGI::Lazy object.

=cut

sub new {
	my $class = shift;
	my $q = shift;

	return bless {_q => $q}, $class;
}

1

