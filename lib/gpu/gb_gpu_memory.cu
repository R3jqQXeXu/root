/* ----------------------------------------------------------------------
   LAMMPS - Large-scale Atomic/Molecular Massively Parallel Simulator
   http://lammps.sandia.gov, Sandia National Laboratories
   Steve Plimpton, sjplimp@sandia.gov

   Copyright (2003) Sandia Corporation.  Under the terms of Contract
   DE-AC04-94AL85000 with Sandia Corporation, the U.S. Government retains
   certain rights in this software.  This software is distributed under 
   the GNU General Public License.

   See the README file in the top-level LAMMPS directory.
------------------------------------------------------------------------- */

/* ----------------------------------------------------------------------
   Contributing authors: Mike Brown (SNL), wmbrown@sandia.gov
                         Peng Wang (Nvidia), penwang@nvidia.com
                         Paul Crozier (SNL), pscrozi@sandia.gov
------------------------------------------------------------------------- */

#include "gb_gpu_memory.h"
#define GB_GPU_MemoryT GB_GPU_Memory<numtyp, acctyp>

template <class numtyp, class acctyp>
GB_GPU_MemoryT::GB_GPU_Memory() : LJ_GPU_MemoryT() {
  this->atom.atom_fields(8); 
  this->atom.ans_fields(13); 
  this->nbor.packing(true);
}

template <class numtyp, class acctyp>
GB_GPU_MemoryT::~GB_GPU_Memory() { 
  clear(); 
}
 
template <class numtyp, class acctyp>
bool GB_GPU_MemoryT::init(const int ij_size, const int ntypes, 
                          const double gamma, const double upsilon, 
                          const double mu, double **host_shape,
                          double **host_well, double **host_cutsq, 
                          double **host_sigma, double **host_epsilon, 
                          double *host_lshape, int **h_form, double **host_lj1, 
                          double **host_lj2, double **host_lj3, 
                          double **host_lj4, double **host_offset, 
                          double *host_special_lj, const int nlocal,
                          const int nall, const int max_nbors, 
                          const bool force_d, const int me) {
  _max_nbors=max_nbors;
  if (this->allocated)
    clear();
    
  bool p=LJ_GPU_MemoryT::init(ij_size,ntypes,host_cutsq,host_sigma,host_epsilon,
                              host_lj1, host_lj2, host_lj3, host_lj4, 
                              host_offset, host_special_lj, max_nbors, me,
                              nlocal, nall);
  if (!p)
    return false;                              
    
  host_form=h_form;
    
  // Initialize timers for the selected GPU
  time_kernel.init();
  time_gayberne.init();
  time_kernel2.init();
  time_gayberne2.init();
    
  // Use the write buffer from atom for data initialization
  NVC_HostT &host_write=this->atom.host_write;
  assert(host_write.numel()>4 && host_write.numel()>ntypes*ntypes*2);

  // Allocate, cast and asynchronous memcpy of constant data
  gamma_upsilon_mu.safe_alloc(3);
  host_write[0]=static_cast<numtyp>(gamma); 
  host_write[1]=static_cast<numtyp>(upsilon);
  host_write[2]=static_cast<numtyp>(mu);
  gamma_upsilon_mu.copy_from_host(host_write.begin());

  lshape.safe_alloc(ntypes,lshape_get_texture<numtyp>());
  lshape.cast_copy(host_lshape,host_write);
  lshape.copy_from_host(host_write.begin());
    
  // Copy shape, well, sigma, epsilon, and cutsq onto GPU
  shape.safe_alloc(ntypes,3,shape_get_texture<numtyp>());
  shape.cast_copy(host_shape[0],host_write);
  well.safe_alloc(ntypes,3,well_get_texture<numtyp>());
  well.cast_copy(host_well[0],host_write);

  // Copy LJ data onto GPU
  int lj_types=ntypes;
  if (lj_types<=MAX_SHARED_TYPES)
    lj_types=MAX_SHARED_TYPES;
  form.safe_alloc(lj_types,lj_types,form_get_texture());
  form.copy_2Dfrom_host(host_form[0],ntypes,ntypes);

  // See if we want fast GB-sphere or sphere-sphere calculations
  multiple_forms=false;
  for (int i=1; i<ntypes; i++)
    for (int j=i; j<ntypes; j++) 
      if (host_form[i][j]!=ELLIPSE_ELLIPSE)
        multiple_forms=true;
        
  // Memory for ilist ordered by particle type
  return host_olist.alloc_rw(this->max_local);
}

template <class numtyp, class acctyp>
void GB_GPU_MemoryT::resize_atom(const int nall, bool &success) {
  this->max_atoms=static_cast<int>(static_cast<double>(nall)*1.10);
  this->atom.resize(this->max_atoms, success);
}

template <class numtyp, class acctyp>
void GB_GPU_MemoryT::resize_local(const int nlocal, const int max_nbors,
                                  bool &success) {
  if (nlocal>this->max_local) {
    this->max_local=static_cast<int>(static_cast<double>(nlocal)*1.10);
    host_olist.clear();
    success=success && host_olist.alloc_rw(this->max_local);
  }
  if (max_nbors>_max_nbors)
    _max_nbors=static_cast<int>(static_cast<double>(max_nbors)*1.10);
  this->nbor.resize(this->max_local,_max_nbors,success);
}

template <class numtyp, class acctyp>
void GB_GPU_MemoryT::clear() {
  if (!this->allocated)
    return;

  int err_flag;
  this->dev_error.copy_to_host(&err_flag);
  if (err_flag == 1)
    std::cerr << "COLLISION BUFFER OVERFLOW OCCURED. INCREASE COLLISION_N "
              << "and RECOMPILE.\n";
  else if (err_flag == 2)
    std::cerr << "BAD MATRIX INVERSION IN FORCE COMPUTATION.\n";  

  LJ_GPU_MemoryT::clear();      
  
  lshape.unbind();

  shape.clear();
  well.clear();
  form.clear();
  lshape.clear();
  gamma_upsilon_mu.clear();
  host_olist.clear();
}  
 
template <class numtyp, class acctyp>
double GB_GPU_MemoryT::host_memory_usage() {
  return this->atom.host_memory_usage(this->max_atoms)+
         this->nbor.host_memory_usage()+4*sizeof(numtyp)+
         sizeof(GB_GPU_Memory<numtyp,acctyp>)+this->max_atoms*sizeof(int);
}

template class GB_GPU_Memory<PRECISION,ACC_PRECISION>;
