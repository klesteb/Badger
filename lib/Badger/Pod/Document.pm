#========================================================================
#
# Badger::Pod::Document
#
# DESCRIPTION
#   Object respresenting a Pod document.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Document;

use Badger::Pod 'POD';
use Badger::Debug ':dump';
use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Base',
    filesystem  => 'File',
    get_methods => 'text file name',
    constants   => 'SCALAR LAST',
    constant    => {
        TEXT_NAME => '<input text>',
    },
    messages   => {
        no_input => 'No text or file parameter specified',
    };

our $TEXT_NAME = '<input text>';


sub init {
    my ($self, $config) = @_;
    my ($text, $file, $name, $nodes);
    
    if ($file = $config->{ file }) {
        $file = File($file);
        $self->{ file } = $file;
        $self->{ text } = $file->text;
        $self->{ name } = $file->name;
    }
    elsif ($text = $config->{ text }) {
        $self->{ text } = ref $text eq SCALAR
            ? $$text 
            :  $text . '';  # force stringification of text objects
        $self->{ name } = $self->TEXT_NAME;
    }
    else {
        return $self->error_msg('no_input');
    }

    # augment and store the config so we can pass it to parsers later
    $config->{ name } = $self->{ name };
    $self->{ config } = $config;
    
    return $self;
}

sub blocks {
    my $self = shift;
    $self->{ blocks } 
        ||= POD->blocks($self->{ config })->parse($self->{ text });
}

sub model {
    my $self = shift;
    $self->{ model } 
        ||= POD->model($self->{ config })->parse($self->{ text });
}


__END__

sub focus {
    my $self = shift;
    push(@{ $self->{ stack } }, @_) if @_;
    return $self->{ stack }->[LAST];
}

sub add_focus {
    my $self  = shift;
    my $stack = $self->{ stack };
    my $node  = $stack->[LAST]->add(@_);
    push(@$stack, $node);
    return $node;
}

sub blur {
    pop(@{ $_[0]->{ stack } });
}

sub parse_code {
    my ($self, $text, $line) = @_;
    $self->debug("<pod:code\@$line>$text</pod:code>\n") if $DEBUG;
    $self->focus->add(
        code => { 
            text => $text, 
            line => $line 
        } 
    );
}

sub parse_command {
    my ($self, $name, $text, $line) = @_;
    $self->debug("<pod:command\@$line>=$name$text</pod:command>\n") if $DEBUG;
    my $body = $self->SUPER::parse_paragraph($text, $line);
    $self->focus->add(
        command => {
            name => $name,
            text => '=' . $name . $text, 
            line => $line,
            body => $body,
        } 
    );
}

sub parse_verbatim {
    my ($self, $text, $line) = @_;
    $self->debug("<pod:verbatim\@$line>$text</pod:verbatim>\n") if $DEBUG;
    $self->focus->add(
        verbatim => {
            text => $text, 
            line => $line,
        } 
    );
}    

sub parse_paragraph {
    my ($self, $text, $line) = @_;
    $self->debug("<pod:paragraph\@$line>$text</pod:paragraph>\n") if $DEBUG;
    my $body = $self->SUPER::parse_paragraph($text, $line);
    $self->focus->add(
        paragraph => { 
            text => $text, 
            line => $line,
            body => $body,
        } 
    );
}

sub parse_format {
    my ($self, $name, $lparen, $rparen, $line, $content) = @_;
    $self->debug("<pod:format\@$line>$name$lparen...$rparen</pod:format>\n") if $DEBUG;
    return [$name, $lparen, $rparen, $line, $content];
}

1;