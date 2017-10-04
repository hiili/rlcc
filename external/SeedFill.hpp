/*
 * A Seed Fill Algorithm
 * by Paul Heckbert
 * from "Graphics Gems", Academic Press, 1990
 *
 * user provides pixelread() and pixelwrite() routines
 *
 * (this header file, along with some renamings, were added to the original implementation)
 */
#ifndef SEEDFILL_HPP
#define SEEDFILL_HPP


#define ROWS 20
#define COLUMNS 10


typedef bool Board[ROWS][COLUMNS];

typedef struct {		/* window: a discrete 2-D rectangle */
    int x0, y0;			/* xmin and ymin */
    int x1, y1;			/* xmax and ymax (inclusive) */
} SFWindow;

typedef bool SFPixel;		/* 1-channel frame buffer assumed */

void SeedFill(Board board, int rows, int columns, int x, int y, SFWindow *win, SFPixel nv);


#endif
