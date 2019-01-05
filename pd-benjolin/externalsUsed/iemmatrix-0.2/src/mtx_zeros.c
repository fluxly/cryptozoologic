/*
 *  iemmatrix
 *
 *  objects for manipulating simple matrices
 *  mostly refering to matlab/octave matrix functions
 *
 * Copyright (c) IOhannes m zm�lnig, forum::f�r::uml�ute
 * IEM, Graz, Austria
 *
 * For information on usage and redistribution, and for a DISCLAIMER OF ALL
 * WARRANTIES, see the file, "LICENSE.txt," in this distribution.
 *
 */
#include "iemmatrix.h"

/* mtx_zeros */
static t_class *mtx_zeros_class;
static void *mtx_zeros_new(t_symbol *s, int argc, t_atom *argv)
{
  t_matrix *x = (t_matrix *)pd_new(mtx_zeros_class);
  int col=0, row=0;
  outlet_new(&x->x_obj, 0);
  x->row = x->col = 0;
  x->atombuffer   = 0;
  switch(argc) {
  case 0:
    break;
  case 1:
    col=row=atom_getfloat(argv);
    break;
  default:
    row=atom_getfloat(argv++);
    col=atom_getfloat(argv);
  }
  if(col<0)col=0;
  if(row<0)row=0;
  if (col*row){
    x->atombuffer = (t_atom *)getbytes((col*row+2)*sizeof(t_atom));
    setdimen(x, row, col);
    matrix_set(x, 0);
  }
  return (x);
}
void mtx_zeros_setup(void)
{
  mtx_zeros_class = class_new(gensym("mtx_zeros"), (t_newmethod)mtx_zeros_new, 
			      (t_method)matrix_free, sizeof(t_matrix), 0, A_GIMME, 0);
  class_addlist(mtx_zeros_class, matrix_zeros);
  class_addbang(mtx_zeros_class, matrix_bang);
  class_addmethod(mtx_zeros_class, (t_method)matrix_zeros, gensym("matrix"), A_GIMME, 0);


}
void iemtx_zeros_setup(void){
  mtx_zeros_setup();
}
