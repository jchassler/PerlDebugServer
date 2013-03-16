PerlDebugServer
===============

This module provide a server for debugging multiples perl processes.

Lots of debugging modules a available for perl (graphical and non graphical), their are all directly attached to the debugged script.
This implies the following limitation : 
  - it is not easy to debug multiple processes (10 processes implies 10 debugging shell windows)
  - it is not easy to debug forking processes - breakpoints should be set again at each script execution (and automation is not trivial)

This module aims at providing an debugging engine so that we can provide a debugger equivalent the jvm one where you can observe and halt each jvm thread as you want (replace jvm thread with perl process). Every debugging processes connect to the debugging server providing runtime informations and receiving breakpoint list to set.

This module aims at providing a convenient base be to develop one or more GUI client to control this debug server.
