#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
/*#include "INLINE.h"*/

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


MODULE = Hash::SafeKeys		PACKAGE = Hash::SafeKeys	

int
save_iterator_state (hvref)
	SV *	hvref

void
restore_iterator_state (hvref, i)
	SV *	hvref
	int	i
	PREINIT:
	I32* temp;
	PPCODE:
	temp = PL_markstack_ptr++;
	restore_iterator_state(hvref, i);
	if (PL_markstack_ptr != temp) {
          /* truly void, because dXSARGS not invoked */
	  PL_markstack_ptr = temp;
	  XSRETURN_EMPTY; /* return empty stack */
        }
        /* must have used dXSARGS; list context implied */
	return; /* assume stack size is correct */

