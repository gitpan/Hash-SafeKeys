=head1 NAME

Hash::SafeKeys - get hash contents without resetting each iterator

=head1 VERSION

Version 0.03

=cut

=head1 SYNOPSIS

    use Hash::SafeKeys;
    while (my ($k,$v) = each %hash) {
       if (something_interesting_happens()) {
          # get keys, values of %hash without resetting
          # the 'each' iterator above
          my @k = safekeys %hash;
          my @v = safevalues %hash;
          my %copy = safecopy %hash;
       }
    }

=head1 DESCRIPTION

Every hash variable in Perl has its own internal iterator,
accessed by the builtin C<each>, C<keys>, and C<values>
functions. The iterator is also implicitly used whenever
the hash is evaluated in list context.  The iterator is
"reset" whenever C<keys> or C<values> is called on a hash,
including the implicit calls when the hash is evaluated in
list context. That makes it dangerous to do certain hash
operations inside a C<while ... each> loop:

    while (my($k,$v) = each %hash) {
       ...
       @k = sort keys %hash;               # Infinite loop!
       @v = grep { /foo/ }, values %hash;  # Ack!
       print join ' ', %hash;              # Run away!
    }

C<Hash::SafeKeys> provides alternate functions to access
the keys, values, or entire contents of a hash in a way
that does not reset the iterator, making them safe to use
in such contexts:

    while (my($k,$v) = each %hash) {
       ...
       @k = sort safekeys %hash;               # Can do
       @v = grep { /foo/ }, safevalues %hash;  # No problem
       print join ' ', safecopy %hash;         # Right away, sir
    }

=head1 FUNCTIONS

=head2 LIST = safekeys HASH

Like the builtin L<keys|perlfunc/"keys"> function, returns a list
consisting of all the keys of the named hash, in the same order
that the builtin function would return them in. Unlike C<keys>,
calling C<safekeys> does not reset the HASH's internal iterator
(see L<each|perlfunc/"each">).

=head2 LIST = safevalues HASH

Like the builtin L<values|perlfunc/"values"> function, returns a list
consisting of all the values of the named hash, in the same order
that the builtin function would return them in. Unlike C<values>,
calling C<safevalues> does not reset the HASH's internal iterator
(see L<each|perlfunc/"each">).

=head2 LIST = safecopy HASH

In list context, returns a shallow copy of the named HASH without
resetting the HASH's internal iterator. Usually, evaluating a HASH 
in list context implicitly uses the internal iterator, resetting
any existing state. 

=head1 EXPORT

L<"safekeys">, L<"safevalues">, and L<"safecopy"> are all 
exported by default. Invoke L<Hash::SafeKeys> with the empty arg list

    use Hash::SafeKeys ();

if you don't want these functions to be imported into the calling
package.

=head1 AUTHOR

Marty O'Brien, C<< <mob at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-hash-safekeys at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Hash-SafeKeys>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Hash::SafeKeys


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Hash-SafeKeys>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Hash-SafeKeys>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Hash-SafeKeys>

=item * Search CPAN

L<http://search.cpan.org/dist/Hash-SafeKeys/>

=back


=head1 ACKNOWLEDGEMENTS

The C<dclone> method in the L<Storable> module demonstrated how
to save and restore internal hash iterator state.
This module is indebted to the authors of this module and to 
L<< user C<gpojd> at stackoverflow.com|http://stackoverflow.com/a/10921567/168857 >>
for directing me to it.

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Marty O'Brien.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

package Hash::SafeKeys;

use strict;
use warnings;
use base qw(Exporter);
our @EXPORT = qw(safekeys safevalues safecopy);
our $VERSION = '0.03';

# crutch for creating the XS code ...
#use Inline (Config => CLEAN_AFTER_BUILD => 0, FORCE_BUILD => 1, BUILD_NOISY => 1);
#use Inline 'C';

# crutches off
use base qw(DynaLoader); bootstrap Hash::SafeKeys $VERSION;

sub safekeys (\%) {
    my $hash = shift;
    my $state = save_iterator_state($hash);
    my @keys = keys %$hash;
    restore_iterator_state($hash,$state);
    return @keys;
}

sub safevalues (\%) {
    my $hash = shift;
    return map { $hash->{$_} } safekeys(%$hash);
}

sub safecopy (\%) {
    my $hash = shift;
    return map { ($_,$hash->{$_}) } safekeys(%$hash);
}

1;

__DATA__
__C__

#define STATES_INITIAL_SIZE 10

struct _iterator_state {
    I32  riter;
    HE*  eiter;
};
typedef struct _iterator_state iterator_state;

static int module_initialized = 0;
iterator_state **STATES;
int STATES_size;

void initialize()
{
    int i;
    if (module_initialized) return;
    STATES = malloc(STATES_INITIAL_SIZE*sizeof(iterator_state *));
    STATES_size = STATES_INITIAL_SIZE;
    for (i=0; i<STATES_size; i++) {
	STATES[i] = (iterator_state*) 0;
    }
    module_initialized = 1;
}

void resize_STATES()
{
    int i;
    int new_size = STATES_size * 2;
    iterator_state **new_STATES = malloc(new_size*sizeof(iterator_state*));
    for (i=0; i<STATES_size; i++) {
	new_STATES[i] = STATES[i];
    }
    for (; i<new_size; i++) {
	new_STATES[i] = (iterator_state*) 0;
    }
    free(STATES);
    STATES = new_STATES;
    STATES_size = new_size;
}

int save_iterator_state(SV* hvref)
{
    int i;
    if (hvref == (SV*) 0) {
	warn("Hash::SafeKeys::save_iterator_state: null input!");
	return -1;
    }
    HV* hv = (HV*) SvRV(hvref);
    if (hv == (HV*) 0) {
	warn("Hash::SafeKeys::save_iterator_state: null input!");
	return -1;
    }
    iterator_state *state = malloc(sizeof(iterator_state));
    initialize();

    for (i=0; i<STATES_size; i++) {
	if (STATES[i] == (iterator_state*) 0) {
	    break;
	}
    }
    if (i >= STATES_size) {
	resize_STATES();
	i = STATES_size;
    }

    state->riter = HvRITER(hv);
    state->eiter = HvEITER(hv);
    STATES[i] = state;
    hv_iterinit(hv);
    return i;
}

void restore_iterator_state(SV* hvref, int i)
{
    if (hvref == (SV*) 0) {
	warn("Hash::SafeKeys::restore_iterator_state: null input");
	return;
    }
    HV* hv = (HV*) SvRV(hvref);
    if (hv == (HV*) 0) {
	warn("Hash::SafeKeys::restore_iterator_state: null input");
	return;
    }
    iterator_state *state = STATES[i];
    initialize();
    if (i < 0 || i >= STATES_size) {
	warn("Hash::SafeKeys::restore_iterator_state: invalid restore key %d", i);
	return;
    }
    if (state != (iterator_state*) 0) {
	HvRITER(hv) = state->riter;
	HvEITER(hv) = state->eiter;
	free(state);
    } else {
	warn("Hash::SafeKeys::restore_iterator_state: operation failed for key %d", i);
    }
    STATES[i] = (iterator_state*) 0;
}

__END__
