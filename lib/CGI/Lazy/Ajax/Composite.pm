package CGI::Lazy::Ajax::Composite;

use strict;
use warnings;

use JavaScript::Minifier qw(minify);
use JSON;
use CGI::Lazy::Globals;
use Tie::IxHash;
use base qw(CGI::Lazy::Ajax);

our $widgetprefix = 'CMP';

#----------------------------------------------------------------------------------------
sub childarray {
	my $self = shift;

	return $self->vars->{children};
}

#----------------------------------------------------------------------------------------
sub children {
	my $self = shift;

	return $self->{_children};
}

#----------------------------------------------------------------------------------------
sub contents {
	my $self = shift;
	my %args = @_;

        my $standalone 		= $self->vars->{standalone};
	my $formOpenTag 	= '';
	my $formCloseTag 	= '';
        my $widgetID		= $self->vars->{id};
	my $children		= $self->childarray; 
	my $output;
	
	if ($standalone) {
		$formOpenTag = $self->vars->{formOpenTag} || $self->q->start_form({-method => 'post', -action => $self->q->url});
		$formCloseTag = $self->q->end_form;
	}
	my $divopen = $args{nodiv} ? '' : "<div id='$widgetID'>";
	my $divclose = $args{nodiv} ? '' : "</div>";

	foreach my $child (@$children) {
		$output .= $child->display(%args);
	}

	return $divopen.
		$formOpenTag.
		$output.
		$formCloseTag.
		$divclose;
}

#----------------------------------------------------------------------------------------
sub display {
	my $self = shift;
	my %args = @_;

	return $self->contents(%args);
}


#----------------------------------------------------------------------------------------
sub new {
	my $class = shift;
	my $q = shift;
	my $vars = shift;

        my $widgetID = $vars->{id};

	my $children = {};
	foreach (@{$vars->{children}}) {
		$children->{$_->widgetID} = $_;
	}

	return bless {_q => $q, 
		_vars => $vars, 
		_widgetprefix => $widgetprefix, 
		_children => $children, 
		_widgetID => $widgetID
	}, $class;
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

CGI::Lazy::Ajax::Composite

=head1 SYNOPSIS

	use CGI::Lazy;

	our $q = CGI::Lazy->new('/path/to/config/file');
	our $composite = $q->ajax->composite({
			id		=> 'stuff',
			children 	=> [],
		);

=head1 DESCRIPTION

Composite is a container for other widgets.  It allows you to perform actions on multiple widgets at once.  Depending on the relationship between the widgets, and how fancy you get, you may need to play with each subwidget by hand.

=head1 METHODS

=head2 childarray ()

Returns array of composite widget's children


=head2 children ()

Returns hashref of composite widget's children


=head2 contents (args)

Generates widget contents based on args.

=head3 args

Hash of arguments.  Common args are mode => 'blank', for displaying a blank data entry form, and nodiv => 1, for sending the contents back without the surrounding div tags (javascript replaces the contents of the div, and we don't want to add another div of the same name inside the div).


=head2 display (args)

Displays the widget initially.  Calls $self->contents, and adds preload lookups and instance specific javascript that will not be updated on subsequent ajax calls.

=head3 args

Hash of arguments


=head2 new (q, vars)

Constructor.

=head3 q

CGI::Lazy object.

=head3 vars

Hashref of object configs.

id			=> widget id 			(manditory)

children 		=> arrayref of child widgets	(manditory)

=cut

