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

#ifdef REGION_CLASS

RegionStyle(block,RegBlock)

#else

#ifndef LMP_REGION_BLOCK_H
#define LMP_REGION_BLOCK_H

#include "region.h"

namespace LAMMPS_NS {

class RegBlock : public Region {
  friend class FixPour;
  friend class FixPourLegacy; 
  friend class FixPourDev; 
  friend class FixPourDevRegionupdate; 

 public:
  RegBlock(class LAMMPS *, int, char **);
  ~RegBlock();
  int inside(double, double, double);
  int surface_interior(double *, double);
  int surface_exterior(double *, double);

 private:
  double xlo,xhi,ylo,yhi,zlo,zhi;
};

}

#endif
#endif
