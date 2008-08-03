package CGI::Lazy::Ajax::Dataset;

use strict;
use warnings;

use JavaScript::Minifier qw(minify);
use JSON;
use CGI::Lazy::Globals;

use base qw(CGI::Lazy::Ajax);

our $widgetjs = <<END;
var __WIDGETID__Validator;
var __WIDGETID__Controller = new adsController('__WIDGETID__', __WIDGETID__Validator, '__PARENTID__');
var __WIDGETID__MultiSearchPrimaryKey = '__PRIMARYKEY__';

END

#----------------------------------------------------------------------------------------
sub buildvalidator {
	my $self = shift;

	my $validator = {};

	foreach ( @{$self->recordset->visibleFields}) {
		if ($self->recordset->validator($_)) {
			my $rules = $self->recordset->validator($_);
			$rules->{label} = $self->recordset->label($_);
			if ($self->type eq "multi") {
				$validator->{$self->widgetID."-".$_.1} = $rules;
			} elsif ($self->type eq "single") {
				$validator->{$self->widgetID."-".$_} = $rules;
			}
		}
	}
	
	$self->{_validator} = $validator;
}

#----------------------------------------------------------------------------------------
sub contents {
	my $self = shift;
	my %args = @_;

        my $widgetID		= $self->widgetID;
	my $vars 		= $self->vars;

	my $type 		= $vars->{type};
	my $multiType	 	= $vars->{multiType};
	my $parentID 		= $vars->{parentId};
        my $submitArgs          = $vars->{submit};
        my $tableCaptionValue   = $vars->{tableCaption}; #can be blank
        my $recset              = $vars->{recordset}; #required
        my $template            = $vars->{template}; #required
        my $lookups             = $vars->{lookups}; #if this isn't set, then new records will only contain what's on the screen
        my $tdHandling          = $vars->{tdHandling} || 'manual';
        my $standalone          = $vars->{standalone};
	my $defaults 		= $vars->{defaultvalues}; #if this isn't set, then new records will only contain what's on the screen
	my $nodelete		= $vars->{nodelete};
	my $deletename		= $vars->{deleteName} || 'Delete';

        my $tableCaptionVar     = "CAPTION";
        my $headingLoopVar      = "HEADING.LOOP";
        my $headingItemVar      = "HEADING.ITEM";
        my $bodyRowLoopVar      = "ROW.LOOP";
        my $bodyRowName         = "ROW";
        my $surroundingDivName  = "DIV.MAIN";
        my $submitFlag		= "SUBMIT";
	my $deleteID		= "DELETE.ID";
	my $deleteFlag		= "DELETE.FLAG";

        my $formOpenTag 	= '';
        my $formCloseTag 	= '';
	my $validator 		= {};
	my $tmplvars 		= {};

	$tmplvars->{$submitFlag} = 1 if $vars->{submit};

	$type = 'multi' unless $type;

	if ($type eq 'single') {
		$multiType = 'list' unless $multiType;
	}

        if ($standalone) {
                $formOpenTag = $vars->{formOpenTag} || $self->q->start_form({-method => 'post', -action => $self->q->url});
                $formCloseTag = $self->q->end_form;
        }


	$recset->select(@{$args{binds}}) unless $args{mode} eq 'blank';
#	$self->q->util->debug->edump($recset->data);

	$self->{_multi} = 0;
	$self->{_empty} = 0;

	if ($type eq 'multi') {
		my @headings = map {{$headingItemVar => $_}} $recset->visibleFieldLabels;
		push @headings, {$headingItemVar => $deletename} unless $nodelete;
		
		my $bodyRowLoop = [];

		my $newrecordindex = 0;

		for (my $i = 0; $i < @{$recset->data}; $i++) {
			my $row = {}; 
			my $rownum = $i + 1; 
			my $ID = $recset->data->[$i]->{$recset->primarykey};

			$row->{$bodyRowName} = "row$rownum";
			$row->{$deleteID} = "$widgetID-$rownum" unless $nodelete;
			$row->{$deleteFlag} = 1 unless $nodelete;

			foreach my $fieldname (keys %{$recset->data->[$i]}) {
				if ($recset->handle($fieldname)) { #if we've been given a handle for this field, set it
					${$recset->handle($fieldname)} = $recset->data->[$i]->{$fieldname};			
				}

				unless ($recset->hidden($fieldname)) { #don't add hidden fields
					$row->{"NAME.".$fieldname} = "$widgetID-:UPDATE:".$fieldname."-:-".$ID."::".$rownum; 
					$row->{"ID.".$fieldname} = "$widgetID-".$fieldname.$rownum;

					if ($recset->outputMask($fieldname)) {
						$row->{"VALUE.".$fieldname} = sprintf $recset->outputMask($fieldname), $recset->data->[$i]->{$fieldname}; 
					} else {
						$row->{"VALUE.".$fieldname} = $recset->data->[$i]->{$fieldname}; 
					}

					if ($recset->validator($fieldname)) {
						my $rule = $recset->validator($fieldname);
						$rule->{label} = $recset->label($fieldname);
						$validator->{"$widgetID-".$fieldname.$rownum} =  $rule;
					}
				}
			}

			$newrecordindex = $rownum;
			push @$bodyRowLoop, $row; 
		}

		#blank record for inserts
		
		my $defaultstring = join ",", sort keys %$defaults;
		my $blankrow = {};
		$newrecordindex++;
		$blankrow->{$bodyRowName} = "row$newrecordindex";
		$blankrow->{$deleteID} = "$widgetID-$newrecordindex" unless $nodelete;
		$blankrow->{$deleteFlag} = 1 unless $nodelete;
		foreach my $field ( @{$recset->visibleFields}) {
			$blankrow->{"NAME.".$field} = "$widgetID-".$field.$newrecordindex;
			$blankrow->{"ID.".$field} = "$widgetID-".$field.$newrecordindex;
			$blankrow->{"VALUE.".$field} = '';

			if ($recset->validator($field)) {
				my $rule = $recset->validator($field);
				$rule->{label} = $recset->label($field);
				$validator->{"$widgetID-".$field.$newrecordindex} = $rule;
			}
		}

		push @$bodyRowLoop, $blankrow;

		$self->{_validator} = $validator;

		$tmplvars->{$tableCaptionVar}	= $tableCaptionValue;
		$tmplvars->{$headingLoopVar}	= \@headings;
		$tmplvars->{$bodyRowLoopVar}	= $bodyRowLoop;
			
	} elsif ($type eq 'single')  {
		if (scalar @{$recset->data} > 1) {
			unless ($vars->{multiType} eq 'sequential') { #there are configurations where we don't want to display multi
				$self->{_multi} = 1;
				return $self->displaySingleList;
			}
		} elsif (scalar @{$recset->data} == 0) {
			$self->{_empty} = 1;
		}

		my $recordnum = 0; #which record of a multiple return to display, if we're not doing displaySingleList
		
		foreach my $field (keys %{$args{vars}}) {
			if ($field eq '-recordnum') {
				$recordnum = $args{vars}->{$field};
			} elsif ($args{vars}->{$field}->{handle}) {
				my $ref = $args{vars}->{$field}->{handle};
				$$ref = $recset->data->[$recordnum]->{$field};
			}
		}

		my $ID = $recset->data->[$recordnum]->{$recset->primarykey} || '';

		if ($args{mode} eq 'blank') {
			foreach my $fieldname (keys %{$recset->fieldlist}) {
				unless ($recset->hidden($fieldname)) {
					$tmplvars->{'LABEL.'.$fieldname} = $recset->label($fieldname) unless $recset->noLabel($fieldname);
					$tmplvars->{'NAME.'.$fieldname} = "$widgetID-:INSERT:".$fieldname;
					$tmplvars->{"ID.".$fieldname} = "$widgetID-".$fieldname;
				}
			}
		} else {
			foreach my $fieldname (keys %{$recset->fieldlist}) {
				if ($recset->handle($fieldname)) { #if we've been given a handle for this field, set it
					${$recset->handle($fieldname)} = $recset->data->[$recordnum]->{$fieldname};			
				}
				unless ($recset->hidden($fieldname)) {
					$tmplvars->{'LABEL.'.$fieldname} = $recset->label($fieldname) unless $recset->noLabel($fieldname);
					$tmplvars->{'NAME.'.$fieldname} = "$widgetID-:UPDATE:".$fieldname."-:-".$ID;
					$tmplvars->{"ID.".$fieldname} = "$widgetID-".$fieldname;

					if ($recset->outputMask($fieldname)) {
						$tmplvars->{"VALUE.".$fieldname} = sprintf $recset->outputMask($fieldname), $recset->data->[$recordnum]->{$fieldname}; 
					} else {
						$tmplvars->{"VALUE.".$fieldname} = $recset->data->[$recordnum]->{$fieldname};
					}
				}
			}
		}
	}

	foreach my $extra (keys %{$self->vars->{extravars}} ) {
		my $type = $self->vars->{extravars}->{$extra}->{type};
		if (ref $self->vars->{extravars}->{$extra}->{value} ) {
			$tmplvars->{"NAME.$extra"} = "$widgetID-$extra";
			$tmplvars->{"ID.$extra"} = "$widgetID-$extra";
			$tmplvars->{"VALUE.$extra"} = ${$self->vars->{extravars}->{$extra}->{value}};
		} else {
			$tmplvars->{"NAME.$extra"} = "$widgetID-$extra";
			$tmplvars->{"ID.$extra"} = "$widgetID-$extra";
			$tmplvars->{"VALUE.$extra"} = $self->vars->{extravars}->{$extra}->{value};
		}
	}

	my $divopen = $args{nodiv} ? '' : "<div id='$widgetID'>";
	my $divclose = $args{nodiv} ? '' : "</div>";
	$validator = $self->jswrap("var ".$self->widgetID ."Validator = ".to_json($self->validator).";");
	my $primarykey = $self->recordset->primarykey;

	my $rawwidgetjs = $self->widgetjs;
	$rawwidgetjs =~ s/__WIDGETID__/$widgetID/g;
	$rawwidgetjs =~ s/__PARENTID__/$parentID/g;
	$rawwidgetjs =~ s/__PRIMARYKEY__/$primarykey/;

	my $widgetjs = $self->jswrap(minify(input => $rawwidgetjs));

	return $divopen.
		$validator.
		$widgetjs.
		$formOpenTag.
		$self->q->template($template)->process($tmplvars).
		$formCloseTag.
		$divclose;
}

#----------------------------------------------------------------------------------------
sub display {
	my $self = shift;
	my %args = @_;

 	my $preloadLookup = $self->preloadLookup;
	
	return $preloadLookup.
		$self->contents(%args);
}

#----------------------------------------------------------------------------------------
sub displaySingleList {
	my $self = shift;
	my %args = @_;

        my $standalone 		= $self->vars->{standalone};
	my $formOpenTag 	= '';
	my $formCloseTag 	= '';
        my $widgetID		= $self->vars->{id};
	my $recset = $self->recordset;
	my @fieldlist = $recset->multipleFieldList;
	my @labels = $recset->multipleFieldLabels;

        my $surroundingDivName	=         "DIV.MAIN";
        my $tableCaptionVar   	=         "CAPTION";
        my $headingLoopVar  	=         "HEADING.LOOP";
        my $headingItemVar   	=         "HEADING.ITEM";
        my $bodyRowLoopVar    	=         "ROW.LOOP";
        my $bodyRowName       	=         "ROW";
	
	if ($standalone) {
		$formOpenTag = $self->vars->{formOpenTag} || $self->q->start_form({-method => 'post', -action => $self->q->url});
		$formCloseTag = $self->q->end_form;
	}

	my @headings = map {{$headingItemVar => $_}} $recset->multipleFieldLabels;

	my $bodyRowLoop = [];

	my $primarykey = $recset->primarykey;

	foreach my $record (@{$recset->data}) {
		my $row = {};
		my $ID = $record->{$primarykey} || '';

		foreach my $field (keys %{$record}) {
			if ($recset->multipleField($field)) {
				$row->{"VALUE.".$field} = "<a href= \"javascript:$widgetID"."Controller.multiSearch('$ID');\">".$record->{$field}."</a>";
			}
		}

		push @$bodyRowLoop, $row;
	}

	my $tmplvars = {
		$headingLoopVar	=> \@headings,
		$bodyRowLoopVar	=> $bodyRowLoop,

	};

	my $divopen = $args{nodiv} ? '' : "<div id='$widgetID'>";
	my $divclose = $args{nodiv} ? '' : "</div>";

	return $divopen.
		$formOpenTag.
		$self->q->template($self->vars->{multipleTemplate})->process($tmplvars).
		$formCloseTag.
		$divclose;
}

#----------------------------------------------------------------------------------------
sub empty {
	my $self = shift;

	return $self->{_empty};
}

#----------------------------------------------------------------------------------------
sub multi {
	my $self = shift;

	return $self->{_multi};
}

#----------------------------------------------------------------------------------------
sub new {
	my $class = shift;
	my $q = shift;
	my $vars = shift;
	
	my $self = {
			_q => $q,
			_vars => $vars, 
			_type => $vars->{type}, 
			_multiType => $vars->{multiType}, 
			_recordset => $vars->{recordset}, 
			_widgetjs => $widgetjs, 
			_widgetID => $vars->{id}
	};

	bless $self, $class;

	$self->buildvalidator;
	
	return $self;
}

#----------------------------------------------------------------------------------------
sub searchResults {
	my $self = shift;
	my %args = @_;

	my $html = $self->rawContents(%args);

	my $outgoing = '{"validator" : '.$self->validator.', "html" : "'.$html.'"}';    

	return $outgoing;
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

CGI::Lazy::Ajax::Dataset

=head1 SYNOPSIS

use CGI::Lazy;

our $q = CGI::Lazy->new({

				tmplDir 	=> "/templates",

				jsDir		=>  "/js",

				plugins 	=> {

					mod_perl => {

						PerlHandler 	=> "ModPerl::Registry",

						saveOnCleanup	=> 1,

					},

					ajax	=>  1,

					dbh 	=> {

						dbDatasource 	=> "dbi:mysql:somedatabase:localhost",

						dbUser 		=> "dbuser",

						dbPasswd 	=> "letmein",

						dbArgs 		=> {"RaiseError" => 1},

					},

					session	=> {

						sessionTable	=> 'SessionData',

						sessionCookie	=> 'frobnostication',

						saveOnDestroy	=> 1,

						expires		=> '+15m',

					},

				},

			});



my $widget = $q->ajax->dataset({

			id		=> 'detailBlock',

			type		=> 'multi',

			template	=> "UsbInternalPOCDetailBlock.tmpl",

#						nodelete	=> 1,

			lookups		=> {

					prodcodeLookup  => {

						sql 		=> 'select ID, description from prodCodeLookup', 

						preload 	=> 1,

						orderby		=> ['ID'],

						output		=> 'hash',

						primarykey	=> 'ID',

					},

						

			},

			recordset	=> $q->db->recordset({

						table		=> 'detail', 

						fieldlist	=> [

									{name => 'detail.ID', 

										hidden => 1},

									{name => 'invoiceid', 

										hidden => 1},

									{name => 'prodCode', 

										label => 'Product Code', 

										validator => {rules => ['/\d+/'], msg => 'number only, and is required'}},

									{	name 		=> 'quantity', 

										label 		=> 'Quantity', 

										validator 	=> {rules => ['/\d+/'], msg => 'number only, and is required'},

										outputMask	=> "%.1f",

									},

									{name => 'unitPrice', 

										label 		=> 'Unit Price' , 

										validator 	=> {rules => ['/\d+/'], msg => 'number only, and is required'},

										inputMask	=> "%.1f",

										},

									{name => 'productGross', 

										label => 'Product Gross' , 

										validator => {rules => ['/\d+/'], msg => 'number only, and is required'}},

									{name => 'prodCodeLookup.description', 

										label => 'Product Description', 

										readOnly => 1 },

									], 

						where 		=> '', 

						joins		=> [

									{type => 'inner', table	=> 'prodCodeLookup', field1 => 'prodCode', field2 => 'prodCodeLookup.ID',},

						],

						orderby		=> 'detail.ID', 

						primarykey	=> 'detail.ID',

			}),
	}),

=head1 DESCRIPTION

CGI::Lazy::Ajax::Dataset is, at present, the crown jewel of the CGI::Lazy framework, and the chief reason why the framework was written.  Lazy was written because the author has been asked to write front ends to simple databases so often that he started to realize he was writing the same damn code over and over again, and finally got sick of it.

When we're talking about web-based access to a database, there really aren't many operations that we are talking about performing.  It all comes down to Select, Insert, Update, and Delete (and Ignore- but more on that later).  From the standpoint of the database, it doesn't matter what the data is pertaining to, it could be cardiac patients, or tootsie rolls- the data is still stored in tables, rows and fields, and no matter what you need to read it, modify it, extend it, or destroy it.

The Dataset is designed to, given a set of records, defined by a CGI::Lazy::DB::Recordset object, display that recordset to the screen in whatever manner you like (determined by template and css)  and then keep track of the data.  It's smart enough to know if a record was retrieved from the db, and therefore should be updated or deleted, or if it came from the web, it must be inserted (or ignored, if it was created clientside, and then subsequently deleted clientside- these records will show on the screen, but will be ignored on submit).

Furthermore, as much of the work as possible is done clientside to cut down on issues caused by network traffic.  It's using AJAX and JSON, but there's no eval-ing.  All data is passed into the browser as JSON, and washed though a JSON parser. 

To do it's magic, the Dataset relies heavily on javascript that *should* work for Firefox and IE6.  At the time of publication, all funcitons and methods work flawlessly with FF2, FF3, and IE6.  The author has tried to write for W3C standards, and provide as much IE support as his corporate sponsors required.  YMMV.  Bug reports are always welcome, however we will not support IE to the detrement of W3C standards.  Get on board M$.


The API for Lazy, Recordset, and Dataset allows for hooking simple widgets together to generate not-so-simple results, such as pages with Parent/Child 1 to Many relationships between the Datasets.  CGI::Lazy::Composite is a wrapper designed to connect Dataset objects together.


=head1 METHODS


=head2 contents (args)

Generates widget contents based on args.

=head3 args

Hash of arguments.  Common args are mode => 'blank', for displaying a blank data entry form, and nodiv => 1, for sending the contents back without the surrounding div tags (javascript replaces the contents of the div, and we don't want to add another div of the same name inside the div).


=head2 display (args)

Displays the widget initially.  Calls $self->contents, and adds preload lookups and instance specific javascript that will not be updated on subsequent ajax calls.

=head3 args

Hash of arguments


=head2 displaySingleList (args)

Handler for displaying data when a search returns multiple records.  Displays multipleTemplate rather than template.

=head3 args

Hash of arguments.


=head2 empty ()

Returns the empty property.  Property gets set when a search returns nothing.


=head2 multi ()

Returns multi property.  Multi gets set when a search returns more than one record.


=head2 new (q, vars)

Constructor.

=head3 q

CGI::Lazy object.

=head3 vars

Hashref of object configs.

id			=> widget id 			(manditory)

template		=> standard template		(manditory)

multipleTemplate 	=> 				(manditory if your searches could ever return multiple results)

recordset	=> CGI::Lazy::RecordSet			(manditory)

lookups			=> 				(optional)

	countryLookup =>	name of lookup 

		sql 		=> sql

		preload 	=> 1 (0 means no preload, will have to be run via ajax)

		orderby		=> order by clause

		output		=> type of output (see CGI::Lazy::DB)

		primarykey	=> primary key

extravars		=>  Extra variables to be output to template	(optional)  		

			name	=> name of variable

				value => variable, string, or reference
=cut

