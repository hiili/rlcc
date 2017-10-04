/*
 * A Seed Fill Algorithm
 * by Paul Heckbert
 * from "Graphics Gems", Academic Press, 1990
 *
 * user provides pixelread() and pixelwrite() routines
 */

/*
 * fill.c : simple seed fill program
 * Calls pixelread() to read pixels, pixelwrite() to write pixels.
 *
 * Paul Heckbert	13 Sept 1982, 28 Jan 1987
 */

#include "SeedFill.hpp"
#include "mex.h"


SFPixel pixelread( Board board, int x, int y )
{
  return board[y][x];
}

void pixelwrite( Board board, int x, int y, SFPixel nv )
{
  board[y][x] = nv;
}


typedef struct {short y, xl, xr, dy;} Segment;
/*
 * Filled horizontal segment of scanline y for xl<=x<=xr.
 * Parent segment was on line y-dy.  dy=1 or -1
 */

#define MAX 1000		/* max depth of stack */

#define PUSH(Y, XL, XR, DY)	/* push new segment on stack */ \
    if (sp<stack+MAX && Y+(DY)>=win->y0 && Y+(DY)<=win->y1) \
    {sp->y = Y; sp->xl = XL; sp->xr = XR; sp->dy = DY; sp++;}

#define POP(Y, XL, XR, DY)	/* pop segment off stack */ \
    {sp--; Y = sp->y+(DY = sp->dy); XL = sp->xl; XR = sp->xr;}

/*
 * fill: set the pixel at (x,y) and all of its 4-connected neighbors
 * with the same pixel value to the new pixel value nv.
 * A 4-connected neighbor is a pixel above, below, left, or right of a pixel.
 */

void SeedFill(Board board, int rows, int columns, int x, int y, SFWindow *win, SFPixel nv)
{
    mxAssert( rows == ROWS && columns == COLUMNS, "rows and columns must be 20 and 10!" );
    
    int l, x1, x2, dy;
    SFPixel ov;	/* old pixel value */
    Segment stack[MAX], *sp = stack;	/* stack of filled segments */

    ov = pixelread(board, x, y);		/* read pv at seed point */
    if (ov==nv || x<win->x0 || x>win->x1 || y<win->y0 || y>win->y1) return;
    PUSH(y, x, x, 1);			/* needed in some cases */
    PUSH(y+1, x, x, -1);		/* seed segment (popped 1st) */

    while (sp>stack) {
	/* pop segment off stack and fill a neighboring scan line */
	POP(y, x1, x2, dy);
	/*
	 * segment of scan line y-dy for x1<=x<=x2 was previously filled,
	 * now explore adjacent pixels in scan line y
	 */
	for (x=x1; x>=win->x0 && pixelread(board, x, y)==ov; x--)
	    pixelwrite(board, x, y, nv);
	if (x>=x1) goto skip;
	l = x+1;
	if (l<x1) PUSH(y, l, x1-1, -dy);		/* leak on left? */
	x = x1+1;
	do {
	    for (; x<=win->x1 && pixelread(board, x, y)==ov; x++)
		pixelwrite(board, x, y, nv);
	    PUSH(y, l, x-1, dy);
	    if (x>x2+1) PUSH(y, x2+1, x-1, -dy);	/* leak on right? */
skip:	    for (x++; x<=x2 && pixelread(board, x, y)!=ov; x++);
	    l = x;
	} while (x<=x2);
    }
}
