# E. Culurciello, January 2026

from siliconcompiler import ASIC, Design               # import python package
from siliconcompiler.targets import skywater130_demo

if __name__ == '__main__':
  design = Design("neural_net_cpu")                           # create design object
  design.set_topmodule("neural_net_cpu", fileset="rtl")       # set top module
  design.add_file("architecture/modules/linear.sv", fileset="rtl")
  design.add_file("architecture/modules/relu.sv", fileset="rtl")
  design.add_file("architecture/networks/mlp_c1.sv", fileset="rtl")
  design.add_file("architecture/top.sv", fileset="rtl")
  design.add_file("architecture/top.sdc", fileset="sdc")        # add input sources
  project = ASIC(design)                                 # create project
  project.add_fileset(["rtl", "sdc"])                    # enable filesets
  skywater130_demo(project)                              # load a pre-defined target
#   project.option.set_remote(True)                        # enable remote execution
  project.run()                                          # run compilation
  project.summary()                                      # print summary
  project.show()                                         # show layout
