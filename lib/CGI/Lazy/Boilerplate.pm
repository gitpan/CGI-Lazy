package CGI::Lazy::Boilerplate;

use strict;
use warnings;

use CGI::Lazy::Globals;

our $datasetMultipleStart = <<END;
<table id="__WIDGETID__Table">
	<caption> <tmpl_var name="CAPTION"> </caption>
	<tr>
		<tmpl_loop name='HEADING.LOOP'>
			<th> <tmpl_var name='HEADING.ITEM'> </th>
		</tmpl_loop>
	</tr>
	<tmpl_loop name='ROW.LOOP'>
		<tr id="<tmpl_var name="ROW">">
END

our $tdPrototypeMulti = <<END;
				<td>
					<input 
						type="text" 
						name="<tmpl_var name='NAME.__FIELDNAME__'>" 
						value="<tmpl_var name='VALUE.__FIELDNAME__'>" 
						id="<tmpl_var name='ID.__FIELDNAME__'>"
						onchange="__WIDGETID__Controller.unflag(this);__WIDGETID__Controller.pushRow(this);" 
					/>
				</td>
END

our $tdPrototypeMultiRO = <<END;
				<td>
					<tmpl_var name='VALUE.__FIELDNAME__'>
				</td>
END

our $tdPrototypeSingle = <<END;
		<td>
			<input 
				type="text" 
				name="<tmpl_var name='NAME.__FIELDNAME__'>" 
				value="<tmpl_var name='VALUE.__FIELDNAME__'>" 
				id="<tmpl_var name='ID.__FIELDNAME__'>"
				onchange="__WIDGETID__Controller.unflag(this);" 
			/>
		</td>
END

our $datasetDeleteTd = <<END;
				<tmpl_if name="DELETE.FLAG">
				<td>
					<input 
						type = 'checkbox' 
						tabindex=-1 
						id = "<tmpl_var name = 'DELETE.ID'>" 
						onclick="__WIDGETID__Controller.deleteRow(this);"
					>
				</td>
				</tmpl_if>
END

our $datasetMultipleEnd = <<END;
		</tr>
	</tmpl_loop>
</table>
END

our $cssClean = <<END;
div#__WIDGETID__ {

}

END

our $datasetSingleStart = <<END;
<table id="__WIDGETID__.table">
END

our $datasetSingleRowStart = <<END;
	<tr>
END

our $datasetSingleLableTd = <<END;
		<td 
			id="__FIELDNAME__Label">
			<tmpl_var name="LABEL.__FIELDNAME__">
		</td>
END

our $datasetSingleRowEnd = <<END;
	</tr>

END

our $datasetSingleEnd = <<END;
		
</table>

END

our $datasetMultipleHeaderStart = <<END;
<div id="__WIDGETID__">
	<table>
		<caption> <tmpl_var name="CAPTION"> </caption>
		<tr>

END

our $datasetMultipleHeaderTd = <<END;
			<th class="pathwidgetheader"> 
				<tmpl_var name="HEADING.ITEM.__FIELDNAME__"> 
			</th>

END

our $datasetMultipleHeaderDeleteTd = <<END;
			<th class="pathwidgetheader"> 
				<tmpl_var name="HEADING.ITEM.DELETE"> 
			</th>

END

our $datasetMultipleHeaderEnd = <<END;
		</tr>


	</table>
</div>


END
#--------------------------------------------------------------------------------------------
sub buildCss	{
	my $self = shift;
	
	my $style = $self->style || 'clean';
	my $method = "buildCss". join "", map {s/^\s+//; s/\s+$//; ucfirst } split ",", $style;

	$self->$method;

}

#--------------------------------------------------------------------------------------------
sub buildCssClean {
	my $self = shift;
	
	$self->outputCss($self->parse4ID($cssClean));
}

#--------------------------------------------------------------------------------------------
sub buildTmplDatasetMultiple {
	my $self = shift;

	my $tmpl = $self->parse4ID($datasetMultipleStart);
	$tmpl .= $self->parse4FieldAndID($_, $tdPrototypeMulti) for @{$self->fieldlist};
	$tmpl .= $self->parse4ID($datasetDeleteTd);
	$tmpl .= $self->parse4ID($datasetMultipleEnd);

	$self->outputTmpl($tmpl);
}

#--------------------------------------------------------------------------------------------
sub buildTmplDatasetMultipleHeadings {
	my $self = shift;

	my $tmpl = $self->parse4ID($datasetMultipleHeaderStart);
	$tmpl .= $self->parse4Field($_, $datasetMultipleHeaderTd) for @{$self->fieldlist};
	$tmpl .= $self->parse4ID($datasetMultipleHeaderDeleteTd);
	$tmpl .= $self->parse4ID($datasetMultipleHeaderEnd);

	$self->outputTmpl($tmpl, 'HDR');
}

#--------------------------------------------------------------------------------------------
sub buildTmplDatasetMultipleRO {
	my $self = shift;

	my $tmpl = $self->parse4ID($datasetMultipleStart);
	$tmpl .= $self->parse4FieldAndID($_, $tdPrototypeMultiRO) for @{$self->fieldlist};
	$tmpl .= $self->parse4ID($datasetMultipleEnd);

	$self->outputTmpl($tmpl, 'RO');
}

#--------------------------------------------------------------------------------------------
sub buildTmplDatasetSingle {
	my $self = shift;

	my $widgetID 	= $self->widgetID;
	my $fieldlist 	= $self->fieldlist;
	my $fields 	= scalar @$fieldlist;
	my $rows 	= ($fields / 5 == int $fields) ? $fields / 5 : int $fields / 5 + 1;

	my $tmpl = $self->parse4ID($datasetSingleStart);

	my $field = 0;
	for (my $i = 0; $i < $rows; $i++) {
		my $column = 0;
		$tmpl .= $datasetSingleRowStart;
		while ($column < 6) {
			if ($fieldlist->[$field]) {
				$tmpl .= $self->parse4Field($fieldlist->[$field], $datasetSingleLableTd);
				$tmpl .= $self->parse4Field($fieldlist->[$field], $self->parse4ID($tdPrototypeSingle));
			}
			$column++;
			$field++;
		}

		$tmpl .= $datasetSingleRowEnd;

	}

	$tmpl .= $self->parse4ID($datasetSingleEnd);

	$self->outputTmpl($tmpl);
}

#--------------------------------------------------------------------------------------------
sub buildTmplDatasetSingleMulti {
	my $self = shift;

	my $tmpl = $self->parse4ID($datasetMultipleStart);
	$tmpl .= $self->parse4Field($_, $tdPrototypeMulti) for @{$self->fieldlist};
	$tmpl .= $self->parse4ID($datasetMultipleEnd);

	$self->outputTmpl($tmpl, 'Multi');
}
#--------------------------------------------------------------------------------------------
sub buildTemplate {
	my $self = shift;
	
	my $method = "buildTmpl". join "", map {s/^\s+//; s/\s+$//; ucfirst } split ",", $self->type;

	$self->$method;
}

#--------------------------------------------------------------------------------------------
sub fieldlist {
	my $self = shift;

	return $self->{_fieldlist};
}

#--------------------------------------------------------------------------------------------
sub new {
	my $class = shift;
	my $args = shift;

	my $self = {
		_widgetID 	=> $args->{id} || $args->{ID},
		_fieldlist	=> $args->{fieldlist},
		_widgetType	=> $args->{type},
		_style		=> $args->{style},

	};

	return bless $self, $class;
}

#--------------------------------------------------------------------------------------------
sub output {
	my $self = shift;
	my $text = shift;
	my $type = shift;
	my $extra = shift;

	my $file = $self->widgetID;
	$file .= $extra if $extra;
	$file .=".$type";

	open OF, "+> $file" or die "Couldn't open $file for writing: $!";
	print OF $text;
	close OF;
}

#--------------------------------------------------------------------------------------------
sub outputCss {
	my $self = shift;
	my $text = shift;

	$self->output($text, "css");
}

#--------------------------------------------------------------------------------------------
sub outputTmpl {
	my $self = shift;
	my $text = shift;
	my $type = shift;

	$self->output($text, "tmpl", $type);
}

#--------------------------------------------------------------------------------------------
sub parse4ID {
	my $self = shift;
	my $text = shift;
	
	my $widgetID = $self->widgetID;

	$text =~ s/__WIDGETID__/$widgetID/gs;

	return $text;
}

#--------------------------------------------------------------------------------------------
sub parse4Field {
	my $self 	= shift;
	my $fieldname	= shift;
	my $text 	= shift;

	$text =~ s/__FIELDNAME__/$fieldname/gs;

	return $text;
}

#--------------------------------------------------------------------------------------------
sub parse4FieldAndID {
	my $self 	= shift;
	my $fieldname	= shift;
	my $text 	= shift;

	$text = $self->parse4Field($fieldname, $text);
	$text = $self->parse4ID($text);

	return $text;
}

#--------------------------------------------------------------------------------------------
sub style {
	my $self = shift;

	return $self->{_style};
}

#--------------------------------------------------------------------------------------------
sub type {
	my $self = shift;

	return $self->{_widgetType};
}
#--------------------------------------------------------------------------------------------
sub widgetID {
	my $self = shift;

	return $self->{_widgetID};
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

CGI::Lazy::BoilerPlate

=head1 SYNOPSIS

	use CGI::Lazy::Boilerplate;

	my $b1 = CGI::Lazy::Boilerplate->new({

			id      => 'frobnitz',

			fieldlist       => [qw(prodCode quantity unitPrice productGross prodCodeLookup.description)],

			type            => 'dataset, multiple',

			style		=> 'funkystyle', #unsupported as of yet

			});

	$b1->buildTemplate;

	$b1->buildCss;

	my $b2 = CGI::Lazy::Boilerplate->new({

			id              => 'glortswaggle',

			fieldlist       => [qw(merchant batch post_date cardnum tailno authCode icao invoicenum invtotal trandate country countryname)],

			type            => 'dataset, single',

			});

	$b2->buildTemplate;

	$b2->buildCss;

	my $b3 = CGI::Lazy::Boilerplate->new({

			id	 	=> 'glortswaggle',

			fieldlist	=> [qw(merchant batch post_date cardnum tailno )],

			type		=> 'dataset, singleMulti',

			});

	$b3->buildTemplate;


=head1 DESCRIPTION

CGI::Lazy::Boilerplate is a module to generate boilerplate template examples for Lazy widgets.  The templates generated can then be customized to do whatever you want, and look like whatever you want.  Some pieces of template syntax might be confusing to users of Lazy, so this will generate a nice starting point for you.

=head1 METHODS

=head2 buildCss ()

Builds a prototype css file of style set in object creation for widget in question, or a blank style if none is specified.


=head2 buildCssClean ()

Builds clean css file for widget.
	

=head2 buildTemplate ()

Builds a template appropriate for widget of type specified in object creation.

=cut

