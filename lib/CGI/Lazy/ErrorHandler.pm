package CGI::Lazy::ErrorHandler;

use strict;
use warnings;

use CGI::Lazy::Globals;

#----------------------------------------------------------------------------------------
sub badConfig {
	my $self = shift;
	my $filename = shift;

	print $self->q->header, "Couldn't parse config file $filename: $@";
	exit;
}

#----------------------------------------------------------------------------------------
sub badSession {
	my $self = shift;
	my $id = shift;

	print $self->q->header, "Bad Session ID : $id";
	exit;
}

#----------------------------------------------------------------------------------------
sub badSessionExpiry {
	my $self = shift;

	print $self->q->header, "Bad Session Config.  Please check your config file or hash in the Session->{expires} key.";
	exit;
}

#----------------------------------------------------------------------------------------
sub config {
	my $self = shift;

	return $self->q->config;
}


#----------------------------------------------------------------------------------------
sub couldntOpenDebugFile {
	my $self = shift;
	my $filename = shift;
	my $error = shift;

	print $self->q->header, "Couldn't open Debugging Log file /tmp/$filename: $error";
	exit;
}

#----------------------------------------------------------------------------------------
sub couldntOpenJsFile {
	my $self = shift;
	my $docroot = shift;
	my $jsdir = shift;
	my $file = shift;
	my $error = shift;

	print $self->q->header, "Couldn't open JS file $docroot$jsdir/$file: $error";
	exit;
}

#----------------------------------------------------------------------------------------
sub dbConnectFailed {
	my $self = shift;

	print $self->q->header, "Database connection failed: <br><br> $@";
	exit;
}

#----------------------------------------------------------------------------------------
sub dbError {
	my $self = shift;
	my $pkg = shift;
	my $file = shift;
	my $line = shift;
	my $query = shift;

	print $self->q->header, "Database operation failed in $file calling $pkg at line $line : <br><br> $@ <br> calling: <br> $query";
}

#----------------------------------------------------------------------------------------
sub dbReturnedMoreThanSingleValue {
	my $self = shift;

	my ($pkg, $file, $line) = caller;
	print $self->q->header, "Database lookup return more thana single value in $pkg called by $file at line $line";
}

#----------------------------------------------------------------------------------------
sub getWithOtherThanArray {
	my $self = shift;

	my ($pkg, $file, $line) = caller;
	print $self->q->header, "DB get (get, getarray, gethashlist) called with something other than an array reference in $pkg called by $file at line $line.  That won't fly, exiting";
	exit;
}

#----------------------------------------------------------------------------------------
sub noConfig {
	my $self = shift;
	my $filename = shift;

	my $headervars = {
		mainTitle 	=> "Config Error",
		secondaryTitle	=> "A problem occured in creating the Config object",
		versionTitle	=> "version ".$self->q->lazyversion,
		messageTitle	=> "Couldn't open config file $filename : $@",
	};

	print $self->q->header, "Couldn't open config file $filename : $@";
	exit;
}

#----------------------------------------------------------------------------------------
sub new {
	my $class = shift;
	my $q = shift;

	return bless {_q => $q}, $class
}

#----------------------------------------------------------------------------------------
sub q {
	my $self = shift;

	return $self->{_q};
}

#----------------------------------------------------------------------------------------
sub tmplCreateError {
	my $self = shift;

	print $self->q->header, "Template Creation Error: <br><br> $@";
}

#----------------------------------------------------------------------------------------
sub tmplParamError {
	my $self = shift;
	my $template = shift;

	print $self->q->header, "Template Parameter Error in $template: <br><br> $@";
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

CGI::Lazy::ErrorHandler

=head1 SYNOPSIS

	use CGI::Lazy;

	my $q = CGI::Lazy->new('/path/to/config/');

	eval {
		something();
	};

	if ($@) {
		$q->errorHandler->funkyErrorMethod;
	}

=head1 DESCRIPTION

CGI::Lazy::ErrorHandler is simply a bunch of canned error messages for displaying errors to the user.

At some point in the future, it will display them in a neater and more unified way, but for now, it's just a convenience object.


=cut

