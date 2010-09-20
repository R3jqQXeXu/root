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

#ifndef NVC_DEVICE
#define NVC_DEVICE

#include <string>
#include <vector>
#include <iostream>

using namespace std;

/// Class for looking at device properties
/** \note Calls to change the device outside of the class results in incorrect
  *       behavior 
  * \note There is no error checking for indexing past the number of devices
  * \note init() at least once before using any of the routines **/
class NVCDevice {
 public:
  /// Grabs the properties for all devices
  /** \note init() must be called following construction before any routines **/
  NVCDevice() {}

  /// Collect properties for every GPU on the node and set active GPU to ID 0
  void init();

  /// Return the number of devices that support CUDA
  inline int num_devices() { return _properties.size(); }

  /// Set the CUDA device to the specified device number
  void set(int num);

  /// Get the current device number
  inline int device_num() { return _device; }

  /// Get the current CUDA device name
  inline string name() { return name(_device); }
  /// Get the CUDA device name
  inline string name(const int i) { return string(_properties[i].name); }

  /// Get the number of cores in the current device
  inline unsigned cores() { return cores(_device); }
  /// Get the number of cores
  inline unsigned cores(const int i) 
    { return _properties[i].multiProcessorCount*8; }
  
  /// Get the gigabytes of global memory in the current device
  inline double gigabytes() { return gigabytes(_device); }
  /// Get the gigabytes of global memory
  inline double gigabytes(const int i) 
    { return static_cast<double>(_properties[i].totalGlobalMem)/1073741824; }
  
  /// Get the bytes of global memory in the current device
  inline size_t bytes() { return bytes(_device); }
  /// Get the bytes of global memory
  inline size_t bytes(const int i) { return _properties[i].totalGlobalMem; }

  /// Return the GPGPU revision number for current device
  inline double revision() { return revision(_device); }
  /// Return the GPGPU revision number
  inline double revision(const int i) 
    { return static_cast<double>(_properties[i].minor)/10+_properties[i].major;}
  
  /// Clock rate in GHz for current device
  inline double clock_rate() { return clock_rate(_device); }
  /// Clock rate in GHz
  inline double clock_rate(const int i) { return _properties[i].clockRate*1e-6;}
               
  /// List all devices along with all properties
  void print_all(ostream &out);
 
 private:
  int _device, _num_devices;
  vector<cudaDeviceProp> _properties;
};

#endif
