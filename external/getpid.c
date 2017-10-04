/* From Matlab Central, Peter Boettcher: http://www.mathworks.com/matlabcentral/newsreader/view_thread/106613 */

#include <sys/types.h>
#include <unistd.h>
#include "mex.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  unsigned int *pr;

  plhs[0] = mxCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
  pr = mxGetData(plhs[0]);
  *pr = (unsigned int)getpid();
}
