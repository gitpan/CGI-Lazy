package CGI::Lazy::Image;

use strict;
use warnings;

use CGI::Lazy::Globals;

no warnings qw(uninitialized redefine);

#-------------------------------------------------------------------------------------------------
sub dir {
	my $self = shift;

	return $self->{_dir};
}

#----------------------------------------------------------------------------------------
sub file {
	my $self = shift;
	my $file = shift;

	my $dir = $self->dir;

	return "$dir/$file";
}

#----------------------------------------------------------------------------------------
sub load {
	my $self = shift;
	my $file = shift;
	
	my $dir = $self->dir;
	$dir =~s/^\///; #strip a leading slash
	my $docroot = $ENV{DOCUMENT_ROOT};
	$docroot =~ s/\/$//; #strip the trailing slash so we don't double it

	return "$docroot/$dir/$file";

}

#-------------------------------------------------------------------------------------------------
sub new {
	my $class = shift;
	my $q = shift;

	return bless {
		_q 		=> $q,
		_dir		=> $q->config->imgDir,
	
	}, $class;
}

#-------------------------------------------------------------------------------------------------
sub q {
	my $self = shift;

	return $self->{_q};
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

CGI::Lazy::Image

=head1 SYNOPSIS

	use CGI::Lazy;

	my $q = CGI::Lazy->new();


	my $imagedir = $q->image->dir;


=head2 DESCRIPTION

CGI::Lazy::Image is, at present, just a convience module for accessing images.

=head1 METHODS

=head2 dir ()

Returns directory containing css specified at lazy object creation

=head2 file (image)

Returns absolute path to file image parsed with document root and image directory

=head3 image

Image file name

=head2 q ( ) 

Returns CGI::Lazy object.

=head2 new ( q )

constructor.

=head3 q

CGI::Lazy object

=cut

