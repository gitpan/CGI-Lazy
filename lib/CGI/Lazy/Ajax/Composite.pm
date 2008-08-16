package CGI::Lazy::Ajax::Composite;

use strict;
use warnings;

use JavaScript::Minifier qw(minify);
use JSON;
use CGI::Lazy::Globals;
use base qw(CGI::Lazy::Ajax);

#----------------------------------------------------------------------------------------
sub ajaxBlank {
	my $self = shift;

	my $widgets 	= [];
	my $output 	= [];

	foreach (@{$self->memberarray}) {
		push @$widgets, $_;
		push @$widgets, $_->ajaxBlank;
	}

	return $self->ajaxReturn($widgets, $output);
}

#----------------------------------------------------------------------------------------
sub ajaxSelect {
	my $self = shift;
	my %args = @_;

	my $type = $self->type;
	$type = ucfirst $type;
	my $method = 'ajaxSelect'.$type;

	return $self->$method;
}

#----------------------------------------------------------------------------------------
sub ajaxSelectManual {
	my $self = shift;
	my %args = shift;


	return;
}

#----------------------------------------------------------------------------------------
sub ajaxSelectParentChild {
	my $self = shift;
	my %args = @_;

	my $incoming = $args{incoming} || from_json(($self->q->param('POSTDATA') || $self->q->param('keywords') || $self->q->param('XForms:Model')));

        my $parent = $self->members->{$self->relationship->{parent}->{name}};

	my %parentKeys;

	foreach my $child (keys %{$self->relationship->{children}}){
		my $handle;
		$parentKeys{$self->relationship->{children}->{$child}->{parentKey}} = {handle => \$handle};

	}

	my %parentParams = (
			incoming => $incoming, 
			div => $self->relationship->{parent}->{searchDiv}, 
			vars => {%parentKeys},
	);

	$parentParams{like} = $self->relationship->{parent}->{searchLike} if $self->relationship->{parent}->{searchLike};

        my $parentOutput = $parent->ajaxSelect(%parentParams); 

#	$self->q->util->debug->edump(\%parentParams);

        if ($parent->multi) {
                return $self->ajaxReturn($parent, $parentOutput);
        } else {

		my $widgets 	= [$parent];
		my $output 	= [$parentOutput];

		foreach my $child (keys %{$self->relationship->{children}}) {
			my %childParams = ($self->relationship->{children}->{$child}->{childKey} => ${$parentKeys{$self->relationship->{children}->{$child}->{parentKey}}->{handle}});

			push @$widgets, $self->members->{$child};
			
			if ($parent->empty) {
				push @$output, $self->members->{$child}->ajaxBlank(div=>1);
			} else {
				push @$output, $self->members->{$child}->ajaxSelect(incoming => {%childParams}, div=>1);
			}
		}

		return $self->ajaxReturn($widgets, $output);
        }


}

#----------------------------------------------------------------------------------------
sub contents {
	my $self = shift;
	my %args = @_;

        my $standalone 		= $self->vars->{standalone};
	my $formOpenTag 	= '';
	my $formCloseTag 	= '';
        my $widgetID		= $self->vars->{id};
	my $members		= $self->memberarray;
	my $output;
	
	if ($standalone) {
		$formOpenTag = $self->vars->{formOpenTag} || $self->q->start_form({-method => 'post', -action => $self->q->url});
		$formCloseTag = $self->q->end_form;
	}
	my $divopen = $args{nodiv} ? '' : "<div id='$widgetID'>";
	my $divclose = $args{nodiv} ? '' : "</div>";

	foreach my $member (@$members) {
		$output .= $member->display(%args);
	}

	return $divopen.
		$formOpenTag.
		$output.
		$formCloseTag.
		$divclose;
}

#----------------------------------------------------------------------------------------
sub dbwrite {
	my $self = shift;
	my %args = @_;

	my $type = $self->type;
	$type = ucfirst $type;
	my $method = 'dbwrite'.$type;

	return $self->$method(%args);;

}

#----------------------------------------------------------------------------------------
sub dbwriteManual {
	my $self = shift;
	my %args = @_;
	
	return;
}

#----------------------------------------------------------------------------------------
sub dbwriteParentChild {
       	my $self = shift;
	my %args = @_;

        my $parent = $self->members->{$self->relationship->{parent}->{name}};

	my %parentKeys;

	foreach my $child (keys %{$self->relationship->{children}}){
		if (($self->relationship->{children}->{$child}->{parentKey} eq $parent->recordset->primarykey) && $parent->recordset->mysqlAuto) {
			$parentKeys{$self->relationship->{children}->{$child}->{parentKey}} = {handle => $parent->recordset->primarykeyhandle};
		} else {
			my $handle;
			$parentKeys{$self->relationship->{children}->{$child}->{parentKey}} = {handle => \$handle};
		}

	}

	$parent->dbwrite(insert => {%parentKeys}, update => {%parentKeys});

	foreach my $child (keys %{$self->relationship->{children}}) {
		my %childParams = ($self->relationship->{children}->{$child}->{childKey} => {value => ${$parentKeys{$self->relationship->{children}->{$child}->{parentKey}}->{handle}}});

		$self->members->{$child}->dbwrite(
					insert	=> {%childParams},
					update 	=> {%childParams},
				);
	}

	return;
}

#----------------------------------------------------------------------------------------
sub display {
	my $self = shift;
	my %args = @_;

	return $self->contents(%args);
}

#----------------------------------------------------------------------------------------
sub memberarray {
	my $self = shift;

	return $self->vars->{members};
}

#----------------------------------------------------------------------------------------
sub members {
	my $self = shift;

	return $self->{_members};
}

#----------------------------------------------------------------------------------------
sub new {
	my $class = shift;
	my $q = shift;
	my $vars = shift;

        my $widgetID = $vars->{id};

	my $members = {};
	foreach (@{$vars->{members}}) {
		$members->{$_->widgetID} = $_;
	}

	return bless {
		_q 		=> $q, 
		_vars 		=> $vars, 
		_members 	=> $members, 
		_widgetID 	=> $widgetID,
		_type		=> $vars->{type} || 'manual',
		_relationship	=> $vars->{relationship},
	}, $class;
}

#----------------------------------------------------------------------------------------
sub relationship {
	my $self = shift;

	return $self->{_relationship};

}

#----------------------------------------------------------------------------------------
sub type {
	my $self = shift;

	return $self->{_type};

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

			type		=> 'parentChild',

			relationship	=> {

                             parent          => {
                                                name            => 'parentWidget',

                                                searchLike      => '%?%',

                                                searchDiv       => 1,

                                },

                                children        => {

                                                activity        => {

                                                        parentKey       => 'advertiser.ID',

                                                        childKey        => 'advertiserID',

                                                },

                                },


			},

			members 	=> [ ... ],
		);

=head1 DESCRIPTION

Composite is a container for other widgets.  It allows you to perform actions on multiple widgets at once.  Depending on the relationship between the widgets, and how fancy you get, you may need to play with each subwidget by hand.  Otherwise, you can specify a type, and use a prebuilt type.

parentChild is a widget that has one widget as the parent, and one or more set up as it's children.  Searching on the parent will return child records that match the parent's results.  Likewise dbwrite will call appropriate methods on all the children based on the widget's construction.

parentChild is pretty experimental.  The configuration given in the example works fine, but I'm not yet convinced the structure is abstracted enough to work for any given group of widgets.  Time will tell, and bugreports/comments.

=head1 METHODS

=head2 ajaxBlank ()

returns blank versions of all member widgets.

=head2 ajaxSelect ()

Runs select query on parameters incoming via ajax call for all member widgets based on widget type.  Returns results formatted for return to browser via ajax handler.

=head2 dbwrite ()

Writes to database for all member widgets based on widget type.

=head2 memberarray ()

Returns array of composite widget's members 

=head2 members ()

Returns hashref of composite widget's members

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

members 		=> arrayref of member widgets	(manditory)

=head1 EXAMPLES

Javascript:

	#these functions are built into a dataset, but at present have to be written manually for a composite

	# javascript functions for recieving search results for a composite widget
	
	function compositeReturn(text) {
		var incoming = JSON.parse(text);
		var html = incoming.html;

		parentController.validator = incoming.validator.parent;
		childController.validator = incoming.validator.child;

		document.getElementById('stuff').innerHTML = html;
	}

	#validation of both parent and child on submit
	function pageValidate() {		
		var parentstate = parentController.validate();
		var childstate = childController.validate();

		if (parentstate && childstate) {
			return true;
		} else {
			return false;
		}
	}

	# javascript functions for searching a parent/child widget composite
	function compositesearch () {
			list = ['parent-field1', 'parent-field2', 'parent-field3'];
			var outgoing = {};

			for (i in list) {
				outgoing[list[i]] = document.getElementById(list[i]).value;
			}

			var compositeSend;
			ajaxSend(compositeSend, outgoing, compositeReturn);
	}

Perl: 
#!/usr/bin/perl

	use strict;
	use warnings;
	use CGI::Lazy;

	our $var = undef;
	our $ref = \$var; #ref to tie parts together.

	our $q = CGI::Lazy->new('/path/to/config/file');
	our $composite = $q->ajax->composite({
			id		=> 'stuff',

			type		=> 'parentChild',

			relationship	=> {

                             parent          => {
                                                name            => 'parentWidget',

                                                searchLike      => '%?%',

                                                searchDiv       => 1,

                                },

                                children        => {

                                                activity        => {

                                                        parentKey       => 'advertiser.ID',

                                                        childKey        => 'advertiserID',

                                                },

                                },


			},

			members 	=> [

				$q->ajax->dataset({
						
						id		=> 'advertiser',

						type		=> 'single',

						multiType	=> 'list',

						containerId	=> 'stuff',

						template	=> 'cscAdvertiser.tmpl',

						multipleTemplate => 'cscAdvertiserMulti.tmpl',

						extravars	=> {

								advertiserID	=> {

										value => $id,

									},
						},

						recordset	=> $q->db->recordset({

									table		=> 'advertiser', 

									fieldlist	=> [

												{name => 'advertiser.ID',	label	=> 'Adv#', handle => $id},

												{name => 'advertiser.companyname',		label	=> 'Company:', 		multi	=> 1},

												{name => 'advertiser.repid',		label	=> 'Account Rep:',	multi	=> 1},

												{name => 'advertiser.address', 		label	=> 'Address:',	 	multi	=> 1},

												{name => 'advertiser.city', 		label	=> 'City:', 		multi	=> 1},

												{name => 'advertiser.state', 		label	=> 'State:'},

												{name => 'advertiser.postalcode', 		label	=> 'Zip:'},

												{name => 'advertiser.country', 		label	=> 'Country'},

												{name => 'advertiser.contactphone',	label	=> 'Phone:'},

												{name => 'advertiser.contactfax', 		label	=> 'Fax:'},

												{name => 'advertiser.contactnamefirst',	label	=> 'Contact:' },

												{name => 'advertiser.contactnamelast',	label	=> '', 			noLabel => 1},

												{name => 'advertiser.contactemail',	label 	=> 'Email:'},

												{name => 'advertiser.website',		label	=> 'Website:'},

												{name => 'advertiser.notes',	label 	=> 'Notes:'},

												{name => 'salesrep.namefirst',	noLabel => 1},

												{name => 'salesrep.namelast', 	noLabel	=> 1}

												], 

									basewhere 	=> '', 

									orderby		=> 'advertiser.ID', 

									primarykey	=> 'advertiser.ID',

									joins		=> [

												{type => 'inner', table	=> 'salesrep', field1 => 'salesrep.ID', field2 => 'advertiser.repid',},

									],

									insertadditional => {

										advertiserID	=> {

												sql => 'select LAST_INSERT_ID()',

												handle => $id,

										},



									},

								}),


				}),

				$q->ajax->dataset({

						id		=> 'activity',

						type		=> 'multi',

						template	=> "cscActivity.tmpl",

						recordset	=> $q->db->recordset({

									table		=> 'activity', 

									fieldlist	=> [

												{name => 'advertiserID', 	hidden => 1},

												{name => 'activity.ID',		label => 'Item#'},

												{name => 'sortdate', 		label => 'RunDate'},

												{name => 'issue', 		label => 'Location'},

												{name => 'page', 		label => 'Page'},

												{name => 'description', 	label => 'Description', nolabel => 1},

												{name => 'type', 		label => 'Type', nolabel => 1},

												{name => 'activity.notes', 	label => 'Notes', nolabel => 1},



												], 

									basewhere 	=> '', 

									orderby		=> 'activity.ID', 

									primarykey	=> 'activity.ID',

						}),

				}),
				
				],
		);


	my %nav = (

		dbwrite => \&dbwrite,

		  );

	if ($q->param('nav')) {

		$nav{$q->param('nav')}->();

	} elsif ($q->param('POSTDATA')) {

		ajaxHandler();

	} else {

		display('blank');

	}

	#----------------------------------------------------------------------------------------
	sub ajaxHandler {
		my $incoming = from_json($q->param('POSTDATA') || $q->param('keywords'));

		if ($incoming->{delete}) {

			doFullDelete($incoming);

			return;

		}

		print $q->header, $composite->ajaxSelect($incoming);

		return;
	}

	#----------------------------------------------------------------------------------------
	sub dbwrite {

		$composite->dbwrite();

		display('blank');
	}

	#----------------------------------------------------------------------------------------

	sub display {

		my $mode = shift;

		print $q->header,

			$q->start_html({-style => {src => '/css/style.css'}}),

			$q->javascript->modules($composite); #javascript functions needed by widget
		
		#header section
		print $q->template('sometemplate.tmpl')->process({ mainTitle => 'Main Title', secondaryTitle => 'Secondary Title', versionTitle => 'version 0.1', messageTitle => 'blah blah blah', });

		#composite widget section
		print $q->start_form({ -id => 'mainForm'}),
		      $q->hidden({-name => 'nav', -value => 'dbwrite'});

		print $composite->display(mode => $mode);
		print $composite->jsload('somejavascript.js');

		print $q->end_form;

		print $q->template('someothertemplate.tmpl')->process({version => $q->lazyversion});

		return;
	}

=cut

