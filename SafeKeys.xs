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

int save_iterator_state(HV* hv)
{
    int i;
    iterator_state *state = malloc(sizeof(iterator_state));
    initialize();
    if (hv == (HV*) 0) {
	/* warn */
	return -1;
    }

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

void restore_iterator_state(HV* hv, int i)
{
    iterator_state *state = STATES[i];
    initialize();
    if (i < 0 || i >= STATES_size) {
	/* warn */
	return;
    }
    if (state != (iterator_state*) 0) {
	HvRITER(hv) = state->riter;
	HvEITER(hv) = state->eiter;
	free(state);
    } else {
	/* warn */
    }
    STATES[i] = (iterator_state*) 0;
}


MODULE = Hash::SafeKeys		PACKAGE = Hash::SafeKeys	

int
save_iterator_state (hv)
	HV *	hv

void
restore_iterator_state (hv, i)
	HV *	hv
	int	i
	PREINIT:
	I32* temp;
	PPCODE:
	temp = PL_markstack_ptr++;
	restore_iterator_state(hv, i);
	if (PL_markstack_ptr != temp) {
          /* truly void, because dXSARGS not invoked */
	  PL_markstack_ptr = temp;
	  XSRETURN_EMPTY; /* return empty stack */
        }
        /* must have used dXSARGS; list context implied */
	return; /* assume stack size is correct */

